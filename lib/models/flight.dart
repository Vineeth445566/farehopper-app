/// A single leg of a trip, e.g. JFK -> DFW on DL 1024.
class FlightSegment {
  final String airline;
  final String flightNumber;
  final String from;
  final String to;
  final DateTime departTime;
  final DateTime arriveTime;
  final Duration duration;

  const FlightSegment({
    required this.airline,
    required this.flightNumber,
    required this.from,
    required this.to,
    required this.departTime,
    required this.arriveTime,
    required this.duration,
  });
}

/// A bookable itinerary: one or more segments plus a price.
class FlightOffer {
  final String id;
  final List<FlightSegment> segments;
  final double totalPrice;
  final String currency;
  final bool isHiddenCity;
  /// Airport code where the traveler actually gets off (a layover city).
  final String? hiddenCityExitPoint;
  final String airline;
  final int stops;
  final Duration totalDuration;
  final String bookingUrl;
  final CabinClass cabin;

  const FlightOffer({
    required this.id,
    required this.segments,
    required this.totalPrice,
    this.currency = 'USD',
    this.isHiddenCity = false,
    this.hiddenCityExitPoint,
    required this.airline,
    required this.stops,
    required this.totalDuration,
    required this.bookingUrl,
    this.cabin = CabinClass.economy,
  });

  String get departureCode => segments.first.from;
  String get arrivalCode => segments.last.to;
  DateTime get departTime => segments.first.departTime;
  DateTime get arriveTime => segments.last.arriveTime;

  /// For hidden-city offers, the code the traveler should look for on the
  /// board is the final ticketed destination (the last segment's arrival).
  String get ticketedDestination => segments.last.to;
}

/// Cabin classes with price multipliers used by the mock fare engine.
enum CabinClass {
  economy('Economy', 1.0),
  premium('Premium Economy', 1.4),
  business('Business', 2.2);

  const CabinClass(this.label, this.multiplier);
  final String label;
  final double multiplier;
}

/// Search parameters entered on the search screen.
/// [from]/[to] may be airport codes or metro codes (NYC, CHI, WAS, ...).
class SearchQuery {
  final String from;
  final String to;
  final DateTime date;
  final int passengers;
  final bool roundTrip;
  final CabinClass cabin;

  const SearchQuery({
    required this.from,
    required this.to,
    required this.date,
    this.passengers = 1,
    this.roundTrip = false,
    this.cabin = CabinClass.economy,
  });
}
