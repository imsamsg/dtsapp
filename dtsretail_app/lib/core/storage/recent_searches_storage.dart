import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentSearchesStorage {
  RecentSearchesStorage(this._prefs);

  final SharedPreferences _prefs;
  static const _maxEntries = 10;

  String _key(String scope) => 'recent_searches_$scope';

  Future<List<String>> read(String scope) async {
    return _prefs.getStringList(_key(scope)) ?? const [];
  }

  Future<void> add(String scope, String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;

    final current = await read(scope);
    final updated = [trimmed, ...current.where((t) => t != trimmed)];
    final capped = updated.take(_maxEntries).toList();
    await _prefs.setStringList(_key(scope), capped);
  }
}

final recentSearchesStorageProvider = FutureProvider<RecentSearchesStorage>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return RecentSearchesStorage(prefs);
});
