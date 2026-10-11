/// Major US domestic airports searchable in FareHopper.
class Airport {
  final String code;
  final String city;
  final String name;

  const Airport({required this.code, required this.city, required this.name});
}

const List<Airport> usAirports = [
  Airport(code: 'ATL', city: 'Atlanta', name: 'Hartsfield-Jackson Atlanta Intl'),
  Airport(code: 'AUS', city: 'Austin', name: 'Austin-Bergstrom Intl'),
  Airport(code: 'BNA', city: 'Nashville', name: 'Nashville Intl'),
  Airport(code: 'BOS', city: 'Boston', name: 'Logan Intl'),
  Airport(code: 'BUR', city: 'Burbank', name: 'Hollywood Burbank'),
  Airport(code: 'BWI', city: 'Baltimore', name: 'BWI Thurgood Marshall'),
  Airport(code: 'CLT', city: 'Charlotte', name: 'Charlotte Douglas Intl'),
  Airport(code: 'DCA', city: 'Washington DC', name: 'Reagan National'),
  Airport(code: 'DEN', city: 'Denver', name: 'Denver Intl'),
  Airport(code: 'DFW', city: 'Dallas', name: 'Dallas/Fort Worth Intl'),
  Airport(code: 'DTW', city: 'Detroit', name: 'Detroit Metro Wayne County'),
  Airport(code: 'EWR', city: 'Newark', name: 'Newark Liberty Intl'),
  Airport(code: 'FLL', city: 'Fort Lauderdale', name: 'Fort Lauderdale Intl'),
  Airport(code: 'HNL', city: 'Honolulu', name: 'Daniel K. Inouye Intl'),
  Airport(code: 'IAH', city: 'Houston', name: 'George Bush Intercontinental'),
  Airport(code: 'IAD', city: 'Washington DC', name: 'Washington Dulles Intl'),
  Airport(code: 'JFK', city: 'New York', name: 'John F. Kennedy Intl'),
  Airport(code: 'LAS', city: 'Las Vegas', name: 'Harry Reid Intl'),
  Airport(code: 'LAX', city: 'Los Angeles', name: 'Los Angeles Intl'),
  Airport(code: 'LGA', city: 'New York', name: 'LaGuardia'),
  Airport(code: 'MCO', city: 'Orlando', name: 'Orlando Intl'),
  Airport(code: 'MDW', city: 'Chicago', name: 'Chicago Midway'),
  Airport(code: 'MIA', city: 'Miami', name: 'Miami Intl'),
  Airport(code: 'MSP', city: 'Minneapolis', name: 'Minneapolis-Saint Paul Intl'),
  Airport(code: 'OAK', city: 'Oakland', name: 'Oakland Intl'),
  Airport(code: 'ORD', city: 'Chicago', name: "Chicago O'Hare Intl"),
  Airport(code: 'PDX', city: 'Portland', name: 'Portland Intl'),
  Airport(code: 'PHL', city: 'Philadelphia', name: 'Philadelphia Intl'),
  Airport(code: 'PHX', city: 'Phoenix', name: 'Phoenix Sky Harbor Intl'),
  Airport(code: 'SAN', city: 'San Diego', name: 'San Diego Intl'),
  Airport(code: 'SEA', city: 'Seattle', name: 'Seattle-Tacoma Intl'),
  Airport(code: 'SFO', city: 'San Francisco', name: 'San Francisco Intl'),
  Airport(code: 'SJC', city: 'San Jose', name: 'Norman Y. Mineta San Jose Intl'),
  Airport(code: 'SLC', city: 'Salt Lake City', name: 'Salt Lake City Intl'),
  Airport(code: 'SNA', city: 'Orange County', name: 'John Wayne'),
  Airport(code: 'TPA', city: 'Tampa', name: 'Tampa Intl'),
];

/// A multi-airport metro code, e.g. NYC covers JFK, EWR and LGA.
class MetroArea {
  final String code;
  final String city;
  final List<String> airports;

  const MetroArea({
    required this.code,
    required this.city,
    required this.airports,
  });
}

const List<MetroArea> metroAreas = [
  MetroArea(code: 'NYC', city: 'New York', airports: ['JFK', 'EWR', 'LGA']),
  MetroArea(code: 'CHI', city: 'Chicago', airports: ['ORD', 'MDW']),
  MetroArea(code: 'WAS', city: 'Washington DC', airports: ['DCA', 'IAD']),
  MetroArea(code: 'LAXM', city: 'Los Angeles Area', airports: ['LAX', 'BUR', 'SNA']),
  MetroArea(code: 'SFO', city: 'San Francisco Bay', airports: ['SFO', 'SJC', 'OAK']),
  MetroArea(code: 'MIA', city: 'Miami Area', airports: ['MIA', 'FLL']),
];

/// One selectable entry in the airport picker: a metro or a single airport.
class AirportOption {
  final String code;
  final String city;
  final String subtitle;
  final bool isMetro;
  final List<String> members;

  const AirportOption({
    required this.code,
    required this.city,
    required this.subtitle,
    this.isMetro = false,
    this.members = const [],
  });
}

/// Metros first, then individual airports.
List<AirportOption> get airportOptions => [
      for (final m in metroAreas)
        AirportOption(
          code: m.code,
          city: '${m.city} (${m.code})',
          subtitle: 'All airports: ${m.airports.join(', ')}',
          isMetro: true,
          members: m.airports,
        ),
      for (final a in usAirports)
        AirportOption(
          code: a.code,
          city: a.city,
          subtitle: '${a.code} - ${a.name}',
        ),
    ];

Airport? airportByCode(String code) {
  for (final a in usAirports) {
    if (a.code == code) return a;
  }
  return null;
}

MetroArea? metroByCode(String code) {
  for (final m in metroAreas) {
    if (m.code == code) return m;
  }
  return null;
}

bool isMetroCode(String code) => metroByCode(code) != null;

/// Expands a metro code to its member airports; plain codes pass through.
List<String> expandMetro(String code) =>
    metroByCode(code)?.airports ?? [code];

/// First member airport for a metro, or the code itself.
String primaryAirport(String code) => expandMetro(code).first;

String cityName(String code) =>
    metroByCode(code)?.city.split(' (').first ??
    airportByCode(code)?.city ??
    code;
