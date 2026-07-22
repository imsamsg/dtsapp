import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dtsretail_app/core/storage/remembered_username_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('read returns null when nothing is stored', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RememberedUsernameStorage(prefs);

    expect(storage.read(), isNull);
  });

  test('save then read round-trips the username', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RememberedUsernameStorage(prefs);

    await storage.save('sam.tan');

    expect(storage.read(), 'sam.tan');
  });

  test('clear removes a previously saved username', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RememberedUsernameStorage(prefs);

    await storage.save('sam.tan');
    await storage.clear();

    expect(storage.read(), isNull);
  });
}
