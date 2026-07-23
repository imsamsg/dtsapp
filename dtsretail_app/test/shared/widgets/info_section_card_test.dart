import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/shared/widgets/info_section_card.dart';

void main() {
  testWidgets('renders the title and each label/value row', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InfoSectionCard(title: 'Details', rows: [('Code', 'ABC123'), ('UOM', 'EA')]),
        ),
      ),
    );

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Code'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('UOM'), findsOneWidget);
    expect(find.text('EA'), findsOneWidget);
  });

  testWidgets('renders just the title when rows is empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InfoSectionCard(title: 'Empty', rows: []))),
    );

    expect(find.text('Empty'), findsOneWidget);
  });
}
