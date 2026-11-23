import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prix_vif/models.dart';
import 'package:prix_vif/screens/product_detail_screen.dart';
import 'package:prix_vif/services/product_analysis_service.dart';
import 'package:prix_vif/services/scan_repository.dart';

ScannedItem _item(String id, String name, double price, String? store, {String? barcode, double? qty, String? unit}) =>
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
    Hive.init(Directory.systemTemp.createTempSync('prix_vif_store_editing').path);
    repository = ScanRepository();
    await repository.init();
    // Café : Carrefour (scan seul), Auchan, et une ligne d'un ticket Carrefour avec du pain
    await repository.saveScan(ScanSession(
      id: 's1',
      date: DateTime(2026, 11, 1),
      storeName: 'Carrefour',
      type: 'barcode',
      items: [_item('art_1', 'Café Moulu', 3.50, 'Carrefour', barcode: 'cafe_123', qty: 250, unit: 'g')],
    ));
    await repository.saveScan(ScanSession(
      id: 's2',
      date: DateTime(2026, 11, 8),
      storeName: 'Auchan',
      type: 'barcode',
      items: [_item('art_2', 'Café Moulu', 3.80, 'Auchan', barcode: 'cafe_123', qty: 250, unit: 'g')],
    ));
    await repository.saveScan(ScanSession(
      id: 't1',
      date: DateTime(2026, 11, 9),
      storeName: 'Carrefour',
      type: 'ticket',
      items: [
        _item('art_3', 'Café Moulu', 3.40, 'Carrefour', barcode: 'cafe_123', qty: 2, unit: 'x 250 g'),
        _item('art_4', 'Pain', 1.00, 'Carrefour', barcode: 'pain_1'),
      ],
    ));
    await repository.saveSelectedStore('Carrefour');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  Future<String?> sessionStore(String id) async =>
      (await repository.getAllScans()).firstWhere((s) => s.id == id).storeName;

  group('dépôt', () {
    test('changer le magasin d\'un produit ne change pas le magasin d\'un ticket mixte', () async {
      final count = await repository.changeStoreForProduct('cafe_123', 'Carrefour', 'Lidl');

      expect(count, 2);
      expect(repository.getScannedItem('art_1')!.storeName, 'Lidl');
      expect(repository.getScannedItem('art_3')!.storeName, 'Lidl');
      expect(repository.getScannedItem('art_4')!.storeName, 'Carrefour', reason: 'autre produit');
      expect(await sessionStore('s1'), 'Lidl', reason: 'session d\'un seul article');
      expect(await sessionStore('t1'), 'Carrefour', reason: 'le pain est toujours chez Carrefour');
      expect(repository.getCustomStores(), contains('Lidl'));
    });

    test('« Inconnu » désigne les scans sans magasin', () async {
      await repository.removeStoreFromProduct('Auchan', 'cafe_123');
      expect(repository.getScannedItem('art_2')!.storeName, isNull);

      final count =
          await repository.changeStoreForProduct('cafe_123', ScanRepository.unknownStoreLabel, 'Monoprix');
      expect(count, 1);
      expect(repository.getScannedItem('art_2')!.storeName, 'Monoprix');
    });

    test('renommer un magasin partout : articles, sessions, liste du scanner, dernier magasin', () async {
      expect(repository.countStoreArticles('Carrefour'), 3);

      final count = await repository.renameStore('Carrefour', 'Carrefour Market');

      expect(count, 3);
      expect(repository.countStoreArticles('Carrefour'), 0);
      expect(repository.countStoreArticles('Carrefour Market'), 3);
      expect(await sessionStore('s1'), 'Carrefour Market');
      expect(await sessionStore('t1'), 'Carrefour Market');
      expect(repository.getAllKnownStores(), allOf(contains('Carrefour Market'), isNot(contains('Carrefour'))));
      expect(repository.getSelectedStore(), 'Carrefour Market');
    });

    test('renommer vers un magasin existant les fusionne ; changer la casse le garde visible', () async {
      await repository.renameStore('Auchan', 'Carrefour');
      expect(repository.getPriceHistoryByStore('cafe_123').keys, ['Carrefour']);

      await repository.renameStore('Carrefour', 'CARREFOUR');
      expect(repository.getAllKnownStores(), contains('CARREFOUR'));
    });

    test('ajouter un prix sans scanner copie la fiche du produit', () async {
      final added = await repository.addPriceForProduct('cafe_123', storeName: 'Lidl', price: 3.20);

      expect(added, isNotNull);
      expect(repository.countProductArticles('cafe_123'), 4);
      final saved = repository.getScannedItem(added!.id)!;
      expect((saved.name, saved.barcode, saved.storeName, saved.price), ('Café Moulu', 'cafe_123', 'Lidl', 3.20));
      // Contenance d'un scan à l'unité, pas celle de la ligne de ticket « x 2 »
      expect((saved.quantity, saved.unit), (250.0, 'g'));
      expect(await sessionStore(added.id), 'Lidl');
      expect(repository.getAllKnownStores(), contains('Lidl'));
      expect(await repository.addPriceForProduct('inconnu', storeName: 'Lidl', price: 1), isNull);
    });
  });

  group('fiche produit, onglet Magasins', () {
    Future<void> openDetail(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: ProductDetailScreen(
          repository: repository,
          productId: 'cafe_123',
          productName: 'Café Moulu',
          initialTabIndex: 2,
          analysisService: ProductAnalysisService(repository, lookupBarcode: (_) async => null),
        ),
      ));
      await _settle(tester);
    }

    /// Touche une carte magasin (dans la zone réelle : la suite écrit dans Hive)
    Future<void> tapStore(WidgetTester tester, String store) async {
      final card = find.byKey(ValueKey('store_card_$store'));
      await tester.ensureVisible(card);
      await tester.pump();
      await tester.runAsync(() => tester.tap(card));
      await _settle(tester);
    }

    Future<void> tapInSheet(WidgetTester tester, String key) async {
      final target = find.byKey(ValueKey(key));
      await tester.ensureVisible(target);
      await tester.pump();
      await tester.tap(target);
      await _settle(tester);
    }

    testWidgets('toucher un magasin puis en choisir un autre déplace les scans de ce produit', (tester) async {
      await openDetail(tester);
      await tapStore(tester, 'Carrefour');

      expect(find.byKey(const ValueKey('store_edit_sheet')), findsOneWidget);
      expect(find.text('Ce produit (2)'), findsOneWidget);
      expect(find.text('Partout (3)'), findsOneWidget);

      await tapInSheet(tester, 'store_suggestion_Lidl');
      expect(find.text('Déplacer vers « Lidl »'), findsOneWidget);
      await tapInSheet(tester, 'store_edit_apply');

      expect(repository.getScannedItem('art_1')!.storeName, 'Lidl');
      expect(repository.getScannedItem('art_4')!.storeName, 'Carrefour');
      expect(find.text('2 scans déplacés vers Lidl'), findsOneWidget);
      expect(find.byKey(const ValueKey('store_card_Lidl')), findsOneWidget);
    });

    testWidgets('« Partout » renomme le magasin pour tous les produits', (tester) async {
      await openDetail(tester);
      await tapStore(tester, 'Carrefour');

      await tapInSheet(tester, 'store_scope_everywhere');
      await tester.enterText(find.byKey(const ValueKey('store_edit_input')), 'Carrefour Market');
      await tester.pump();
      await tapInSheet(tester, 'store_edit_apply');

      expect(repository.getScannedItem('art_4')!.storeName, 'Carrefour Market');
      expect(find.textContaining('renommé en « Carrefour Market » (3 scans)'), findsOneWidget);
    });

    testWidgets('retirer un magasin demande une confirmation', (tester) async {
      await openDetail(tester);
      await tapStore(tester, 'Auchan');

      await tapInSheet(tester, 'store_edit_remove');
      expect(repository.getScannedItem('art_2')!.storeName, 'Auchan', reason: 'pas encore confirmé');
      await tapInSheet(tester, 'store_edit_confirm_remove');

      expect(repository.getScannedItem('art_2')!.storeName, isNull);
      expect(find.text('« Auchan » retiré de ce produit'), findsOneWidget);
    });

    testWidgets('ajouter un prix dans un magasin sans scanner', (tester) async {
      await openDetail(tester);
      final button = find.byKey(const ValueKey('add_store_price'));
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.runAsync(() => tester.tap(button));
      await _settle(tester);

      await tapInSheet(tester, 'add_price_store_Lidl');
      await tester.enterText(find.byKey(const ValueKey('add_price_input')), '3,20');
      await tester.pump();
      await tapInSheet(tester, 'add_price_save');

      final lidl = repository.getArticlesForProduct('cafe_123').where((a) => a.storeName == 'Lidl').toList();
      expect(lidl.single.price, 3.20);
      expect(find.text('Prix ajouté : 3.20 € chez Lidl'), findsOneWidget);
      expect(find.byKey(const ValueKey('store_card_Lidl')), findsOneWidget);
    });
  });
}
