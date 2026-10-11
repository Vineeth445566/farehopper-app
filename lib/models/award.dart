/// Cabin options for award search.
enum AwardCabin {
  economy('Economy', 'Y'),
  premium('Premium', 'W'),
  business('Business', 'J'),
  first('First', 'F');

  const AwardCabin(this.label, this.apiCode);
  final String label;
  /// seats.aero availability/cost field prefix (Y/W/J/F).
  final String apiCode;
}

/// One award itinerary priced in miles + cash fees.
class AwardOffer {
  final String id;
  final String program;
  final String programCode;
  final String origin;
  final String destination;
  final DateTime date;
  final AwardCabin cabin;
  final int mileageCost;
  final double plusCashFees;
  final String airline;
  final int stops;
  final String bookingUrl;
  final bool isSaver;

  const AwardOffer({
    required this.id,
    required this.program,
    required this.programCode,
    required this.origin,
    required this.destination,
    required this.date,
    required this.cabin,
    required this.mileageCost,
    required this.plusCashFees,
    required this.airline,
    required this.stops,
    required this.bookingUrl,
    this.isSaver = false,
  });
}

/// Award search parameters: date RANGE, cabin and program filters.
class AwardQuery {
  final String from;
  final String to;
  final DateTime startDate;
  final DateTime endDate;
  final List<AwardCabin> cabins;
  final Set<String> programs;

  const AwardQuery({
    required this.from,
    required this.to,
    required this.startDate,
    required this.endDate,
    this.cabins = const [AwardCabin.economy],
    this.programs = const {},
  });
}
