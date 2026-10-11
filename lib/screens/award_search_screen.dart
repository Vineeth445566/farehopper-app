import 'package:flutter/material.dart';

import '../data/airports.dart';
import '../models/award.dart';
import '../services/award_service.dart';
import 'award_results_screen.dart';

/// Reuse the cash search screen's airport picker via a shared widget.
/// (Defined locally to keep the award tab self-contained.)
class _AwardAirportField extends StatefulWidget {
  final String label;
  final AirportOption? value;
  final ValueChanged<AirportOption?> onChanged;
  final AirportOption? exclude;

  const _AwardAirportField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.exclude,
  });

  @override
  State<_AwardAirportField> createState() => _AwardAirportFieldState();
}

class _AwardAirportFieldState extends State<_AwardAirportField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.value?.city ?? '');
  }

  @override
  void didUpdateWidget(covariant _AwardAirportField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = widget.value?.city ?? '';
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
      displayStringForOption: (a) => a.city,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
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

class AwardSearchScreen extends StatefulWidget {
  const AwardSearchScreen({super.key});

  @override
  State<AwardSearchScreen> createState() => _AwardSearchScreenState();
}

class _AwardSearchScreenState extends State<AwardSearchScreen> {
  AirportOption? _from = airportOptions
      .firstWhere((o) => o.code == 'PHX', orElse: () => airportOptions.first);
  AirportOption? _to;
  DateTime _start = DateTime.now().add(const Duration(days: 1));
  DateTime _end = DateTime.now().add(const Duration(days: 30));
  final Set<AwardCabin> _cabins = {AwardCabin.economy};
  final Set<String> _programs = {};

  static const _programOptions = [
    ('united', 'United MileagePlus'),
    ('american', 'American AAdvantage'),
    ('delta', 'Delta SkyMiles'),
    ('alaska', 'Alaska Mileage Plan'),
    ('aeroplan', 'Aeroplan'),
    ('flyingblue', 'Flying Blue'),
    ('jetblue', 'JetBlue TrueBlue'),
  ];

  void _swap() {
    setState(() {
      final tmp = _from;
      _from = _to;
      _to = tmp;
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 330)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end.isBefore(_start)) {
          _end = _start.add(const Duration(days: 7));
        }
      } else {
        _end = picked;
        if (_start.isAfter(_end)) {
          _start = _end.subtract(const Duration(days: 7));
        }
      }
    });
  }

  void _search() {
    if (_from == null || _to == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select both a departure and arrival airport.')),
      );
      return;
    }
    if (_cabins.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select at least one cabin class.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AwardResultsScreen(
          query: AwardQuery(
            from: _from!.code,
            to: _to!.code,
            startDate: _start,
            endDate: _end,
            cabins: _cabins.toList(),
            programs: _programs,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Award flights'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Search award availability by miles.',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              AwardServiceFactory.isMock
                  ? 'Live award data needs a seats.aero Pro API key (free to try); showing sample data until configured.'
                  : 'Live award availability via seats.aero.',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _AwardAirportField(
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
                  child: _AwardAirportField(
                    label: 'To',
                    value: _to,
                    exclude: _from,
                    onChanged: (a) => setState(() => _to = a),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(true),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                        'From ${_start.month}/${_start.day}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(false),
                    icon: const Icon(Icons.calendar_today),
                    label:
                        Text('To ${_end.month}/${_end.day}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Cabins', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: AwardCabin.values.map((c) {
                final selected = _cabins.contains(c);
                return FilterChip(
                  label: Text(c.label),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _cabins.add(c);
                    } else {
                      _cabins.remove(c);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('Programs (all if none selected)',
                style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _programOptions.map((p) {
                final selected = _programs.contains(p.$1);
                return FilterChip(
                  label: Text(p.$2),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _programs.add(p.$1);
                    } else {
                      _programs.remove(p.$1);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.search),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Find award flights',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
