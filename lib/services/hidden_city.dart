import 'dart:math';

import '../data/airports.dart';
import '../models/flight.dart';

/// Warning copy shown wherever hidden-city fares appear.
class HiddenCityWarnings {
  static const short =
      'You get off at the layover city and skip the last leg.';

  static const rules = [
    'Book one-way only. A return leg gets cancelled if you skip a segment.',
    'Carry-on only. Checked bags go to the final ticketed city.',
    'Do not add a frequent-flyer number to the booking.',
    'Airlines can rebook you through a different city if flights change.',
    'Hidden-city ticketing violates most airlines\u2019 terms of service.',
  ];

  static String exitLine(String exitCode) =>
      'Get off at $exitCode \u2014 skip the last leg.';
}

/// Synthesizes hidden-city offers from a normal A -> B search result.
///
/// A hidden-city fare is a ticket A -> C (via B) that is cheaper than a
/// regular A -> B ticket. The traveler simply leaves the airport at B.
class HiddenCityFinder {
  /// Candidate "beyond" cities C for a given destination B. In a real
  /// implementation this would be discovered from fare data; here we use a
  /// curated map of plausible continuations from common destinations.
  static const Map<String, List<String>> beyondCities = {
    'MCO': ['MIA', 'TPA', 'ATL', 'CLT'],
    'MIA': ['TPA', 'MCO', 'ATL', 'BNA'],
    'LAX': ['SFO', 'SEA', 'SAN', 'LAS'],
    'SFO': ['LAX', 'SEA', 'SAN', 'PDX'],
    'SEA': ['SFO', 'LAX', 'PDX', 'DEN'],
    'ORD': ['MSP', 'DTW', 'DEN', 'DFW'],
    'DFW': ['IAH', 'AUS', 'DEN', 'PHX'],
    'DEN': ['SLC', 'PHX', 'LAS', 'SEA'],
    'ATL': ['CLT', 'BNA', 'MCO', 'DCA'],
    'BOS': ['DCA', 'PHL', 'EWR', 'JFK'],
    'JFK': ['BOS', 'DCA', 'PHL', 'EWR'],
    'LAS': ['LAX', 'PHX', 'SAN', 'DEN'],
    'PHX': ['LAS', 'SAN', 'DEN', 'LAX'],
    'TPA': ['MCO', 'MIA', 'ATL', 'CLT'],
    'AUS': ['DFW', 'IAH', 'DEN', 'PHX'],
    'SAN': ['LAX', 'SFO', 'LAS', 'PHX'],
    'DCA': ['BOS', 'PHL', 'CLT', 'ATL'],
    'CLT': ['ATL', 'DCA', 'MCO', 'BNA'],
    'MSP': ['ORD', 'DTW', 'DEN', 'SEA'],
    'DTW': ['ORD', 'MSP', 'BOS', 'DCA'],
    'BNA': ['ATL', 'CLT', 'DFW', 'ORD'],
    'PDX': ['SEA', 'SFO', 'LAX', 'DEN'],
    'SLC': ['DEN', 'LAS', 'PHX', 'SEA'],
  };

  /// Builds 2-4 hidden-city offers priced below the cheapest regular fare.
  List<FlightOffer> find({
    required String from,
    required String to,
    required DateTime date,
    required List<FlightOffer> regularOffers,
    int passengers = 1,
  }) {
    if (regularOffers.isEmpty) return [];
    // Metro codes resolve to their primary airport for fare discovery.
    final dest = primaryAirport(to);
    final origin = primaryAirport(from);
    final beyond = beyondCities[dest];
    if (beyond == null || beyond.isEmpty) return [];

    final cheapest =
        regularOffers.map((o) => o.totalPrice).reduce(min);
    final seed = _seed(origin, dest, date);
    final rng = Random(seed);
    final picks = [...beyond]..shuffle(rng);
    final count = 2 + rng.nextInt(3); // 2-4
    final airlines = ['Delta', 'United', 'American', 'JetBlue', 'Alaska'];

    final offers = <FlightOffer>[];
    for (var i = 0; i < count && i < picks.length; i++) {
      final beyondCity = picks[i];
      // 15-40% below the cheapest direct fare.
      final discount = 0.15 + rng.nextDouble() * 0.25;
      final price =
          ((cheapest * (1 - discount)) * 100).roundToDouble() / 100;
      final airline = airlines[rng.nextInt(airlines.length)];

      final depart = DateTime(date.year, date.month, date.day,
          7 + rng.nextInt(12), [0, 15, 30, 45][rng.nextInt(4)]);
      final leg1Mins = 90 + rng.nextInt(150);
      final layoverMins = 50 + rng.nextInt(110);
      final leg2Mins = 60 + rng.nextInt(150);
      final arr1 = depart.add(Duration(minutes: leg1Mins));
      final dep2 = arr1.add(Duration(minutes: layoverMins));
      final arr2 = dep2.add(Duration(minutes: leg2Mins));

      final segments = [
        FlightSegment(
          airline: airline,
          flightNumber: '${100 + rng.nextInt(8900)}',
          from: origin,
          to: dest, // the hidden-city exit point
          departTime: depart,
          arriveTime: arr1,
          duration: Duration(minutes: leg1Mins),
        ),
        FlightSegment(
          airline: airline,
          flightNumber: '${100 + rng.nextInt(8900)}',
          from: dest,
          to: beyondCity, // ticketed final destination (skipped)
          departTime: dep2,
          arriveTime: arr2,
          duration: Duration(minutes: leg2Mins),
        ),
      ];

      offers.add(FlightOffer(
        id: 'hidden-$origin-$dest-$beyondCity-$i',
        segments: segments,
        totalPrice: price,
        isHiddenCity: true,
        hiddenCityExitPoint: dest,
        airline: airline,
        stops: 1,
        totalDuration: arr2.difference(depart),
        bookingUrl: 'https://www.google.com/travel/flights',
      ));
    }
    return offers;
  }

  int _seed(String from, String to, DateTime date) {
    var h = 7;
    for (final c in 'hidden$from$to'.codeUnits) {
      h = h * 31 + c;
    }
    return h * 31 + date.day + date.month * 31;
  }
}
