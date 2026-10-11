import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/airports.dart';
import '../models/watch.dart';
import '../models/flight.dart';
import '../services/watch_service.dart';
import 'results_screen.dart';

/// Saved fare watches with last seen prices and delete.
class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await WatchService.instance.load();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(Watch w) async {
    await WatchService.instance.remove(w.id);
    setState(() {});
  }

  void _rerun(Watch w) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          query: SearchQuery(
            from: w.from,
            to: w.to,
            date: w.date,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final watches = WatchService.instance.watches;
    final dateFmt = DateFormat('MMM d, yyyy');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watched fares'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : watches.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bookmark_border,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('No watched fares yet',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text(
                        'Run a search and tap the bookmark icon\nto watch a route for price drops.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: watches.length,
                  itemBuilder: (context, i) {
                    final w = watches[i];
                    final belowTarget = w.lastSeenPrice != null &&
                        w.lastSeenPrice! < w.targetPrice;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          Icons.bookmark,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(
                          '${w.from} to ${w.to}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${cityName(w.from)} to ${cityName(w.to)} - ${dateFmt.format(w.date)}'),
                            const SizedBox(height: 2),
                            Text(
                              'Target: \$${w.targetPrice.toStringAsFixed(0)}'
                              '${w.lastSeenPrice != null ? ' - Last seen: \$${w.lastSeenPrice!.toStringAsFixed(0)}' : ''}',
                              style: TextStyle(
                                color: belowTarget
                                    ? theme.colorScheme.tertiary
                                    : null,
                                fontWeight: belowTarget
                                    ? FontWeight.w600
                                    : null,
                              ),
                            ),
                            if (belowTarget)
                              const Text(
                                'Below your target price!',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Re-run search',
                              icon: const Icon(Icons.refresh),
                              onPressed: () => _rerun(w),
                            ),
                            IconButton(
                              tooltip: 'Delete watch',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(w),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
