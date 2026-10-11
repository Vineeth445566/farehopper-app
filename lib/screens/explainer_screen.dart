import 'package:flutter/material.dart';

import '../services/hidden_city.dart';

/// "How hidden-city fares work" explainer.
class ExplainerScreen extends StatelessWidget {
  const ExplainerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hidden-city fares'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How it works',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _step(context, 1, 'Book A to C via B',
                'You buy a ticket from your origin (A) to a farther city (C) that connects through the city you actually want (B).'),
            _step(context, 2, 'Get off at B',
                'When you land at the layover city B, you simply leave the airport. You skip the last leg to C.'),
            _step(context, 3, 'Save 20-60%',
                'Because of how airlines price connecting itineraries, the A-to-C ticket is often much cheaper than a direct A-to-B ticket.'),
            const SizedBox(height: 20),
            Text('Rules to follow',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            ...HiddenCityWarnings.rules.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 20,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(r,
                            style:
                                theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Disclaimer: hidden-city ticketing violates most airlines\u2019 '
                'contracts of carriage. Airlines may cancel return legs, '
                'withhold frequent-flyer credit, or close accounts for repeated '
                'use. FareHopper shows these fares for information; booking is '
                'at your own risk.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(
      BuildContext context, int n, String title, String body) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            child: Text('$n',
                style:
                    const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(
                            fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(body,
                    style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
