import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prix_vif/models.dart';
import 'package:prix_vif/screens/product_selection_screen.dart';
import 'package:prix_vif/services/scan_repository.dart';

void main() {
  late ScanRepository repository;

  setUpAll(() async {
    // Hors zone fake-async des testWidgets : Hive fait de l'IO réelle
    final tempDir = Directory.systemTemp.createTempSync();
    Hive.init(tempDir.path);

    repository = ScanRepository();
    await repository.init();

    final now = DateTime.now();
    await repository.saveScan(ScanSession(
      id: 'sel_test_1',
      date: now,
      type: 'barcode',
      items: [
        ScannedItem(
          id: 's1',
          name: 'Lait Demi-Ecreme',
          brand: 'Candia',
          price: 1.50,
          scanDate: now,
          barcode: '3008360001234',
          categories: ['Foods', 'Beverages', 'Milks'],
        ),
        ScannedItem(
          id: 's2',
          name: 'Pain de Mie',
          brand: 'Brioche Dore',
          price: 2.99,
          scanDate: now,
          barcode: '3017620422003',
          categories: ['Foods', 'Breads'],
        ),
      ],
    ));
  });

  test('repository init + saveScan + getUniqueProducts', () {
    final products = repository.getUniqueProducts();
    expect(products.length, 2);
    expect(
      products.map((p) => p['categories']).toList(),
      containsAll([
        ['Foods', 'Beverages', 'Milks'],
        ['Foods', 'Breads'],
      ]),
    );
  });

  testWidgets('Le filtre par type ne garde que les produits du type choisi',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ProductSelectionScreen(repository: repository),
    ));
    // NeonTitle a une animation infinie : pump() avec durée plutôt que pumpAndSettle()
    await tester.pump(const Duration(milliseconds: 500));

    // Au départ, tous les produits sont visibles + les chips de type
    expect(find.text('Lait Demi-Ecreme'), findsOneWidget);
    expect(find.text('Pain de Mie'), findsOneWidget);
    expect(find.text('Tous'), findsOneWidget);
    // "Milks"/"Breads" apparaissent dans le chip de filtre ET sur la carte produit
    expect(find.text('Milks'), findsAtLeastNWidgets(1));
    expect(find.text('Breads'), findsAtLeastNWidgets(1));

    // On filtre sur le type "Milks" (chip "Tous" + chip "Milks" + label carte)
    await tester.tap(find.text('Milks').first);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Lait Demi-Ecreme'), findsOneWidget);
    expect(find.text('Pain de Mie'), findsNothing);
    expect(find.text('(1 produits · Milks)'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('La recherche textuelle trouve aussi via les catégories',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ProductSelectionScreen(repository: repository),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    // "beverages" ne match ni le nom ni la marque, mais matche la catégorie "Beverages"
    await tester.enterText(find.byType(TextField), 'beverages');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Lait Demi-Ecreme'), findsOneWidget);
    expect(find.text('Pain de Mie'), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
