import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/airports.dart';
import '../models/flight.dart';
import '../services/hidden_city.dart';

String _fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

/// Bottom sheet with the full segment timeline, price breakdown and
/// hidden-city warnings.
class ItineraryDetail extends StatelessWidget {
  final FlightOffer offer;

  const ItineraryDetail({super.key, required this.offer});

  Future<void> _openBooking(BuildContext context) async {
    final uri = Uri.parse(offer.bookingUrl);
    final ok = await launchUrl(uri,
        mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not open booking link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFmt = DateFormat('h:mm a');
    final base = offer.totalPrice * 0.82;
    final fees = offer.totalPrice - base;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Itinerary',
                    style: theme.textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${offer.airline} - ${offer.cabin.label} - '
              '${cityName(offer.departureCode)} to ${cityName(offer.arrivalCode)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            // Segment timeline
            ..._buildTimeline(context, timeFmt),
            const SizedBox(height: 16),
            const Divider(),
            _priceRow('Base fare',
                '\$${base.toStringAsFixed(2)}'),
            _priceRow('Taxes & fees',
                '\$${fees.toStringAsFixed(2)}'),
            _priceRow('Total',
                '\$${offer.totalPrice.toStringAsFixed(2)}',
                bold: true),
            if (offer.isHiddenCity) ...[
              const SizedBox(height: 16),
              _buildHiddenCityWarning(context),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _openBooking(context),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Continue to book'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                final ref =
                    '${offer.departureCode}-${offer.arrivalCode} '
                    '${offer.airline} '
                    '\$${offer.totalPrice.toStringAsFixed(2)}';
                Clipboard.setData(ClipboardData(text: ref));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Itinerary copied.')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy itinerary reference'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTimeline(
      BuildContext context, DateFormat timeFmt) {
    final widgets = <Widget>[];
    for (var i = 0; i < offer.segments.length; i++) {
      final s = offer.segments[i];
      final isExit = offer.isHiddenCity &&
          s.to == offer.hiddenCityExitPoint;
      widgets.add(
        _segmentRow(context, s, timeFmt, isExit: isExit),
      );
      if (i < offer.segments.length - 1) {
        final layover = offer.segments[i + 1].departTime
            .difference(s.arriveTime);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 7, top: 4, bottom: 4),
            child: Row(
              children: [
                Container(
                    width: 2, height: 28,
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant),
                const SizedBox(width: 12),
                Text(
                  'Layover in ${s.to} - ${_fmtDuration(layover)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _segmentRow(BuildContext context, FlightSegment s,
      DateFormat timeFmt,
      {bool isExit = false}) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(Icons.circle,
                size: 14, color: theme.colorScheme.primary),
            Container(
                width: 2, height: 52,
                color: theme.colorScheme.outlineVariant),
            Icon(Icons.circle,
                size: 14, color: theme.colorScheme.primary),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(timeFmt.format(s.departTime),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                  Text(s.from,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Text(cityName(s.from),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '${s.airline} ${s.flightNumber} - ${_fmtDuration(s.duration)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(timeFmt.format(s.arriveTime),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Text(s.to,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      if (isExit) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme
                                .colorScheme.tertiaryContainer,
                            borderRadius:
                                BorderRadius.circular(4),
                          ),
                          child: Text('GET OFF HERE',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme
                                      .onTertiaryContainer)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              Text(cityName(s.to),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _priceRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value,
              style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildHiddenCityWarning(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.tertiary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber,
                  color: theme.colorScheme.tertiary),
              const SizedBox(width: 8),
              Text('Hidden-city fare — read before booking',
                  style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(HiddenCityWarnings.short,
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          ...HiddenCityWarnings.rules.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text('-  '),
                  Expanded(child: Text(r)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
