/// API credentials for the live Amadeus provider.
///
/// Fill these in when you have Amadeus Self-Service API keys, or supply them
/// with --dart-define (see FlightServiceFactory). While empty, the app uses
/// the deterministic mock service.
class AppConfig {
  static const String amadeusApiKey = String.fromEnvironment(
    'AMADEUS_API_KEY',
    defaultValue: '',
  );
  static const String amadeusApiSecret = String.fromEnvironment(
    'AMADEUS_API_SECRET',
    defaultValue: '',
  );

  /// seats.aero Partner API key for live award availability.
  /// Free to try at https://developers.seats.aero — pass with
  /// --dart-define=SEATS_AERO_API_KEY=your_key
  static const String seatsAeroApiKey = String.fromEnvironment(
    'SEATS_AERO_API_KEY',
    defaultValue: '',
  );
}
