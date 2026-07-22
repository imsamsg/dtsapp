import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RememberedUsernameStorage {
  RememberedUsernameStorage(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'remembered_username';

  String? read() => _prefs.getString(_key);

  Future<void> save(String username) => _prefs.setString(_key, username);

  Future<void> clear() => _prefs.remove(_key);
}

final rememberedUsernameStorageProvider = FutureProvider<RememberedUsernameStorage>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return RememberedUsernameStorage(prefs);
});
