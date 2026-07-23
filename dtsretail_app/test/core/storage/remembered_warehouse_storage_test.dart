import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dtsretail_app/core/storage/remembered_warehouse_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('read returns null when nothing is stored', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RememberedWarehouseStorage(prefs);

    expect(storage.read(), isNull);
  });

  test('save then read round-trips the warehouse code', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RememberedWarehouseStorage(prefs);

    await storage.save('BBPOS');

    expect(storage.read(), 'BBPOS');
  });

  test('save overwrites a previously saved warehouse code', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RememberedWarehouseStorage(prefs);

    await storage.save('BBPOS');
    await storage.save('BBPOS2');

    expect(storage.read(), 'BBPOS2');
  });
}
