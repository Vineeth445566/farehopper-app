import 'package:flutter/material.dart';

import '../data/airports.dart';
import '../models/flight.dart';
import 'explainer_screen.dart';
import 'explore_screen.dart';
import 'results_screen.dart';
import 'watchlist_screen.dart';

/// Airport/metro picker with type-ahead search.
class _AirportField extends StatefulWidget {
  final String label;
  final AirportOption? value;
  final ValueChanged<AirportOption?> onChanged;
  final AirportOption? exclude;

  const _AirportField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.exclude,
  });

  @override
  State<_AirportField> createState() => _AirportFieldState();
}

class _AirportFieldState extends State<_AirportField> {
  late final TextEditingController _controller;

  String _display(AirportOption? v) => v == null ? '' : v.city;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _display(widget.value));
  }

  @override
  void didUpdateWidget(covariant _AirportField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = _display(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = airportOptions;
    return Autocomplete<AirportOption>(
      displayStringForOption: _display,
      optionsBuilder: (text) {
        final q = text.text.trim().toLowerCase();
        return options.where((a) {
          if (a.code == widget.exclude?.code) return false;
          if (q.isEmpty) return true;
          return a.code.toLowerCase().contains(q) ||
              a.city.toLowerCase().contains(q) ||
              a.subtitle.toLowerCase().contains(q);
        });
      },
      onSelected: widget.onChanged,
      fieldViewBuilder: (context, _, focusNode, onSubmitted) {
        return TextField(
          controller: _controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: const Icon(Icons.flight),
            border: const OutlineInputBorder(),
            suffixIcon: widget.value != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged(null);
                    },
                  )
                : null,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, opts) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 32,
              height: 260,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: opts.length,
                itemBuilder: (context, i) {
                  final a = opts.elementAt(i);
                  return ListTile(
                    leading: a.isMetro
                        ? const Icon(Icons.location_city)
                        : Text(a.code,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                    title: Text(a.city),
                    subtitle: Text(a.subtitle,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => onSelected(a),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  AirportOption? _from = airportOptions
      .firstWhere((o) => o.code == 'PHX', orElse: () => airportOptions.first);
  AirportOption? _to;
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  int _passengers = 1;
  bool _roundTrip = false;
  CabinClass _cabin = CabinClass.economy;

  void _swap() {
    setState(() {
      final tmp = _from;
      _from = _to;
      _to = tmp;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now,
      lastDate: now.add(const Duration(days: 330)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  SearchQuery? _buildQuery() {
    if (_from == null || _to == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select both a departure and arrival airport.')),
      );
      return null;
    }
    return SearchQuery(
      from: _from!.code,
      to: _to!.code,
      date: _date,
      passengers: _passengers,
      roundTrip: _roundTrip,
      cabin: _cabin,
    );
  }

  void _search() {
    final q = _buildQuery();
    if (q == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResultsScreen(query: q)),
    );
  }

  void _explore() {
    if (_from == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pick an origin airport to explore from.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExploreScreen(
          origin: _from!.code,
          date: _date,
          cabin: _cabin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight_takeoff),
            SizedBox(width: 8),
            Text('FareHopper'),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Watched fares',
            icon: const Icon(Icons.bookmark_border),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const WatchlistScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Find the cheapest US domestic fares.',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Domestic US flights only. Metro codes like NYC search all area airports. Hidden-city deals included.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // From / To
            Row(
              children: [
                Expanded(
                  child: _AirportField(
                    label: 'From',
                    value: _from,
                    exclude: _to,
                    onChanged: (a) => setState(() => _from = a),
                  ),
                ),
                IconButton(
                  tooltip: 'Swap origin and destination',
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: _swap,
                ),
                Expanded(
                  child: _AirportField(
                    label: 'To',
                    value: _to,
                    exclude: _from,
                    onChanged: (a) => setState(() => _to = a),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Date + passengers
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      '${_date.month}/${_date.day}/${_date.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: theme.colorScheme.outline),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: _passengers > 1
                              ? () => setState(() => _passengers--)
                              : null,
                        ),
                        Text('$_passengers',
                            style: theme.textTheme.titleMedium),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _passengers < 6
                              ? () => setState(() => _passengers++)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Trip type toggle
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    label: Text('One-way'),
                    icon: Icon(Icons.arrow_forward)),
                ButtonSegment(
                    value: true,
                    label: Text('Round-trip'),
                    icon: Icon(Icons.swap_horiz)),
              ],
              selected: {_roundTrip},
              onSelectionChanged: (s) =>
                  setState(() => _roundTrip = s.first),
            ),
            if (_roundTrip)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Hidden-city fares only apply to one-way trips.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // Cabin class
            Text('Cabin', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<CabinClass>(
              segments: const [
                ButtonSegment(
                    value: CabinClass.economy,
                    label: Text('Economy')),
                ButtonSegment(
                    value: CabinClass.premium,
                    label: Text('Premium')),
                ButtonSegment(
                    value: CabinClass.business,
                    label: Text('Business')),
              ],
              selected: {_cabin},
              onSelectionChanged: (s) =>
                  setState(() => _cabin = s.first),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.search),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Find cheap flights',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            // Explore section
            Row(
              children: [
                Icon(Icons.explore,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Explore from ${_from?.city ?? '...'}',
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Not sure where to go? See the cheapest destinations from your origin on ${_date.month}/${_date.day}.',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _explore,
              icon: const Icon(Icons.map),
              label: const Text('Explore cheap destinations'),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ExplainerScreen()),
                ),
                icon: const Icon(Icons.help_outline),
                label: const Text('How hidden-city fares work'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
