import 'package:flutter/material.dart';

import '../models/flight.dart';
import '../services/flight_service.dart';
import 'results_screen.dart';

/// "Where can I go cheap?" — cheapest destinations from an origin.
class ExploreScreen extends StatefulWidget {
  final String origin;
  final DateTime date;
  final CabinClass cabin;

  const ExploreScreen({
    super.key,
    required this.origin,
    required this.date,
    this.cabin = CabinClass.economy,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _service = MockFlightService();
  bool _loading = true;
  List<ExploreDeal> _deals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.delayed(const Duration(milliseconds: 900));
    final deals = _service.exploreDeals(
        widget.origin, widget.date, widget.cabin);
    if (mounted) {
      setState(() {
        _deals = deals;
        _loading = false;
      });
    }
  }

  void _openDeal(ExploreDeal deal) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          query: SearchQuery(
            from: widget.origin,
            to: deal.destinationCode,
            date: widget.date,
            cabin: widget.cabin,
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
        title: Text('Explore from ${widget.origin}'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${widget.date.month}/${widget.date.day}/${widget.date.year} - ${widget.cabin.label} - one-way',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _deals.isEmpty
              ? const Center(
                  child: Text('No deals found.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.15,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _deals.length,
                  itemBuilder: (context, i) {
                    final deal = _deals[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _openDeal(deal),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.location_on,
                                      color: theme
                                          .colorScheme.primary,
                                      size: 20),
                                  const SizedBox(width: 4),
                                  Text(deal.destinationCode,
                                      style: theme
                                          .textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight:
                                                  FontWeight.bold)),
                                ],
                              ),
                              Text(deal.city,
                                  style: theme.textTheme.bodyMedium),
                              Text(
                                'from \$${deal.price.toStringAsFixed(0)}',
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
