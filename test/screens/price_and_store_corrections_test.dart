import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prix_vif/models.dart';
import 'package:prix_vif/services/scan_repository.dart';
import 'package:prix_vif/widgets/article_edit_dialog.dart';

ScannedItem _item(
  String id,
  String name,
  double price,
  String store, {
  String? barcode,
  double? qty,
  String? unit,
}) =>
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
    Hive.init(Directory.systemTemp.createTempSync('prix_vif_price_store_test').path);
    repository = ScanRepository();
    await repository.init();

    // 2 scans pour le produit "café" (barcode: 'cafe_123')
    await repository.saveScan(
      ScanSession(
        id: 's1',
        date: DateTime(2026, 11, 1),
        storeName: 'Carrefour',
        items: [
          _item('art_1', 'Café Moulu', 3.50, 'Carrefour', barcode: 'cafe_123', qty: 250, unit: 'g'),
        ],
      ),
    );
    await repository.saveScan(
      ScanSession(
        id: 's2',
        date: DateTime(2026, 11, 8),
        storeName: 'Auchan',
        items: [
          _item('art_2', 'Café Moulu', 3.80, 'Auchan', barcode: 'cafe_123', qty: 250, unit: 'g'),
        ],
      ),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  // ─── Repo unitaire ─────────────────────────────────────────────────────────

  group('ScanRepository — prix et magasins', () {
    test("getScannedItem renvoie l'article scanné existant", () {
      final item = repository.getScannedItem('art_1');
      expect(item, isNotNull);
      expect(item!.name, 'Café Moulu');
      expect(item.price, 3.50);
      expect(item.storeName, 'Carrefour');

      final unknown = repository.getScannedItem('inconnu');
      expect(unknown, isNull);
    });

    test('getArticlesForProduct renvoie tous les articles du produit', () {
      final articles = repository.getArticlesForProduct('cafe_123');
      expect(articles.length, 2);
      expect(articles.map((a) => a.id).toSet(), {'art_1', 'art_2'});
    });

    test('changeStoreForProduct remplace le magasin spécifié pour le produit', () async {
      // Changer uniquement 'Carrefour' en 'Leclerc' pour ce produit
      final count = await repository.changeStoreForProduct('cafe_123', 'Carrefour', 'Leclerc');
      expect(count, 1);

      final art1 = repository.getScannedItem('art_1')!;
      final art2 = repository.getScannedItem('art_2')!;
      expect(art1.storeName, 'Leclerc');
      expect(art2.storeName, 'Auchan'); // non affecté
    });

    test('changeStoreForProduct remplace tous les magasins du produit si oldStore est null', () async {
      final count = await repository.changeStoreForProduct('cafe_123', null, 'Monoprix');
      expect(count, 2);

      final art1 = repository.getScannedItem('art_1')!;
      final art2 = repository.getScannedItem('art_2')!;
      expect(art1.storeName, 'Monoprix');
      expect(art2.storeName, 'Monoprix');
    });

    test("updateArticle met à jour le prix et le magasin d'un article", () async {
      final item = repository.getScannedItem('art_1')!;
      final updated = ScannedItem(
        id: item.id,
        name: item.name,
        brand: item.brand,
        price: 2.99,
        quantity: item.quantity,
        unit: item.unit,
        scanDate: item.scanDate,
        barcode: item.barcode,
        storeName: 'Lidl',
      );

      await repository.updateArticle(updated);

      final saved = repository.getScannedItem('art_1')!;
      expect(saved.price, 2.99);
      expect(saved.storeName, 'Lidl');
    });

    test('getAllKnownStores inclut les magasins des articles scannés', () {
      final stores = repository.getAllKnownStores();
      expect(stores, containsAll(['Carrefour', 'Auchan']));
    });
  });

  // ─── ArticleEditDialog ──────────────────────────────────────────────────────

  group('ArticleEditDialog — saisie et enregistrement', () {
    testWidgets('affiche le dialog et enregistre le prix modifié', (tester) async {
      final item = _item('d1', 'Pâtes', 1.50, 'Lidl', qty: 500, unit: 'g');
      ArticleEditResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await showArticleEditDialog(ctx, item);
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ouvrir'));
      await _settle(tester);

      expect(find.text("Modifier l'article"), findsOneWidget);

      // Modifier le prix
      await tester.enterText(find.byKey(const ValueKey('edit_price')), '2,30');
      await tester.tap(find.byKey(const ValueKey('edit_save')));
      await _settle(tester);

      expect(result, isA<ArticleUpdated>());
      final upd1 = result as ArticleUpdated;
      expect(upd1.item.price, 2.30);
      expect(upd1.item.storeName, 'Lidl'); // magasin inchangé
    });

    testWidgets('affiche le dialog et enregistre le magasin modifié', (tester) async {
      final item = _item('d2', 'Lait', 0.85, 'Aldi');
      ArticleEditResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await showArticleEditDialog(ctx, item);
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ouvrir'));
      await _settle(tester);

      expect(find.text("Modifier l'article"), findsOneWidget);

      // Modifier le magasin
      await tester.enterText(find.byKey(const ValueKey('edit_store')), 'Intermarché');
      await tester.tap(find.byKey(const ValueKey('edit_save')));
      await _settle(tester);

      expect(result, isA<ArticleUpdated>());
      final upd2 = result as ArticleUpdated;
      expect(upd2.item.storeName, 'Intermarché');
      expect(upd2.item.price, 0.85); // prix inchangé
    });

    testWidgets('annuler le dialog renvoie null', (tester) async {
      final item = _item('d3', 'Yaourt', 0.60, 'Leclerc');
      ArticleEditResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await showArticleEditDialog(ctx, item);
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ouvrir'));
      await _settle(tester);

      await tester.tap(find.text('Annuler'));
      await _settle(tester);

      expect(result, isNull);
    });

    testWidgets("un clic sur un ActionChip remplit le champ magasin", (tester) async {
      final item = _item('d4', 'Jus', 2.10, 'Carrefour');

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showArticleEditDialog(
                ctx,
                item,
                knownStores: ['Leclerc', 'Monoprix'],
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ouvrir'));
      await _settle(tester);

      // Toucher le chip "Leclerc"
      await tester.tap(find.text('Leclerc'));
      await _settle(tester);

      // Le champ magasin doit contenir "Leclerc"
      final storeField = tester.widget<TextFormField>(find.byKey(const ValueKey('edit_store')));
      expect(storeField.controller?.text, 'Leclerc');
    });
  });
}
