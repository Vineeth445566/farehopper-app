import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/airports.dart';
import '../models/award.dart';
import '../services/award_service.dart';

String _fmtMiles(int miles) {
  if (miles >= 1000) {
    final k = miles / 1000;
    return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}k';
  }
  return '$miles';
}

class AwardResultsScreen extends StatefulWidget {
  final AwardQuery query;

  const AwardResultsScreen({super.key, required this.query});

  @override
  State<AwardResultsScreen> createState() => _AwardResultsScreenState();
}

class _AwardResultsScreenState extends State<AwardResultsScreen> {
  final _service = AwardServiceFactory.create();

  bool _loading = true;
  List<AwardOffer> _offers = [];
  List<AwardOffer> _visible = [];
  double _maxMiles = 100000;
  final Set<AwardCabin> _cabins = {};
  final Set<String> _programs = {};

  @override
  void initState() {
    super.initState();
    _runSearch();
  }

  Future<void> _runSearch() async {
    setState(() => _loading = true);
    try {
      await Future.delayed(const Duration(milliseconds: 1200));
      _offers = await _service.search(widget.query);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Award search failed: $e')),
        );
      }
      _offers = [];
    }
    if (mounted) {
      setState(() => _loading = false);
      _applyFilters();
    }
  }

  void _applyFilters() {
    setState(() {
      _visible = _offers.where((o) {
        if (o.mileageCost > _maxMiles) return false;
        if (_cabins.isNotEmpty && !_cabins.contains(o.cabin)) {
          return false;
        }
        if (_programs.isNotEmpty &&
            !_programs.contains(o.programCode)) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  Future<void> _openFilters() async {
    final allPrograms = _offers.map((o) => o.programCode).toSet().toList()
      ..sort();
    final programNames = {
      for (final o in _offers) o.programCode: o.program
    };
    await showModalBottomSheet(
      context: context,
      builder: (_) => _AwardFilterSheet(
        maxMiles: _maxMiles,
        cabins: _cabins,
        programs: _programs,
        allPrograms: allPrograms,
        programNames: programNames,
        onApply: (maxMiles, cabins, programs) {
          _maxMiles = maxMiles;
          _cabins
            ..clear()
            ..addAll(cabins);
          _programs
            ..clear()
            ..addAll(programs);
          _applyFilters();
        },
      ),
    );
  }

  void _openDetail(AwardOffer offer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AwardDetail(offer: offer),
    );
  }

  /// Builds a PointsYeah deep link with the current search pre-filled.
  /// PointsYeah is a free award search tool (no API key needed) — this
  /// hands off to their live search in the browser.
  Uri _pointsYeahUrl() {
    final q = widget.query;
    final cabins = q.cabins.isEmpty
        ? AwardCabin.values
        : q.cabins;
    return Uri.https('www.pointsyeah.com', '/search', {
      'departure': primaryAirport(q.from),
      'arrival': primaryAirport(q.to),
      'startDate': _fmtDate(q.startDate),
      'endDate': _fmtDate(q.endDate),
      'cabins': cabins.map((c) => c.name).join(','),
      'trip': 'oneway',
    });
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _openPointsYeah() async {
    final uri = _pointsYeahUrl();
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open PointsYeah')),
        );
      }
    }
  }

  Widget _buildLiveSearchBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: Colors.amber),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Showing sample award data',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text(
                    'Tap below for live award availability '
                    'on PointsYeah (free).',
                    style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: _openPointsYeah,
            child: const Text('Search live'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.query;
    final range =
        '${q.startDate.month}/${q.startDate.day} - ${q.endDate.month}/${q.endDate.day}';
    return Scaffold(
      appBar: AppBar(
        title: Text('${q.from} to ${q.to}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(range,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Filters',
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilters,
          ),
        ],
      ),
      body: _loading
          ? _buildLoading()
          : _visible.isEmpty
              ? _buildEmpty()
              : Column(
                  children: [
                    if (AwardServiceFactory.isMock)
                      _buildLiveSearchBanner(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _runSearch,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _visible.length,
                          itemBuilder: (context, i) => _AwardCard(
                            offer: _visible[i],
                            onTap: () => _openDetail(_visible[i]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 6,
      itemBuilder: (context, i) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 104,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.card_giftcard,
              size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('No award availability',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
              'Try widening the date range or loosening filters.'),
        ],
      ),
    );
  }
}

class _AwardCard extends StatelessWidget {
  final AwardOffer offer;
  final VoidCallback onTap;

  const _AwardCard({required this.offer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat('EEE, MMM d');
    final stopsText =
        offer.stops == 0 ? 'Nonstop' : '${offer.stops} stop';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(offer.program,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                theme.colorScheme.onSurfaceVariant)),
                  ),
                  if (offer.isSaver)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade800,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('SAVER',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(offer.cabin.label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme
                                .onSecondaryContainer)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${offer.origin} to ${offer.destination}',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${dateFmt.format(offer.date)} - ${offer.airline} - $stopsText',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme
                                  .onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_fmtMiles(offer.mileageCost)} miles',
                        style:
                            theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        '+\$${offer.plusCashFees.toStringAsFixed(2)} fees',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AwardFilterSheet extends StatefulWidget {
  final double maxMiles;
  final Set<AwardCabin> cabins;
  final Set<String> programs;
  final List<String> allPrograms;
  final Map<String, String> programNames;
  final void Function(
      double maxMiles, Set<AwardCabin> cabins, Set<String> programs) onApply;

  const _AwardFilterSheet({
    required this.maxMiles,
    required this.cabins,
    required this.programs,
    required this.allPrograms,
    required this.programNames,
    required this.onApply,
  });

  @override
  State<_AwardFilterSheet> createState() => _AwardFilterSheetState();
}

class _AwardFilterSheetState extends State<_AwardFilterSheet> {
  late double _maxMiles;
  late Set<AwardCabin> _cabins;
  late Set<String> _programs;

  @override
  void initState() {
    super.initState();
    _maxMiles = widget.maxMiles;
    _cabins = Set.of(widget.cabins);
    _programs = Set.of(widget.programs);
  }

  @override
  Widget build(BuildContext context) {
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
            Text('Max miles: ${_fmtMiles(_maxMiles.round())}',
                style: theme.textTheme.titleSmall),
            Slider(
              min: 10000,
              max: 100000,
              divisions: 9,
              value: _maxMiles,
              label: _fmtMiles(_maxMiles.round()),
              onChanged: (v) => setState(() => _maxMiles = v),
            ),
            const SizedBox(height: 8),
            Text('Cabins', style: theme.textTheme.titleSmall),
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
            const SizedBox(height: 12),
            Text('Programs', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.allPrograms.map((p) {
                final selected = _programs.contains(p);
                return FilterChip(
                  label: Text(
                      widget.programNames[p] ?? p),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _programs.add(p);
                    } else {
                      _programs.remove(p);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                widget.onApply(_maxMiles, _cabins, _programs);
                Navigator.of(context).pop();
              },
              child: const Text('Apply filters'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AwardDetail extends StatelessWidget {
  final AwardOffer offer;

  const _AwardDetail({required this.offer});

  Future<void> _openBooking(BuildContext context) async {
    final uri = Uri.parse(offer.bookingUrl);
    if (!await launchUrl(uri,
        mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open booking link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat('EEEE, MMMM d, yyyy');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(offer.program,
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${offer.origin} to ${offer.destination} - ${dateFmt.format(offer.date)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _row('Cabin', offer.cabin.label),
            _row('Airline', offer.airline),
            _row('Stops',
                offer.stops == 0 ? 'Nonstop' : '${offer.stops}'),
            _row('Miles required',
                '${NumberFormat('#,###').format(offer.mileageCost)} miles'),
            _row('Cash fees',
                '\$${offer.plusCashFees.toStringAsFixed(2)}'),
            if (offer.isSaver)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Saver availability — this is a good-value redemption for this route.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _openBooking(context),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Continue to book'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
