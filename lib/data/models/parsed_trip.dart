import 'package:flutter/foundation.dart';

import '../../core/enums.dart';

/// 匯入流程的記憶體表示：AI 解析結果 → 預覽可編輯 → 寫入 Drift 的中介模型。
/// 對應規格 §4.3 的 JSON 契約，與 Drift row 解耦（row 帶 uuid，這裡不帶）。

@immutable
class ParsedTrip {
  const ParsedTrip({
    this.tourCode,
    this.title,
    this.startDate,
    this.endDate,
    this.leaderName,
    this.leaderPhoneDomestic,
    this.leaderPhoneOverseas,
    this.airportServiceLine,
    this.meetupTime,
    this.meetupLocation,
    this.luggageTag,
    this.sourcePdfPath,
    this.rawJson,
    this.flights = const <ParsedFlight>[],
    this.days = const <ParsedDay>[],
    this.infoSections = const <ParsedInfoSection>[],
  });

  final String? tourCode;
  final String? title;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? leaderName;
  final String? leaderPhoneDomestic;
  final String? leaderPhoneOverseas;
  final String? airportServiceLine;
  final DateTime? meetupTime;
  final String? meetupLocation;
  final String? luggageTag;
  final String? sourcePdfPath;
  final String? rawJson;
  final List<ParsedFlight> flights;
  final List<ParsedDay> days;
  final List<ParsedInfoSection> infoSections;

  ParsedTrip copyWith({
    String? tourCode,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    String? leaderName,
    String? leaderPhoneDomestic,
    String? leaderPhoneOverseas,
    String? airportServiceLine,
    DateTime? meetupTime,
    String? meetupLocation,
    String? luggageTag,
    String? sourcePdfPath,
    String? rawJson,
    List<ParsedFlight>? flights,
    List<ParsedDay>? days,
    List<ParsedInfoSection>? infoSections,
  }) {
    return ParsedTrip(
      tourCode: tourCode ?? this.tourCode,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      leaderName: leaderName ?? this.leaderName,
      leaderPhoneDomestic: leaderPhoneDomestic ?? this.leaderPhoneDomestic,
      leaderPhoneOverseas: leaderPhoneOverseas ?? this.leaderPhoneOverseas,
      airportServiceLine: airportServiceLine ?? this.airportServiceLine,
      meetupTime: meetupTime ?? this.meetupTime,
      meetupLocation: meetupLocation ?? this.meetupLocation,
      luggageTag: luggageTag ?? this.luggageTag,
      sourcePdfPath: sourcePdfPath ?? this.sourcePdfPath,
      rawJson: rawJson ?? this.rawJson,
      flights: flights ?? this.flights,
      days: days ?? this.days,
      infoSections: infoSections ?? this.infoSections,
    );
  }
}

@immutable
class ParsedFlight {
  const ParsedFlight({
    this.dayIndex,
    this.flightNo,
    this.carrier,
    this.departTime,
    this.arriveTime,
    this.fromAirport,
    this.toAirport,
  });

  final int? dayIndex;
  final String? flightNo;
  final String? carrier;
  final DateTime? departTime;
  final DateTime? arriveTime;
  final String? fromAirport;
  final String? toAirport;

  ParsedFlight copyWith({
    int? dayIndex,
    String? flightNo,
    String? carrier,
    DateTime? departTime,
    DateTime? arriveTime,
    String? fromAirport,
    String? toAirport,
  }) {
    return ParsedFlight(
      dayIndex: dayIndex ?? this.dayIndex,
      flightNo: flightNo ?? this.flightNo,
      carrier: carrier ?? this.carrier,
      departTime: departTime ?? this.departTime,
      arriveTime: arriveTime ?? this.arriveTime,
      fromAirport: fromAirport ?? this.fromAirport,
      toAirport: toAirport ?? this.toAirport,
    );
  }
}

@immutable
class ParsedDay {
  const ParsedDay({
    required this.dayIndex,
    this.date,
    this.routeSummary,
    this.hotelName,
    this.hotelNameEn,
    this.hotelPhone,
    this.mealBreakfast,
    this.mealLunch,
    this.mealDinner,
    this.notes,
    this.spots = const <ParsedSpot>[],
  });

  final int dayIndex;
  final DateTime? date;
  final String? routeSummary;
  final String? hotelName;
  final String? hotelNameEn;
  final String? hotelPhone;
  final String? mealBreakfast;
  final String? mealLunch;
  final String? mealDinner;
  final String? notes;
  final List<ParsedSpot> spots;

  ParsedDay copyWith({
    int? dayIndex,
    DateTime? date,
    String? routeSummary,
    String? hotelName,
    String? hotelNameEn,
    String? hotelPhone,
    String? mealBreakfast,
    String? mealLunch,
    String? mealDinner,
    String? notes,
    List<ParsedSpot>? spots,
  }) {
    return ParsedDay(
      dayIndex: dayIndex ?? this.dayIndex,
      date: date ?? this.date,
      routeSummary: routeSummary ?? this.routeSummary,
      hotelName: hotelName ?? this.hotelName,
      hotelNameEn: hotelNameEn ?? this.hotelNameEn,
      hotelPhone: hotelPhone ?? this.hotelPhone,
      mealBreakfast: mealBreakfast ?? this.mealBreakfast,
      mealLunch: mealLunch ?? this.mealLunch,
      mealDinner: mealDinner ?? this.mealDinner,
      notes: notes ?? this.notes,
      spots: spots ?? this.spots,
    );
  }
}

@immutable
class ParsedSpot {
  const ParsedSpot({
    required this.orderIndex,
    required this.name,
    this.visitType = VisitType.enter,
    this.description,
    this.refundNote,
    this.imagePath,
  });

  final int orderIndex;
  final String name;
  final VisitType visitType;
  final String? description;
  final String? refundNote;
  final String? imagePath;

  ParsedSpot copyWith({
    int? orderIndex,
    String? name,
    VisitType? visitType,
    String? description,
    String? refundNote,
    String? imagePath,
  }) {
    return ParsedSpot(
      orderIndex: orderIndex ?? this.orderIndex,
      name: name ?? this.name,
      visitType: visitType ?? this.visitType,
      description: description ?? this.description,
      refundNote: refundNote ?? this.refundNote,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}

@immutable
class ParsedInfoSection {
  const ParsedInfoSection({
    required this.category,
    required this.title,
    required this.body,
    required this.orderIndex,
  });

  final InfoCategory category;
  final String title;
  final String body;
  final int orderIndex;

  ParsedInfoSection copyWith({
    InfoCategory? category,
    String? title,
    String? body,
    int? orderIndex,
  }) {
    return ParsedInfoSection(
      category: category ?? this.category,
      title: title ?? this.title,
      body: body ?? this.body,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}
