import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../data/airports.dart';
import '../models/award.dart';

/// Contract for any award-availability backend.
abstract class AwardService {
  Future<List<AwardOffer>> search(AwardQuery query);
}

/// Mock frequent-flyer programs with realistic domestic award charts.
class _MockProgram {
  final String name;
  final String code;
  final String bookingUrl;
  const _MockProgram(this.name, this.code, this.bookingUrl);
}

class MockAwardService implements AwardService {
  static const _programs = [
    _MockProgram('United MileagePlus', 'united',
        'https://www.united.com/en/us/fsr/choose-flights'),
    _MockProgram('American AAdvantage', 'american',
        'https://www.aa.com/booking/search'),
    _MockProgram('Delta SkyMiles', 'delta', 'https://www.delta.com/flightsearch'),
    _MockProgram('Alaska Mileage Plan', 'alaska',
        'https://www.alaskaair.com/search/results'),
    _MockProgram('Aeroplan', 'aeroplan', 'https://www.aircanada.com/aeroplan'),
    _MockProgram('Flying Blue', 'flyingblue',
        'https://www.flyingblue.com/en-us'),
    _MockProgram('JetBlue TrueBlue', 'jetblue',
        'https://www.jetblue.com/booking/flights'),
  ];

  static const _airlines = [
    'United',
    'American',
    'Delta',
    'Alaska',
    'JetBlue',
  ];

  /// Realistic domestic mileage bands per cabin (in miles).
  static const _bands = {
    AwardCabin.economy: [7500, 25000],
    AwardCabin.premium: [15000, 40000],
    AwardCabin.business: [25000, 75000],
    AwardCabin.first: [40000, 100000],
  };

  @override
  Future<List<AwardOffer>> search(AwardQuery q) async {
    var h = 97;
    for (final c in 'award${q.from}${q.to}'.codeUnits) {
      h = h * 31 + c;
    }
    h = h * 31 + q.startDate.day + q.startDate.month * 31;
    final rng = Random(h);

    final cabins = q.cabins.isEmpty ? AwardCabin.values : q.cabins;
    final programs = q.programs.isEmpty
        ? _programs
        : _programs.where((p) => q.programs.contains(p.code)).toList();

    final days = q.endDate.difference(q.startDate).inDays.clamp(0, 60);
    final offers = <AwardOffer>[];
    final from = primaryAirport(q.from);
    final to = primaryAirport(q.to);

    for (var d = 0; d <= days && offers.length < 60; d++) {
      final date = DateTime(
          q.startDate.year, q.startDate.month, q.startDate.day + d);
      // Not every program has availability every day.
      for (final program in programs) {
        if (rng.nextDouble() < 0.45) continue;
        final cabin = cabins[rng.nextInt(cabins.length)];
        final band = _bands[cabin]!;
        final miles =
            band[0] + rng.nextInt((band[1] - band[0]) ~/ 500) * 500;
        final saver = miles <= band[0] + (band[1] - band[0]) * 0.25;
        final fees =
            (5.60 + rng.nextDouble() * 44.40).roundToDouble();
        final airline =
            _airlines[rng.nextInt(_airlines.length)];
        offers.add(AwardOffer(
          id: 'award-$from-$to-${program.code}-${cabin.apiCode}-$d',
          program: program.name,
          programCode: program.code,
          origin: from,
          destination: to,
          date: date,
          cabin: cabin,
          mileageCost: miles,
          plusCashFees: fees,
          airline: airline,
          stops: rng.nextDouble() < 0.4 ? 0 : 1,
          bookingUrl: program.bookingUrl,
          isSaver: saver,
        ));
      }
    }
    offers.sort((a, b) => a.mileageCost.compareTo(b.mileageCost));
    return offers;
  }
}

/// Live provider backed by the seats.aero Partner API.
///
/// Docs: https://developers.seats.aero
/// Base: https://seats.aero/partnerapi
/// Auth: HTTP header `Partner-Authorization: <API_KEY>`
///
/// Search endpoint:
///   GET /search
///     ?origin_airport={from}
///     &destination_airport={to}
///     &start_date={yyyy-MM-dd}
///     &end_date={yyyy-MM-dd}
///     &cabins={economy,premium,business,first}
///     &order_by=lowest_mileage
///     &take=100
///
/// Response JSON: `{ "data": [ {...}, ... ] }` where each entry carries
/// fields like Source, OriginAirport, DestinationAirport, Date, and per-cabin
/// availability flags (YAvailable/WAvailable/JAvailable/FAvailable) plus
/// mileage-cost fields (names vary by source; parse defensively).
class SeatsAeroAwardService implements AwardService {
  final String apiKey;
  static const _base = 'https://seats.aero/partnerapi';

