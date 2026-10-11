import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/watch.dart';

/// Persists fare watches in shared_preferences with an in-memory cache.
class WatchService {
  static const _storageKey = 'farehopper_watches';
  static final WatchService instance = WatchService._();

  WatchService._();

  final List<Watch> _watches = [];
  bool _loaded = false;

  List<Watch> get watches => List.unmodifiable(_watches);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _watches
          ..clear()
          ..addAll(list.map(
              (e) => Watch.fromJson(Map<String, dynamic>.from(e as Map))));
      } catch (_) {
        _watches.clear();
      }
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_watches.map((w) => w.toJson()).toList()),
    );
  }

  Future<void> add(Watch watch) async {
    await load();
    _watches.removeWhere((w) => w.id == watch.id);
    _watches.add(watch);
    await _save();
  }

  Future<void> remove(String id) async {
    await load();
    _watches.removeWhere((w) => w.id == id);
    await _save();
  }

  Future<void> updateLastSeen(String id, double price) async {
    await load();
    final i = _watches.indexWhere((w) => w.id == id);
    if (i != -1) {
      _watches[i] = _watches[i].copyWith(lastSeenPrice: price);
      await _save();
    }
  }

  /// Finds a watch for the same route and calendar day.
  Watch? findFor(String from, String to, DateTime date) {
    for (final w in _watches) {
      if (w.from == from &&
          w.to == to &&
          w.date.year == date.year &&
          w.date.month == date.month &&
          w.date.day == date.day) {
        return w;
      }
    }
    return null;
  }
}
