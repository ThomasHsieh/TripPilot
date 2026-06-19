import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_pilot/core/enums.dart';
import 'package:trip_pilot/data/database/app_database.dart';
import 'package:trip_pilot/data/models/parsed_trip.dart';
import 'package:trip_pilot/data/repositories/trip_repository.dart';
import 'package:trip_pilot/features/import/trip_json_mapper.dart';

/// 代表性 JSON（仿 §4.3，對應範例行程的精簡版）。
Map<String, dynamic> sampleJson({bool dropLastDay = false}) {
  final List<Map<String, dynamic>> days = <Map<String, dynamic>>[
    <String, dynamic>{
      'day_index': 1,
      'date': '2026-06-13',
      'route_summary': '桃園 / 青森',
      'hotel_name': '十和田莊',
      'hotel_name_en': 'TOWADASO',
      'hotel_phone': '0176-75-2221',
      'meal_breakfast': null,
      'meal_lunch': '機上簡餐',
      'meal_dinner': '飯店會席料理',
      'spots': <Map<String, dynamic>>[
        <String, dynamic>{
          'order_index': 1,
          'name': '奧入瀨溪流',
          'visit_type': 'enter',
          'refund_note': null,
        },
      ],
    },
    <String, dynamic>{
      'day_index': 2,
      'date': '2026-06-14',
      'route_summary': '秋田',
      'hotel_name': '田澤湖 LAKE RESORT',
      'spots': <Map<String, dynamic>>[
        <String, dynamic>{
          'order_index': 1,
          'name': '發荷峠展望台',
          'visit_type': 'photo',
        },
      ],
    },
    <String, dynamic>{
      'day_index': 3,
      'date': '2026-06-15',
      'route_summary': '山形縣'
    },
    <String, dynamic>{
      'day_index': 4,
      'date': '2026-06-16',
      'route_summary': '岩手縣',
      'spots': <Map<String, dynamic>>[
        <String, dynamic>{
          'order_index': 1,
          'name': '平泉中尊寺',
          'visit_type': 'enter',
          'refund_note': '停駛退費500日幣/位',
        },
      ],
    },
    <String, dynamic>{
      'day_index': 5,
      'date': '2026-06-17',
      'route_summary': '青森'
    },
    <String, dynamic>{
      'day_index': 6,
      'date': '2026-06-18',
      'route_summary': '青森 / 桃園'
    },
  ];
  if (dropLastDay) days.removeLast();

  return <String, dynamic>{
    'tour_code': 'NSC061306BR6',
    'title': '東北仙境傳說六日',
    'start_date': '2026-06-13',
    'end_date': '2026-06-18',
    'leader_name': '王小明',
    'leader_phone_domestic': '0912345678',
    'leader_phone_overseas': '08012345678',
    'meetup_time': '2026-06-13T07:25',
    'meetup_location': '桃園機場第二航廈',
    'luggage_tag': '橘色',
    'days': days,
    'flights': <Map<String, dynamic>>[
      <String, dynamic>{
        'day_index': 1,
        'flight_no': 'BR122',
        'carrier': '長榮航空',
        'depart_time': '2026-06-13T09:55',
        'arrive_time': '2026-06-13T14:20',
        'from_airport': '台北(桃園)',
        'to_airport': '青森縣',
      },
      <String, dynamic>{
        'day_index': 6,
        'flight_no': 'BR121',
        'carrier': '長榮航空',
        'depart_time': '2026-06-18T15:30',
        'arrive_time': '2026-06-18T18:40',
      },
    ],
    'info_sections': <Map<String, dynamic>>[
      <String, dynamic>{
        'category': 'customs',
        'title': '退稅規定',
        'body': '購物時請保留收據辦理退稅，鋰電池須隨身攜帶。',
        'order_index': 1,
      },
    ],
  };
}

void main() {
  test('JSON → ParsedTrip 映射正確', () {
    final ParsedTrip trip = mapClaudeJson(sampleJson());

    expect(trip.tourCode, 'NSC061306BR6');
    expect(trip.days, hasLength(6));
    expect(trip.flights, hasLength(2));
    expect(trip.flights.first.flightNo, 'BR122');
    expect(trip.flights.first.departTime, DateTime(2026, 6, 13, 9, 55));

    final ParsedDay d1 = trip.days.first;
    expect(d1.hotelName, '十和田莊');
    expect(d1.hotelPhone, '0176-75-2221');
    expect(d1.spots.single.visitType, VisitType.enter);

    final ParsedDay d2 = trip.days[1];
    expect(d2.spots.single.visitType, VisitType.photo);

    final ParsedDay d4 = trip.days[3];
    expect(d4.spots.single.name, '平泉中尊寺');
    expect(d4.spots.single.refundNote, '停駛退費500日幣/位');

    expect(trip.infoSections.single.category, InfoCategory.customs);
    expect(trip.meetupTime, DateTime(2026, 6, 13, 7, 25));
  });

  test('一致的行程 → 無警告', () {
    final ParsedTrip trip = mapClaudeJson(sampleJson());
    expect(validateParsedTrip(trip), isEmpty);
  });

  test('天數不符 → dayCountMismatch 警告', () {
    final ParsedTrip trip = mapClaudeJson(sampleJson(dropLastDay: true));
    final List<TripWarning> warnings = validateParsedTrip(trip);
    expect(
      warnings.map((TripWarning w) => w.kind),
      contains(TripWarningKind.dayCountMismatch),
    );
  });

  test('映射結果寫入 Drift → 讀回 6 天', () async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final TripRepository repo = TripRepository(db);

    final ParsedTrip trip = mapClaudeJson(sampleJson());
    final String tripId = await repo.insertParsedTrip(trip);

    final trips = await repo.getTrips();
    expect(trips.single.tourCode, 'NSC061306BR6');
    expect(await repo.getDays(tripId), hasLength(6));

    final days = await repo.getDays(tripId);
    final day1Spots = await repo.getSpotsForDay(days.first.id);
    expect(day1Spots.single.name, '奧入瀨溪流');
  });

  test('容錯：缺漏與型別不符不崩潰', () {
    final ParsedTrip trip = mapClaudeJson(<String, dynamic>{
      'tour_code': 123, // 非字串
      'days': 'oops', // 非陣列
      'flights': null,
    });
    expect(trip.tourCode, '123');
    expect(trip.days, isEmpty);
    expect(trip.flights, isEmpty);
  });
}
