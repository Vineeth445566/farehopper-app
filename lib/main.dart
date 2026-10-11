import 'package:flutter/material.dart';

import 'screens/award_search_screen.dart';
import 'screens/search_screen.dart';

void main() {
  runApp(const FareHopperApp());
}

class FareHopperApp extends StatelessWidget {
  const FareHopperApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Deep navy/slate surfaces with an amber accent.
    const seedAmber = Color(0xFFF5A623);
    final darkScheme = ColorScheme.fromSeed(
      seedColor: seedAmber,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF0F172A), // deep navy
      surfaceContainerHighest: const Color(0xFF1E293B), // slate
      primary: seedAmber,
      tertiary: const Color(0xFFFBBF24),
      tertiaryContainer: const Color(0xFF78350F),
      onTertiaryContainer: const Color(0xFFFEF3C7),
    );

    return MaterialApp(
      title: 'FareHopper',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
      ),
      home: const HomeTabs(),
    );
  }
}

class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});

  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int _index = 0;

  static const _pages = [
    SearchScreen(), // Cash fares (watchlist + explore live here)
    AwardSearchScreen(), // Award flights
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.attach_money),
            label: 'Cash fares',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_giftcard),
            label: 'Award flights',
          ),
        ],
      ),
    );
  }
}
