import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prix_vif/analytics/analytics.dart';
import 'package:prix_vif/models.dart';
import 'package:prix_vif/screens/my_list_screen.dart';
import 'package:prix_vif/screens/products_screen.dart';
import 'package:prix_vif/screens/profile_screen.dart';
import 'package:prix_vif/screens/stores_screen.dart';
import 'package:prix_vif/services/scan_repository.dart';

ScannedItem _item(String id, String product, double price, String store, DateTime date) => ScannedItem(
      id: id,
      name: product,
      brand: 'Marque',
      price: price,
      scanDate: date,
      barcode: product.toLowerCase(),
      storeName: store,
    );

/// Lait : 1.00 € puis 1.20 € chez Carrefour (+20 %), 0.99 € chez Leclerc
List<ScanSession> _sessions() {
  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));
  return [
    ScanSession(id: 'avant', date: weekAgo, items: [
      _item('1', 'Lait', 1.00, 'Carrefour', weekAgo),
      _item('2', 'Beurre', 3.00, 'Carrefour', weekAgo),
    ]),
    ScanSession(id: 'carrefour', date: now, items: [
      _item('3', 'Lait', 1.20, 'Carrefour', now),
      _item('4', 'Beurre', 3.00, 'Carrefour', now),
    ]),
    ScanSession(id: 'leclerc', date: now, items: [_item('5', 'Lait', 0.99, 'Leclerc', now)]),
  ];
}

/// Laisse les écritures Hive (vraies E/S) se terminer
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  String? openedProduct;
  int? openedTab;
  void onProductTap(String id, String _, {int initialTabIndex = 0}) {
    openedProduct = id;
    openedTab = initialTabIndex;
  }

  group('Produits', () {
    Widget products(List<ScanSession> sessions, {ProductsView view = ProductsView.whereToBuy, VoidCallback? onAll}) {
      openedProduct = null;
      openedTab = null;
      return MaterialApp(
        home: ProductsScreen(sessions: sessions, initialView: view, onProductTap: onProductTap, onAllProducts: onAll),
      );
    }

    testWidgets('où chaque produit est le moins cher, la fiche s\'ouvre sur Magasins', (tester) async {
      await tester.pumpWidget(products(_sessions()));

      expect(find.text('Où acheter'), findsOneWidget);
      expect(find.text('Évolution'), findsOneWidget);
      expect(find.text('Où chaque produit est le moins cher'), findsOneWidget);
      expect(find.text('1.20 €  (+0.21 €)'), findsOneWidget);
      expect(find.text('Vu seulement chez Carrefour'), findsOneWidget);

      await tester.tap(find.text('Lait'));
      expect((openedProduct, openedTab), ('lait', 2));
    });

    testWidgets('la recherche filtre les produits', (tester) async {
      await tester.pumpWidget(products(_sessions()));
      await tester.enterText(find.byKey(const ValueKey('dashboard_product_search')), 'beur');
      await tester.pump();
      expect(find.text('Beurre'), findsOneWidget);
      expect(find.text('Lait'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('dashboard_product_search')), 'xyz');
      await tester.pump();
      expect(find.text('Aucun produit ne correspond à « xyz ».'), findsOneWidget);
    });

    testWidgets('vue Évolution : une hausse ouvre la fiche sur Évolution', (tester) async {
      await tester.pumpWidget(products(_sessions(), view: ProductsView.evolution));
      await tester.pumpAndSettle();

      expect(find.text('Ce qui a augmenté'), findsOneWidget);
      expect(find.text('+20 %'), findsOneWidget);
      await tester.tap(find.text('Lait'));
      expect((openedProduct, openedTab), ('lait', 1));
    });

    testWidgets('« Tous mes produits » et état vide', (tester) async {
      var opened = 0;
      await tester.pumpWidget(products(_sessions(), onAll: () => opened++));
      await tester.tap(find.byKey(const ValueKey('products_all')));
      expect(opened, 1);

      await tester.pumpWidget(products(const []));
      expect(find.text('Aucune donnée'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
    });
  });

  testWidgets('Ma liste : où faire ses courses et ce que chaque magasin a de moins cher', (tester) async {
    openedProduct = null;
    await tester.pumpWidget(MaterialApp(home: MyListScreen(sessions: _sessions(), onProductTap: onProductTap)));
    await tester.pumpAndSettle();

    expect(find.text('Où faire mes courses ?'), findsOneWidget);
    expect(find.text('Ce que chaque magasin a de moins cher'), findsOneWidget);
    await tester.tap(find.text('Lait').first);
    expect((openedProduct, openedTab), ('lait', 2));
  });

  group('Profil', () {
    late ScanRepository repository;

    setUp(() async {
      Hive.init(Directory.systemTemp.createTempSync('prix_vif_profile_test').path);
      repository = ScanRepository();
      await repository.init();
      for (final session in _sessions()) {
        await repository.saveScan(session);
      }
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
    });

    testWidgets('tes relevés, l\'historique et les données de démo', (tester) async {
      var history = 0;
      final sessions = [..._sessions(), ...ScanSession.demoSessions.take(1)];
      await tester.pumpWidget(MaterialApp(
        home: ProfileScreen(
          sessions: sessions,
          repository: repository,
          onOpenHistory: () => history++,
          onChanged: () async {},
        ),
      ));

      expect(find.text('Tes relevés'), findsOneWidget);
      expect(find.text('prix relevés'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_remove_demo')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('profile_history')));
      expect(history, 1);
    });

    testWidgets('Mes magasins : renommer un magasin partout', (tester) async {
      var changed = 0;
      await tester.pumpWidget(MaterialApp(
        home: StoresScreen(repository: repository, onChanged: () async => changed++),
      ));
      expect(find.byKey(const ValueKey('store_row_Carrefour')), findsOneWidget);

      await tester.runAsync(() => tester.tap(find.byKey(const ValueKey('store_row_Carrefour'))));
      await _settle(tester);
      expect(find.text('4 prix relevés'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('store_rename')));
      await _settle(tester);
      await tester.enterText(find.byKey(const ValueKey('store_name_input')), 'Carrefour Market');
      await tester.tap(find.byKey(const ValueKey('store_name_confirm')));
      await _settle(tester);

      expect(repository.countStoreArticles('Carrefour Market'), 4);
      expect(changed, 1);
      expect(find.byKey(const ValueKey('store_row_Carrefour Market')), findsOneWidget);
      expect(find.byKey(const ValueKey('store_row_Carrefour')), findsNothing);
    });
  });

  test('ProductStorePrices.calculate identifie magasin le moins cher et écart', () {
    final t0 = DateTime(2026, 11, 2);
    ScanSession session(String id, String store, double price) => ScanSession(id: id, date: t0, storeName: store, items: [
          ScannedItem(
            id: '${id}_1',
            name: 'Pâte à Tartiner',
            brand: 'Nocciolata',
            barcode: '8001234567890',
            price: price,
            scanDate: t0,
            storeName: store,
          ),
        ]);

    final item = ProductStorePrices.calculate([session('a', 'Leclerc', 3.20), session('b', 'Monoprix', 4.10)]).single;
    expect((item.cheapest.storeName, item.cheapest.price), ('Leclerc', 3.20));
    expect((item.mostExpensive.storeName, item.mostExpensive.price), ('Monoprix', 4.10));
    expect(item.priceDiff, closeTo(0.90, 0.001));
    expect(item.savingPercent, closeTo(21.95, 0.1));
    expect(item.hasPriceDifference, isTrue);
  });
}
