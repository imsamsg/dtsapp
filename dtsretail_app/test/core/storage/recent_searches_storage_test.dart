import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dtsretail_app/core/storage/recent_searches_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('add stores the term, most recent first', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RecentSearchesStorage(prefs);

    await storage.add('product', 'garden plants');
    await storage.add('product', 'barcode 123');

    expect(await storage.read('product'), ['barcode 123', 'garden plants']);
  });

  test('add deduplicates a repeated term by moving it to the front', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RecentSearchesStorage(prefs);

    await storage.add('product', 'apple');
    await storage.add('product', 'banana');
    await storage.add('product', 'apple');

    expect(await storage.read('product'), ['apple', 'banana']);
  });

  test('add caps history at 10 entries', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RecentSearchesStorage(prefs);

    for (var i = 0; i < 12; i++) {
      await storage.add('product', 'term-$i');
    }

    final result = await storage.read('product');
    expect(result.length, 10);
    expect(result.first, 'term-11');
  });

  test('scopes are independent', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RecentSearchesStorage(prefs);

    await storage.add('product', 'apple');
    await storage.add('stock_count', 'SC0001');

    expect(await storage.read('product'), ['apple']);
    expect(await storage.read('stock_count'), ['SC0001']);
  });
}
