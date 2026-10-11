import 'package:flutter/material.dart';

import '../models/flight.dart';

/// -1 = any, 0 = nonstop only, 1 = up to 1 stop.
class FlightFilters {
  final double maxPrice;
  final int maxStops;
  final Set<String> airlines;

  const FlightFilters({
    this.maxPrice = 700,
    this.maxStops = -1,
    this.airlines = const {},
  });

  FlightFilters copyWith({
    double? maxPrice,
    int? maxStops,
    Set<String>? airlines,
  }) =>
      FlightFilters(
        maxPrice: maxPrice ?? this.maxPrice,
        maxStops: maxStops ?? this.maxStops,
        airlines: airlines ?? this.airlines,
      );

  bool matches(FlightOffer o) {
    if (o.totalPrice > maxPrice) return false;
    if (maxStops >= 0 && o.stops > maxStops) return false;
    if (airlines.isNotEmpty && !airlines.contains(o.airline)) {
      return false;
    }
    return true;
  }
}

class FilterSheet extends StatefulWidget {
  final FlightFilters initial;
  final List<FlightOffer> offers;

  const FilterSheet({
    super.key,
    required this.initial,
    required this.offers,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late double _maxPrice;
  late int _maxStops;
  late Set<String> _airlines;

  @override
  void initState() {
    super.initState();
    _maxPrice = widget.initial.maxPrice;
    _maxStops = widget.initial.maxStops;
    _airlines = Set.of(widget.initial.airlines);
  }

  @override
  Widget build(BuildContext context) {
    final allAirlines = widget.offers.map((o) => o.airline).toSet().toList()
      ..sort();
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filters',
                    style: theme.textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Max price: \$${_maxPrice.round()}',
                style: theme.textTheme.titleSmall),
            Slider(
              min: 100,
              max: 700,
              divisions: 12,
              value: _maxPrice,
              label: '\$${_maxPrice.round()}',
              onChanged: (v) => setState(() => _maxPrice = v),
            ),
            const SizedBox(height: 8),
            Text('Stops', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: -1, label: Text('Any')),
                ButtonSegment(value: 0, label: Text('Nonstop')),
                ButtonSegment(value: 1, label: Text('1 stop max')),
              ],
              selected: {_maxStops},
              onSelectionChanged: (s) =>
                  setState(() => _maxStops = s.first),
            ),
            const SizedBox(height: 16),
            Text('Airlines', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allAirlines.map((a) {
                final selected = _airlines.contains(a);
                return FilterChip(
                  label: Text(a),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _airlines.add(a);
                    } else {
                      _airlines.remove(a);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                FlightFilters(
                  maxPrice: _maxPrice,
                  maxStops: _maxStops,
                  airlines: _airlines,
                ),
              ),
              child: const Text('Apply filters'),
            ),
          ],
        ),
      ),
    );
  }
}
