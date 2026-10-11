import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../data/airports.dart';
import '../models/flight.dart';

/// Contract for any flight-search backend.
abstract class FlightService {
  Future<List<FlightOffer>> search(SearchQuery query);
}

/// Generates realistic domestic offers without network access.
/// Deterministic: seeded by route + date + cabin so results are stable.
class MockFlightService implements FlightService {
  static const _airlines = [
    'Delta',
    'United',
    'American',
    'Southwest',
    'JetBlue',
    'Alaska',
    'Spirit',
    'Frontier',
  ];

  static const _bookingUrls = [
    'https://www.delta.com',
    'https://www.united.com',
    'https://www.aa.com',
    'https://www.southwest.com',
    'https://www.jetblue.com',
    'https://www.alaskaair.com',
    'https://www.spirit.com',
    'https://www.flyfrontier.com',
  ];

  @override
  Future<List<FlightOffer>> search(SearchQuery q) async {
    // Simulated network latency is added by the results screen.
    final seed = _seedFor(q);
    final rng = Random(seed);
    final fromAirports = expandMetro(q.from);
    final toAirports = expandMetro(q.to);
    final count = 8 + rng.nextInt(7); // 8-14 offers
    final offers = <FlightOffer>[];

    for (var i = 0; i < count; i++) {
      final from = fromAirports[rng.nextInt(fromAirports.length)];
      final to = toAirports[rng.nextInt(toAirports.length)];
      final airlineIdx = rng.nextInt(_airlines.length);
      final airline = _airlines[airlineIdx];
      final stopRoll = rng.nextDouble();
      final stops = stopRoll < 0.35 ? 0 : (stopRoll < 0.8 ? 1 : 2);
      offers.add(_buildOffer(
        rng: rng,
        index: i,
        query: q,
        from: from,
        to: to,
        airline: airline,
        airlineIdx: airlineIdx,
        stops: stops,
      ));
    }
    offers.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
    return offers;
  }

  int _seedFor(SearchQuery q) {
    var h = 17;
    for (final c in '${q.from}${q.to}${q.cabin.index}'.codeUnits) {
      h = h * 31 + c;
    }
    h = h * 31 + q.date.day + q.date.month * 31 + q.date.year;
    return h;
  }

  FlightOffer _buildOffer({
    required Random rng,
    required int index,
    required SearchQuery query,
    required String from,
    required String to,
    required String airline,
    required int airlineIdx,
    required int stops,
  }) {
    const hubs = ['DFW', 'ORD', 'DEN', 'ATL', 'CLT', 'PHX', 'LAS', 'MSP'];
    final viaPool =
        hubs.where((h) => h != from && h != to).toList();

    final base = DateTime(
      query.date.year,
      query.date.month,
      query.date.day,
      6 + rng.nextInt(14), // departures 6:00 - 19:00
      [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55][rng.nextInt(12)],
    );

    final segments = <FlightSegment>[];
    var current = from;
    var cursor = base;
    final via = <String>[];
    for (var s = 0; s < stops; s++) {
      via.add(viaPool[rng.nextInt(viaPool.length)]);
    }

    final legs = [...via, to];
    for (var s = 0; s < legs.length; s++) {
      final legMinutes = 60 + rng.nextInt(180); // 1h - 4h per leg
      final depart = s == 0
          ? cursor
          : cursor.add(Duration(minutes: 45 + rng.nextInt(90)));
      final arrive = depart.add(Duration(minutes: legMinutes));
      segments.add(FlightSegment(
        airline: airline,
        flightNumber: '${100 + rng.nextInt(8900)}',
        from: current,
        to: legs[s],
        departTime: depart,
        arriveTime: arrive,
        duration: Duration(minutes: legMinutes),
      ));
      current = legs[s];
      cursor = arrive;
    }

    final totalDuration = cursor.difference(base);
    // Price: base fare grows with legs and drops for ultra-low-cost
    // carriers; morning/evening peaks cost a bit more.
    final isUlc = airline == 'Spirit' || airline == 'Frontier';
    var price = 89.0 + rng.nextDouble() * 200 + legs.length * 45;
    if (isUlc) price *= 0.72;
    if (base.hour < 8 || base.hour >= 17) price *= 1.12;
    price *= query.cabin.multiplier;
    price = (price * 100).roundToDouble() / 100;

    return FlightOffer(
      id: 'mock-${query.from}-${query.to}-$index',
      segments: segments,
      totalPrice: price,
      airline: airline,
      stops: stops,
      totalDuration: totalDuration,
      bookingUrl: _bookingUrls[airlineIdx],
      cabin: query.cabin,
    );
  }

