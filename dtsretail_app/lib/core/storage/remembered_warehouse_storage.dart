import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RememberedWarehouseStorage {
  RememberedWarehouseStorage(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'remembered_warehouse_code';

  String? read() => _prefs.getString(_key);

  Future<void> save(String warehouseCode) => _prefs.setString(_key, warehouseCode);
}

final rememberedWarehouseStorageProvider = FutureProvider<RememberedWarehouseStorage>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return RememberedWarehouseStorage(prefs);
});
