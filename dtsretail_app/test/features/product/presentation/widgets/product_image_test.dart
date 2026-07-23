import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/product/presentation/widgets/product_image.dart';

void main() {
  testWidgets('shows the fallback icon when imageUrl is null', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProductImage(imageUrl: null, heroTag: 'tag-1')));
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });

  testWidgets('shows the fallback icon when imageUrl is empty', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProductImage(imageUrl: '', heroTag: 'tag-2')));
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });

  testWidgets('wraps its content in a Hero with the given tag', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProductImage(imageUrl: null, heroTag: 'unique-tag')));
    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'unique-tag');
  });
}
