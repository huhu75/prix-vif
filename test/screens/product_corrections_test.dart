import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prix_vif/models.dart';
import 'package:prix_vif/screens/product_detail_screen.dart';
import 'package:prix_vif/screens/product_selection_screen.dart';
import 'package:prix_vif/services/open_food_facts_service.dart';
import 'package:prix_vif/services/product_analysis_service.dart';
import 'package:prix_vif/services/scan_repository.dart';

ScannedItem _item(String id, String name, double price, String store, {String? barcode, double? qty, String? unit}) =>
    ScannedItem(
      id: id,
      name: name,
      brand: 'Marque',
      price: price,
      quantity: qty,
      unit: unit,
      scanDate: DateTime(2026, 11, 10),
      barcode: barcode,
      storeName: store,
    );

final _realMilk = OFFProduct(
  barcode: 'vrai_lait',
  name: 'Lait demi-écrémé Lactel',
  brand: 'Lactel',
  nutriscore: 'b',
  categories: const ['Milks'],
  quantity: 1,
  unit: 'L',
  allergens: const [],
  nutrientLevels: const {},
  nutriments: const {},
);

/// Laisse les écritures Hive (vraies E/S) se terminer tout en faisant avancer
/// l'horloge simulée du test : pumpAndSettle seul ne voit pas les E/S réelles.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late ScanRepository repository;

  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  setUp(() async {
    Hive.init(Directory.systemTemp.createTempSync('prix_vif_corrections').path);
    repository = ScanRepository();
    await repository.init();
    // « Lessive » mal rapprochée : deux scans, dont une ligne de ticket de 2 articles
    await repository.saveScan(
      ScanSession(
        id: 's1',
        date: DateTime(2026, 11, 1),
        items: [
          _item('a', 'Lessive', 1.20, 'Carrefour', barcode: 'faux'),
          _item('b', 'Pain', 1.00, 'Carrefour', barcode: 'pain'),
        ],
      ),
    );
    await repository.saveScan(
      ScanSession(
        id: 's2',
        date: DateTime(2026, 11, 8),
        items: [_item('c', 'Lessive', 2.30, 'Leclerc', barcode: 'faux', qty: 2, unit: 'x 5 kg')],
      ),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  group('dépôt', () {
    test('deleteProduct supprime tous les scans du produit et les sessions vides', () async {
      expect(repository.countProductArticles('faux'), 2);

      final removed = await repository.deleteProduct('faux');

      expect(removed, 2);
      expect(repository.countProductArticles('faux'), 0);
      final sessions = await repository.getAllScans();
      expect(sessions.map((s) => s.id), ['s1']);
      expect(sessions.single.items.map((i) => i.name), ['Pain']);
    });

    test('rematchProduct rattache les scans à la bonne fiche en gardant prix, magasin et nombre d\'articles', () async {
      final updated = await repository.rematchProduct(
        'faux',
        name: _realMilk.name,
        brand: _realMilk.brand,
        barcode: _realMilk.barcode,
        nutriscore: _realMilk.nutriscore,
        categories: _realMilk.categories,
        packQuantity: _realMilk.quantity,
        packUnit: _realMilk.unit,
      );

      expect(updated, 2);
      expect(repository.countProductArticles('faux'), 0);
      final articles = repository.getAllStoredArticles().where((a) => a.barcode == 'vrai_lait').toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      expect(articles.map((a) => a.name).toSet(), {'Lait demi-écrémé Lactel'});
      expect(articles.map((a) => a.price), [1.20, 2.30]);
      expect(articles.map((a) => a.storeName), ['Carrefour', 'Leclerc']);
      // Scan simple : contenance du nouveau produit ; ligne de 2 articles : pack de 2
      expect((articles[0].quantity, articles[0].unit), (1.0, 'L'));
      expect((articles[1].quantity, articles[1].unit), (2.0, 'x 1 L'));
    });
  });

  group('fiche produit', () {
    Future<void> openDetail(WidgetTester tester, {Future<void> Function()? onChanged}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(
                      repository: repository,
                      productId: 'faux',
                      productName: 'Lessive',
                      analysisService: ProductAnalysisService(repository, lookupBarcode: (_) async => null),
                      offSearch: (query) async => [_realMilk],
                      onChanged: onChanged,
                    ),
                  ),
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await _settle(tester);
    }

    testWidgets('supprimer le produit depuis sa fiche', (tester) async {
      var changed = 0;
      await openDetail(tester, onChanged: () async => changed++);

      // Démarrée hors de l'horloge simulée : ses écritures Hive (E/S réelles) aboutissent
      await tester.runAsync(() => tester.tap(find.byKey(const ValueKey('delete_product'))));
      await _settle(tester);
      expect(find.text('Supprimer « Lessive » ?'), findsOneWidget);
      expect(find.textContaining('2 scans de ce produit seront retirés'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('confirm_delete_product')));
      await _settle(tester);

      expect(repository.countProductArticles('faux'), 0);
      expect(changed, 1);
      expect(find.byType(ProductDetailScreen), findsNothing);
      expect(find.textContaining('« Lessive » supprimé (2 scans)'), findsOneWidget);
    });

    testWidgets('corriger le produit Open Food Facts depuis sa fiche', (tester) async {
      var changed = 0;
      await openDetail(tester, onChanged: () async => changed++);

      // Démarrée hors de l'horloge simulée : ses écritures Hive (E/S réelles) aboutissent
      await tester.runAsync(() => tester.tap(find.byKey(const ValueKey('rematch_product'))));
      await _settle(tester);
      expect(find.text('Lait demi-écrémé Lactel'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('off_match_result_0')));
      await _settle(tester);

      expect(repository.countProductArticles('vrai_lait'), 2);
      expect(changed, 1);
      expect(find.text('LAIT DEMI-ÉCRÉMÉ LACTEL'), findsOneWidget);
    });
  });

  testWidgets('la liste « Analyser un produit » ouvre la fiche avec tous les scans du produit', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ProductSelectionScreen(repository: repository)));
    await _settle(tester);

    await tester.tap(find.text('Lessive'));
    await _settle(tester);

    final detail = tester.widget<ProductDetailScreen>(find.byType(ProductDetailScreen));
    expect(detail.productId, 'faux');
    expect(repository.countProductArticles(detail.productId), 2);
  });
}
