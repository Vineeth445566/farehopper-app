import 'dart:math';

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
/// TODO: wire up when you have Amadeus Self-Service API credentials:
///  1. POST https://test.api.amadeus.com/v1/security/oauth2/token
///     with `grant_type=client_credentials`, `client_id`, `client_secret`
///  2. GET https://test.api.amadeus.com/v2/shopping/flight-offers
///     with query params `originLocationCode`, `destinationLocationCode`,
///     `departureDate` (YYYY-MM-DD), adults, max results, `currencyCode=USD`.
///     For metro codes, expand to member airports (see `expandMetro` in
///     `lib/data/airports.dart`) and fan out one request per member.
///  3. Map each offer's itineraries -> FlightSegment list, price.total ->
///     totalPrice, and validatingAirlineCodes -> airline name.
///  4. Cache the OAuth token until its expires_in elapses; refresh on 401.
class AmadeusFlightService implements FlightService {
  final String apiKey;
  final String apiSecret;

  AmadeusFlightService({required this.apiKey, required this.apiSecret});

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
    // TODO: implement the OAuth2 token exchange + flight-offers call.
    throw UnimplementedError(
      'AmadeusFlightService.search is not implemented yet. '
      'See the TODO in lib/services/flight_service.dart for the endpoint flow.',
    );
  }
}

/// Picks the live provider when credentials exist, else the mock.
class FlightServiceFactory {
  static FlightService create() {
    if (AppConfig.amadeusApiKey.isNotEmpty &&
        AppConfig.amadeusApiSecret.isNotEmpty) {
      return AmadeusFlightService(
        apiKey: AppConfig.amadeusApiKey,
        apiSecret: AppConfig.amadeusApiSecret,
      );
    }
    return MockFlightService();
  }
}
