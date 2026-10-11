import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/flight.dart';
import '../models/watch.dart';
import '../services/flight_service.dart';
import '../services/hidden_city.dart';
import '../services/watch_service.dart';
import 'itinerary_detail.dart';
import '../widgets/filter_sheet.dart';

enum SortOption { price, duration, departure }

String _fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return '${h}h ${m}m';
}

String _fmtMoney(double v) =>
    NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(v);

class ResultsScreen extends StatefulWidget {
  final SearchQuery query;

  const ResultsScreen({super.key, required this.query});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _service = FlightServiceFactory.create();
  final _hiddenCityFinder = HiddenCityFinder();

  bool _loading = true;
  List<FlightOffer> _offers = [];
  List<FlightOffer> _visible = [];
  SortOption _sort = SortOption.price;
  FlightFilters _filters = const FlightFilters();
  String? _priceDropMessage;

  @override
  void initState() {
    super.initState();
    _runSearch();
  }

  Future<void> _runSearch() async {
    setState(() {
      _loading = true;
      _priceDropMessage = null;
    });
    try {
      // Simulated latency so the loading state is visible with mock data.
      await Future.delayed(const Duration(milliseconds: 1200));
      final regular = await _service.search(widget.query);
      final hidden = widget.query.roundTrip
          ? <FlightOffer>[]
          : _hiddenCityFinder.find(
              from: widget.query.from,
              to: widget.query.to,
              date: widget.query.date,
              regularOffers: regular,
            );
      _offers = [...hidden, ...regular];
      await _checkWatch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
      _offers = [];
    }
    if (mounted) {
      setState(() => _loading = false);
      _applySortAndFilter();
    }
  }

  /// In-app price-drop detection against saved watches.
  Future<void> _checkWatch() async {
    if (_offers.isEmpty) return;
    final watchService = WatchService.instance;
    final watch = watchService.findFor(
        widget.query.from, widget.query.to, widget.query.date);
    if (watch == null) return;
    final cheapest =
        _offers.map((o) => o.totalPrice).reduce((a, b) => a < b ? a : b);
    if (cheapest < watch.targetPrice) {
      _priceDropMessage =
          'Price dropped! Now ${_fmtMoney(cheapest)} — below your ${_fmtMoney(watch.targetPrice)} target.';
    } else if (watch.lastSeenPrice != null &&
        cheapest < watch.lastSeenPrice!) {
      _priceDropMessage =
          'Price dropped to ${_fmtMoney(cheapest)} (was ${_fmtMoney(watch.lastSeenPrice!)}).';
    }
    await watchService.updateLastSeen(watch.id, cheapest);
  }

  Future<void> _watchRoute() async {
    if (_offers.isEmpty) return;
    final cheapest =
        _offers.map((o) => o.totalPrice).reduce((a, b) => a < b ? a : b);
    final controller =
        TextEditingController(text: cheapest.round().toString());
    final target = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Watch this route'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alert me when ${widget.query.from} to ${widget.query.to} drops below:',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                prefixText: '\$',
                border: OutlineInputBorder(),
                labelText: 'Target price',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context)
                .pop(double.tryParse(controller.text)),
            child: const Text('Watch'),
          ),
        ],
      ),
    );
    if (target == null || target <= 0) return;
    final watch = Watch(
      id: 'watch-${widget.query.from}-${widget.query.to}-'
          '${widget.query.date.millisecondsSinceEpoch}',
      from: widget.query.from,
      to: widget.query.to,
      date: widget.query.date,
      targetPrice: target,
      createdAt: DateTime.now(),
      lastSeenPrice: cheapest,
    );
    await WatchService.instance.add(watch);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Watching ${widget.query.from} to ${widget.query.to} below ${_fmtMoney(target)}.')),
      );
    }
  }

  void _applySortAndFilter() {
    var list = _offers.where(_filters.matches).toList();
    switch (_sort) {
      case SortOption.price:
        list.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
      case SortOption.duration:
        list.sort((a, b) => a.totalDuration.compareTo(b.totalDuration));
      case SortOption.departure:
        list.sort((a, b) => a.departTime.compareTo(b.departTime));
    }
    setState(() => _visible = list);
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<FlightFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FilterSheet(
        initial: _filters,
        offers: _offers,
      ),
    );
    if (result != null) {
      _filters = result;
      _applySortAndFilter();
    }
  }

  void _openDetail(FlightOffer offer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ItineraryDetail(offer: offer),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.query;
    final dateStr =
        '${q.date.month}/${q.date.day}/${q.date.year}';
    return Scaffold(
      appBar: AppBar(
        title: Text('${q.from} to ${q.to}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '$dateStr - ${q.passengers} traveler${q.passengers > 1 ? 's' : ''}'
              '${q.roundTrip ? ' - Round-trip' : ' - One-way'}'
              ' - ${q.cabin.label}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<SortOption>(
              value: _sort,
              icon: const Icon(Icons.sort),
              items: const [
                DropdownMenuItem(
                    value: SortOption.price, child: Text('Price')),
                DropdownMenuItem(
                    value: SortOption.duration,
                    child: Text('Duration')),
                DropdownMenuItem(
                    value: SortOption.departure,
                    child: Text('Departure')),
              ],
              onChanged: (v) {
                if (v != null) {
                  _sort = v;
                  _applySortAndFilter();
                }
              },
            ),
          ),
          IconButton(
            tooltip: 'Watch this route',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: _watchRoute,
          ),
          IconButton(
            tooltip: 'Filters',
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_priceDropMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              color: Theme.of(context)
                  .colorScheme
                  .tertiaryContainer,
              child: Row(
                children: [
                  Icon(Icons.trending_down,
                      color: Theme.of(context)
                          .colorScheme
                          .onTertiaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _priceDropMessage!,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? _buildLoading()
                : _visible.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _runSearch,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _visible.length,
                          itemBuilder: (context, i) => _OfferCard(
                            offer: _visible[i],
                            onTap: () =>
                                _openDetail(_visible[i]),
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
          height: 96,
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
          const Icon(Icons.flight_takeoff,
              size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('No flights found',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
              'Try different dates or loosen your filters.'),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              _filters = const FlightFilters();
              _applySortAndFilter();
            },
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final FlightOffer offer;
  final VoidCallback onTap;

  const _OfferCard({required this.offer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFmt = DateFormat('h:mm a');
    final stopsText = offer.stops == 0
        ? 'Nonstop'
        : '${offer.stops} stop${offer.stops > 1 ? 's' : ''} - '
            '${offer.segments.sublist(0, offer.segments.length - 1).map((s) => s.to).join(', ')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (offer.isHiddenCity) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_off,
                              size: 14,
                              color: theme
                                  .colorScheme.onTertiaryContainer),
                          const SizedBox(width: 4),
                          Text('HIDDEN-CITY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme
                                    .colorScheme.onTertiaryContainer,
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        HiddenCityWarnings.exitLine(
                            offer.hiddenCityExitPoint ?? ''),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(offer.airline,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(
                                    color: theme.colorScheme
                                        .onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(
                          '${timeFmt.format(offer.departTime)} - '
                          '${timeFmt.format(offer.arriveTime)}',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${offer.departureCode} - ${offer.arrivalCode}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_fmtDuration(offer.totalDuration)} - $stopsText',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme
                                  .onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _fmtMoney(offer.totalPrice),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
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