  /// Cheapest mock fare per destination from [from] on [date].
  /// Used by the Explore view ("where can I go cheap?").
  List<ExploreDeal> exploreDeals(
      String from, DateTime date, CabinClass cabin) {
    final fromMembers = expandMetro(from).toSet();
    var h = 41;
    for (final c in 'explore$from${cabin.index}'.codeUnits) {
      h = h * 31 + c;
    }
    h = h * 31 + date.day + date.month * 31 + date.year;
    final rng = Random(h);

    final destinations = usAirports
        .where((a) => !fromMembers.contains(a.code))
        .toList()
      ..shuffle(rng);
    final picks = destinations.take(8 + rng.nextInt(5)).toList(); // 8-12

    final deals = picks.map((a) {
      var price = 79.0 + rng.nextDouble() * 320;
      price *= cabin.multiplier;
      price = price.roundToDouble();
      return ExploreDeal(
        destinationCode: a.code,
        city: a.city,
        price: price,
      );
    }).toList();
    deals.sort((a, b) => a.price.compareTo(b.price));
    return deals;
  }
}

/// One row in the Explore view: cheapest fare to a destination.
class ExploreDeal {
  final String destinationCode;
  final String city;
  final double price;

  const ExploreDeal({
    required this.destinationCode,
    required this.city,
    required this.price,
  });
}

/// Live provider backed by the Amadeus Flight Offers Search API.
///
/// Auth: OAuth2 client credentials.
///   POST https://test.api.amadeus.com/v1/security/oauth2/token
///   body: grant_type=client_credentials&client_id=...&client_secret=...
/// Search:
///   GET https://test.api.amadeus.com/v2/shopping/flight-offers
///     ?originLocationCode=PHX&destinationLocationCode=JFK
///     &departureDate=2026-11-15&adults=1&max=20&currencyCode=USD
///
/// Metro codes (NYC, CHI, ...) are expanded to member airports and fanned
/// out as one request per origin/destination pair; results are merged and
/// sorted by price. The OAuth token is cached until shortly before expiry.
///
/// Note: the test environment serves cached/limited routes, not full live
/// inventory. Switch [_host] to api.amadeus.com for production (metered).
class AmadeusFlightService implements FlightService {
  final String apiKey;
  final String apiSecret;

  static const _host = 'test.api.amadeus.com';
  static const _maxResults = 20;

  String? _token;
  DateTime? _tokenExpiry;

  AmadeusFlightService({required this.apiKey, required this.apiSecret});

  /// IATA carrier code -> display name for common US carriers.
  static const _carrierNames = {
    'AA': 'American',
    'AS': 'Alaska',
    'B6': 'JetBlue',
    'DL': 'Delta',
    'F9': 'Frontier',
    'HA': 'Hawaiian',
    'NK': 'Spirit',
    'SY': 'Sun Country',
    'UA': 'United',
    'WN': 'Southwest',
  };