  SeatsAeroAwardService({required this.apiKey});

  @override
  Future<List<AwardOffer>> search(AwardQuery query) async {
    if (apiKey.isEmpty) {
      throw UnimplementedError(
        'SeatsAeroAwardService needs an API key. '
        'Get one at https://developers.seats.aero and pass it with '
        '--dart-define=SEATS_AERO_API_KEY=your_key (see lib/config.dart). '
        'Showing sample data until configured.',
      );
    }

    final cabins = query.cabins.isEmpty
        ? AwardCabin.values
        : query.cabins;
    final uri = Uri.parse('$_base/search').replace(queryParameters: {
      'origin_airport': primaryAirport(query.from),
      'destination_airport': primaryAirport(query.to),
      'start_date': _fmtDate(query.startDate),
      'end_date': _fmtDate(query.endDate),
      'cabins': cabins.map((c) => c.name).join(','),
      'order_by': 'lowest_mileage',
      'take': '100',
    });

    final resp = await http.get(
      uri,
      headers: {'Partner-Authorization': apiKey},
    );
    if (resp.statusCode != 200) {
      throw StateError(
          'seats.aero request failed: HTTP ${resp.statusCode}');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? [];
    final offers = <AwardOffer>[];
    for (var i = 0; i < data.length; i++) {
      final e = Map<String, dynamic>.from(data[i] as Map);
      offers.addAll(_parseEntry(e, i, query));
    }
    offers.sort((a, b) => a.mileageCost.compareTo(b.mileageCost));
    return offers;
  }

  /// Defensive parse: seats.aero field names vary by availability source,
  /// so every field has a fallback.
  List<AwardOffer> _parseEntry(
      Map<String, dynamic> e, int index, AwardQuery query) {
    final origin = (e['OriginAirport'] ?? query.from).toString();
    final destination =
        (e['DestinationAirport'] ?? query.to).toString();
    final dateStr = e['Date']?.toString();
    DateTime date;
    try {
      date = dateStr != null ? DateTime.parse(dateStr) : query.startDate;
    } catch (_) {
      date = query.startDate;
    }
    final program = (e['Source'] ?? e['Program'] ?? 'Unknown').toString();
    final programCode = program.toLowerCase().replaceAll(' ', '');

    final out = <AwardOffer>[];
    for (final cabin in AwardCabin.values) {
      final p = cabin.apiCode; // Y/W/J/F
      final available = e['${p}Available'] == true ||
          e['${p}SeatsAvailable'] == true;
      if (!available) continue;
      final milesRaw = e['${p}MileageCost'] ??
          e['${p}Miles'] ??
          e['${p}MileageProgram'];
      final miles = milesRaw is num
          ? milesRaw.toInt()
          : int.tryParse(milesRaw?.toString() ?? '') ?? 0;
      if (miles <= 0) continue;
      final feesRaw = e['${p}TotalTaxes'] ?? e['Taxes'] ?? 5.60;
      final fees = feesRaw is num
          ? feesRaw.toDouble()
          : double.tryParse(feesRaw.toString()) ?? 5.60;
      out.add(AwardOffer(
        id: 'seats-$index-$p',
        program: program,
        programCode: programCode,
        origin: origin,
        destination: destination,
        date: date,
        cabin: cabin,
        mileageCost: miles,
        plusCashFees: fees,
        airline: (e['Airline'] ?? program).toString(),
        stops: (e['Stops'] as num?)?.toInt() ?? 0,
        bookingUrl: 'https://seats.aero',
        isSaver: e['${p}Saver'] == true,
      ));
    }
    return out;
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Picks the live seats.aero provider when a key exists, else the mock.
class AwardServiceFactory {
  static AwardService create() {
    if (AppConfig.seatsAeroApiKey.isNotEmpty) {
      return SeatsAeroAwardService(apiKey: AppConfig.seatsAeroApiKey);
    }
    return MockAwardService();
  }

  /// True when showing sample data instead of live availability.
  static bool get isMock => AppConfig.seatsAeroApiKey.isEmpty;
}
