import 'package:flutter_test/flutter_test.dart';

import 'package:fare_finder/main.dart';

void main() {
  testWidgets('App boots with Cash and Awards tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FareHopperApp());
    await tester.pumpAndSettle();

    expect(find.text('Cash fares'), findsOneWidget);
    expect(find.text('Award flights'), findsOneWidget);
    expect(find.text('FareHopper'), findsOneWidget);

    // Switch to the Awards tab.
    await tester.tap(find.text('Award flights'));
    await tester.pumpAndSettle();
    expect(find.text('Find award flights'), findsOneWidget);
  });
}