  @override
  Future<List<FlightOffer>> search(SearchQuery query) async {
    if (apiKey.isEmpty || apiSecret.isEmpty) {
      throw UnimplementedError(
        'AmadeusFlightService needs API credentials. '
        'Set AMADEUS_API_KEY and AMADEUS_API_SECRET via --dart-define '
        '(see lib/config.dart), or get free test keys at '
        'https://developers.amadeus.com/register',
      );
    }

    final token = await _accessToken();
    final origins = expandMetro(query.from);
    final destinations = expandMetro(query.to);
    final date = _fmtDate(query.date);

    // Fan out across metro member airports (usually 1x1 or a few pairs).
    final offers = <FlightOffer>[];
    for (final o in origins) {
      for (final d in destinations) {
        if (o == d) continue;
        offers.addAll(await _searchPair(
          token: token,
          origin: o,
          destination: d,
          date: date,
          adults: query.passengers,
          cabin: query.cabin,
        ));
      }
    }
    offers.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
    return offers;
  }

  Future<String> _accessToken() async {
    if (_token != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(
            _tokenExpiry!.subtract(const Duration(minutes: 2)))) {
      return _token!;
    }
    final resp = await http.post(
      Uri.https(_host, '/v1/security/oauth2/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'grant_type=client_credentials'
          '&client_id=${Uri.encodeComponent(apiKey)}'
          '&client_secret=${Uri.encodeComponent(apiSecret)}',
    );
    if (resp.statusCode != 200) {
      throw StateError(
          'Amadeus auth failed: HTTP ${resp.statusCode} ${resp.body}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    _token = body['access_token'] as String;
    final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 1800;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
    return _token!;
  }

  Future<List<FlightOffer>> _searchPair({
    required String token,
    required String origin,
    required String destination,
    required String date,
    required int adults,
    required CabinClass cabin,
  }) async {
    final uri = Uri.https(_host, '/v2/shopping/flight-offers', {
      'originLocationCode': origin,
      'destinationLocationCode': destination,
      'departureDate': date,
      'adults': adults.toString(),
      'max': _maxResults.toString(),
      'currencyCode': 'USD',
    });
    final resp = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode != 200) {
      // Amadeus returns 400 for routes with no availability in test env.
      return [];
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? [];
    final dictionaries = body['dictionaries'] as Map<String, dynamic>?;
    final carriers = (dictionaries?['carriers'] as Map?)?.cast<String, String>() ?? {};

    final offers = <FlightOffer>[];
    for (var i = 0; i < data.length; i++) {
      final offer = _parseOffer(
        Map<String, dynamic>.from(data[i] as Map),
        index: i,
        cabin: cabin,
        carriers: carriers,
      );
      if (offer != null) offers.add(offer);
    }
    return offers;
  }

  FlightOffer? _parseOffer(
    Map<String, dynamic> o, {
    required int index,
    required CabinClass cabin,
    required Map<String, String> carriers,
  }) {
    try {
      final itineraries = o['itineraries'] as List;
      if (itineraries.isEmpty) return null;
      final segs = (itineraries.first as Map)['segments'] as List;

      final segments = <FlightSegment>[];
      for (final s in segs) {
        final sm = Map<String, dynamic>.from(s as Map);
        final dep = sm['departure'] as Map;
        final arr = sm['arrival'] as Map;
        final carrierCode = (sm['carrierCode'] ?? '').toString();
        final airline = _carrierNames[carrierCode] ??
            carriers[carrierCode] ??
            carrierCode;
        segments.add(FlightSegment(
          airline: airline,
          flightNumber: '${sm['number'] ?? ''}',
          from: (dep['iataCode'] ?? '').toString(),
          to: (arr['iataCode'] ?? '').toString(),
          departTime: DateTime.parse((dep['at'] ?? '').toString()),
          arriveTime: DateTime.parse((arr['at'] ?? '').toString()),
          duration: _parseDuration((sm['duration'] ?? '').toString()),
        ));
      }
      if (segments.isEmpty) return null;

      final price = (o['price'] as Map)['total']?.toString() ?? '0';
      final total = double.tryParse(price) ?? 0;
      if (total <= 0) return null;

      final validating = (o['validatingAirlineCodes'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final airline = validating.isNotEmpty
          ? (_carrierNames[validating.first] ??
              carriers[validating.first] ??
              validating.first)
          : segments.first.airline;

      final first = segments.first.departTime;
      final last = segments.last.arriveTime;
      return FlightOffer(
        id: 'amadeus-$index-${o['id'] ?? ''}',
        segments: segments,
        totalPrice: total,
        airline: airline,
        stops: segments.length - 1,
        totalDuration: last.difference(first),
        bookingUrl:
            'https://www.google.com/travel/flights', // Amadeus is search-only in test env
        cabin: cabin,
      );
    } catch (_) {
      return null; // skip malformed offers
    }
  }

  /// Parses ISO-8601 durations like "PT2H30M".
  Duration _parseDuration(String iso) {
    final m = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?').firstMatch(iso);
    if (m == null) return Duration.zero;
    final h = int.tryParse(m.group(1) ?? '0') ?? 0;
    final min = int.tryParse(m.group(2) ?? '0') ?? 0;
    return Duration(hours: h, minutes: min);
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Live provider backed by the Duffel API (free searches).
///
/// Docs: https://duffel.com/docs/api
/// Auth: `Authorization: Bearer <token>` + `Duffel-Version: v2`
/// Flow:
///   1. POST /air/offer_requests { data: { slices: [...], passengers: [...] } }
///   2. GET /air/offers?offer_request_id={id}&limit=20
///
/// Note: test tokens (duffel_test_...) return Duffel Airways sample data.
/// A live token (after "going live" in the Duffel dashboard) returns real
/// bookable offers from 300+ airlines.
class DuffelFlightService implements FlightService {
  final String apiToken;

  static const _host = 'api.duffel.com';

  DuffelFlightService({required this.apiToken});

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiToken',
        'Duffel-Version': 'v2',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  @override
  Future<List<FlightOffer>> search(SearchQuery query) async {
    if (apiToken.isEmpty) {
      throw UnimplementedError(
        'DuffelFlightService needs an API token. '
        'Get a free one at https://duffel.com and pass it with '
        '--dart-define=DUFFEL_API_KEY=... (see lib/config.dart).',
      );
    }

    final origins = expandMetro(query.from);
    final destinations = expandMetro(query.to);
    final date = _fmtDate(query.date);

    final offers = <FlightOffer>[];
    for (final o in origins) {
      for (final d in destinations) {
        if (o == d) continue;
        offers.addAll(await _searchPair(
          origin: o,
          destination: d,
          date: date,
          adults: query.passengers,
          cabin: query.cabin,
        ));
      }
    }
    offers.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
    return offers;
  }

  Future<List<FlightOffer>> _searchPair({
    required String origin,
    required String destination,
    required String date,
    required int adults,
    required CabinClass cabin,
  }) async {
    // 1. Create the offer request.
    final reqResp = await http.post(
      Uri.https(_host, '/air/offer_requests'),
      headers: _headers,
      body: jsonEncode({
        'data': {
          'slices': [
            {
              'origin': origin,
              'destination': destination,
              'departure_date': date,
            }
          ],
          'passengers': List.generate(
              adults, (_) => {'type': 'adult'}),
          'max_connections': 2,
          'cabin_class': _duffelCabin(cabin),
        }
      }),
    );
    if (reqResp.statusCode != 200 && reqResp.statusCode != 201) {
      return [];
    }
    final reqBody =
        jsonDecode(reqResp.body) as Map<String, dynamic>;
    final requestId =
        ((reqBody['data'] as Map)['id'] ?? '').toString();
    if (requestId.isEmpty) return [];

    // 2. Fetch the offers.
    final offersResp = await http.get(
      Uri.https(_host, '/air/offers',
          {'offer_request_id': requestId, 'limit': '20'}),
      headers: _headers,
    );
    if (offersResp.statusCode != 200) return [];
    final offersBody =
        jsonDecode(offersResp.body) as Map<String, dynamic>;
    final data = (offersBody['data'] as List?) ?? [];

    final offers = <FlightOffer>[];
    for (var i = 0; i < data.length; i++) {
      final offer = _parseOffer(
        Map<String, dynamic>.from(data[i] as Map),
        cabin: cabin,
      );
      if (offer != null) offers.add(offer);
    }
    return offers;
  }

  String _duffelCabin(CabinClass cabin) {
    switch (cabin) {
      case CabinClass.economy:
        return 'economy';
      case CabinClass.premium:
        return 'premium_economy';
      case CabinClass.business:
        return 'business';
    }
  }

  FlightOffer? _parseOffer(
    Map<String, dynamic> o, {
    required CabinClass cabin,
  }) {
    try {
      final slices = o['slices'] as List;
      if (slices.isEmpty) return null;
      final segments =
          ((slices.first as Map)['segments'] as List);

      final flightSegments = <FlightSegment>[];
      for (final s in segments) {
        final sm = Map<String, dynamic>.from(s as Map);
        final origin =
            (sm['origin'] as Map?)?['iata_code']?.toString() ?? '';
        final dest =
            (sm['destination'] as Map?)?['iata_code']?.toString() ??
                '';
        final carrier = (sm['operating_carrier'] as Map?) ??
            (sm['marketing_carrier'] as Map?);
        final airline =
            carrier?['name']?.toString() ?? 'Unknown';
        flightSegments.add(FlightSegment(
          airline: airline,
          flightNumber:
              (sm['marketing_carrier_flight_number'] ?? '')
                  .toString(),
          from: origin,
          to: dest,
          departTime:
              DateTime.parse((sm['departing_at'] ?? '').toString())
                  .toLocal(),
          arriveTime:
              DateTime.parse((sm['arriving_at'] ?? '').toString())
                  .toLocal(),
          duration: _parseDuration(
              (sm['duration'] ?? '').toString()),
        ));
      }
      if (flightSegments.isEmpty) return null;

      final total =
          double.tryParse((o['total_amount'] ?? '0').toString()) ??
              0;
      if (total <= 0) return null;

      final owner = o['owner'] as Map?;
      final airline =
          owner?['name']?.toString() ??
              flightSegments.first.airline;

      final first = flightSegments.first.departTime;
      final last = flightSegments.last.arriveTime;
      return FlightOffer(
        id: 'duffel-${o['id'] ?? ''}',
        segments: flightSegments,
        totalPrice: total,
        airline: airline,
        stops: flightSegments.length - 1,
        totalDuration: last.difference(first),
        bookingUrl: 'https://www.google.com/travel/flights',
        cabin: cabin,
      );
    } catch (_) {
      return null; // skip malformed offers
    }
  }

  Duration _parseDuration(String iso) {
    final m = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?').firstMatch(iso);
    if (m == null) return Duration.zero;
    final h = int.tryParse(m.group(1) ?? '0') ?? 0;
    final min = int.tryParse(m.group(2) ?? '0') ?? 0;
    return Duration(hours: h, minutes: min);
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Picks the live provider when credentials exist, else the mock.
/// Duffel is preferred over Amadeus (Amadeus self-service is discontinued).
class FlightServiceFactory {
  static FlightService create() {
    if (AppConfig.duffelApiKey.isNotEmpty) {
      return DuffelFlightService(apiToken: AppConfig.duffelApiKey);
    }
    if (AppConfig.amadeusApiKey.isNotEmpty &&
        AppConfig.amadeusApiSecret.isNotEmpty) {
      return AmadeusFlightService(
        apiKey: AppConfig.amadeusApiKey,
        apiSecret: AppConfig.amadeusApiSecret,
      );
    }
    return MockFlightService();
  }

  /// True when showing sample data instead of live prices.
  static bool get isMock => AppConfig.duffelApiKey.isEmpty &&
      AppConfig.amadeusApiKey.isEmpty;
}
