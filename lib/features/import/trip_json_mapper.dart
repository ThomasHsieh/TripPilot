import '../../core/enums.dart';
import '../../data/models/parsed_trip.dart';

/// 解析後合理性警告（§4.4）。預覽頁以黃色標示，仍允許修正後存檔。
enum TripWarningKind {
  dayCountMismatch,
  dateDiscontinuous,
  flightOutOfRange,
  meetupAfterFirstFlight,
}

class TripWarning {
  const TripWarning(this.kind, [this.detail]);
  final TripWarningKind kind;
  final String? detail;
}

/// 將 Claude 回傳的 JSON Map 映射為 [ParsedTrip]。
/// 全程容錯：型別不符或缺漏一律降級為 null/預設，不丟例外（§4.2「不可崩潰」）。
ParsedTrip mapClaudeJson(
  Map<String, dynamic> json, {
  String? sourcePdfPath,
  String? rawJson,
}) {
  return ParsedTrip(
    tourCode: _str(json['tour_code']),
    title: _str(json['title']),
    startDate: _date(json['start_date']),
    endDate: _date(json['end_date']),
    leaderName: _str(json['leader_name']),
    leaderPhoneDomestic: _str(json['leader_phone_domestic']),
    leaderPhoneOverseas: _str(json['leader_phone_overseas']),
    airportServiceLine: _str(json['airport_service_line']),
    meetupTime: _dateTime(json['meetup_time']),
    meetupLocation: _str(json['meetup_location']),
    luggageTag: _str(json['luggage_tag']),
    sourcePdfPath: sourcePdfPath,
    rawJson: rawJson,
    flights: _list(json['flights']).map(_mapFlight).toList(),
    days: _list(json['days']).map(_mapDay).toList(),
    infoSections: _indexedInfo(_list(json['info_sections'])),
  );
}

ParsedFlight _mapFlight(Map<String, dynamic> j) => ParsedFlight(
      dayIndex: _int(j['day_index']),
      flightNo: _str(j['flight_no']),
      carrier: _str(j['carrier']),
      departTime: _dateTime(j['depart_time']),
      arriveTime: _dateTime(j['arrive_time']),
      fromAirport: _str(j['from_airport']),
      toAirport: _str(j['to_airport']),
    );

ParsedDay _mapDay(Map<String, dynamic> j) {
  final List<Map<String, dynamic>> spots = _list(j['spots']);
  return ParsedDay(
    dayIndex: _int(j['day_index']) ?? 0,
    date: _date(j['date']),
    routeSummary: _str(j['route_summary']),
    hotelName: _str(j['hotel_name']),
    hotelNameEn: _str(j['hotel_name_en']),
    hotelPhone: _str(j['hotel_phone']),
    mealBreakfast: _str(j['meal_breakfast']),
    mealLunch: _str(j['meal_lunch']),
    mealDinner: _str(j['meal_dinner']),
    notes: _str(j['notes']),
    spots: <ParsedSpot>[
      for (int i = 0; i < spots.length; i++) _mapSpot(spots[i], i + 1),
    ],
  );
}

ParsedSpot _mapSpot(Map<String, dynamic> j, int fallbackOrder) => ParsedSpot(
      orderIndex: _int(j['order_index']) ?? fallbackOrder,
      name: _str(j['name']) ?? '',
      visitType: VisitType.fromWire(_str(j['visit_type'])),
      description: _str(j['description']),
      refundNote: _str(j['refund_note']),
      imagePath: _str(j['image']),
    );

List<ParsedInfoSection> _indexedInfo(List<Map<String, dynamic>> raw) {
  return <ParsedInfoSection>[
    for (int i = 0; i < raw.length; i++)
      ParsedInfoSection(
        category: InfoCategory.fromWire(_str(raw[i]['category'])),
        title: _str(raw[i]['title']) ?? '',
        body: _str(raw[i]['body']) ?? '',
        orderIndex: _int(raw[i]['order_index']) ?? (i + 1),
      ),
  ];
}

/// 合理性檢查（§4.4）：天數連續性、航班日期落在區間、集合早於首班機。
List<TripWarning> validateParsedTrip(ParsedTrip trip) {
  final List<TripWarning> warnings = <TripWarning>[];
  final DateTime? start = trip.startDate;
  final DateTime? end = trip.endDate;

  // 1. 天數與日期區間一致
  if (start != null && end != null && trip.days.isNotEmpty) {
    final int expected = end.difference(_dateOnly(start)).inDays + 1;
    if (expected != trip.days.length) {
      warnings.add(
        TripWarning(
          TripWarningKind.dayCountMismatch,
          '日期區間 $expected 天，但解析出 ${trip.days.length} 天',
        ),
      );
    }
  }

  // 2. 每日日期連續性
  if (start != null) {
    final List<ParsedDay> sorted = <ParsedDay>[...trip.days]
      ..sort((ParsedDay a, ParsedDay b) => a.dayIndex.compareTo(b.dayIndex));
    for (final ParsedDay day in sorted) {
      if (day.date == null) continue;
      final DateTime expected =
          _dateOnly(start).add(Duration(days: day.dayIndex - 1));
      if (_dateOnly(day.date!) != expected) {
        warnings.add(
          TripWarning(
            TripWarningKind.dateDiscontinuous,
            'Day ${day.dayIndex} 日期不連續',
          ),
        );
        break;
      }
    }
  }

  // 3. 航班日期落在行程區間內
  if (start != null && end != null) {
    final DateTime lo = _dateOnly(start);
    final DateTime hi = _dateOnly(end);
    for (final ParsedFlight f in trip.flights) {
      for (final DateTime? t in <DateTime?>[f.departTime, f.arriveTime]) {
        if (t == null) continue;
        final DateTime d = _dateOnly(t);
        if (d.isBefore(lo) || d.isAfter(hi)) {
          warnings.add(
            TripWarning(
              TripWarningKind.flightOutOfRange,
              '航班 ${f.flightNo ?? ''} 日期不在行程區間',
            ),
          );
          break;
        }
      }
    }
  }

  // 4. 集合時間早於首班機
  if (trip.meetupTime != null && trip.flights.isNotEmpty) {
    final List<DateTime> departs = trip.flights
        .map((ParsedFlight f) => f.departTime)
        .whereType<DateTime>()
        .toList()
      ..sort();
    if (departs.isNotEmpty && !trip.meetupTime!.isBefore(departs.first)) {
      warnings.add(const TripWarning(TripWarningKind.meetupAfterFirstFlight));
    }
  }

  return warnings;
}

// ── 型別輔助（容錯）──────────────────────────────────────────

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String? _str(Object? v) {
  if (v == null) return null;
  final String s = v.toString().trim();
  return s.isEmpty || s.toLowerCase() == 'null' ? null : s;
}

int? _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

DateTime? _date(Object? v) {
  final String? s = _str(v);
  if (s == null) return null;
  return DateTime.tryParse(s.length == 10 ? '${s}T00:00' : s);
}

DateTime? _dateTime(Object? v) {
  final String? s = _str(v);
  if (s == null) return null;
  return DateTime.tryParse(s);
}

List<Map<String, dynamic>> _list(Object? v) {
  if (v is! List) return const <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
  for (final Object? e in v) {
    if (e is Map) {
      out.add(
        e.map(
          (Object? k, Object? val) =>
              MapEntry<String, dynamic>(k.toString(), val),
        ),
      );
    }
  }
  return out;
}
