import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prix_vif/analytics/analytics.dart';
import 'package:prix_vif/models.dart';
import 'package:prix_vif/widgets/dashboard/prices_tab.dart';
import 'package:prix_vif/widgets/dashboard/stores_tab.dart';

final _start = DateTime(2026, 11, 1);

ScannedItem _buy(String product, double price, String store, int day) => ScannedItem(
      id: '${product}_${store}_$day',
      name: product,
      brand: 'Marque',
      price: price,
      scanDate: _start.add(Duration(days: day)),
      barcode: 'ean_$product',
      storeName: store,
    );

ScanSession _trip(String id, int day, List<ScannedItem> items) =>
    ScanSession(id: id, date: _start.add(Duration(days: day)), items: items);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('ShoppingBasketAnalysis', () {
    // Lait, Pain, Café achetés deux fois ; Chips une seule fois
    final sessions = [
      _trip('t1', 0, [
        _buy('Lait', 1.20, 'Carrefour', 0),
        _buy('Pain', 2.00, 'Carrefour', 0),
        _buy('Café', 4.00, 'Carrefour', 0),
        _buy('Chips', 1.50, 'Carrefour', 0),
      ]),
      _trip('t2', 7, [
        _buy('Lait', 1.00, 'Leclerc', 7),
        _buy('Pain', 2.20, 'Leclerc', 7),
        _buy('Café', 3.50, 'Leclerc', 7),
      ]),
    ];

    test('le panier habituel exclut les produits achetés une seule fois', () {
      final basket = ShoppingBasketAnalysis.calculate(sessions)!;
      expect(basket.usesRegularPurchases, isTrue);
      expect(basket.products.map((p) => p.name).toSet(), {'Lait', 'Pain', 'Café'});
    });

    test('classe les magasins et calcule le panier optimal', () {
      final basket = ShoppingBasketAnalysis.calculate(sessions)!;
      // Carrefour : 1.20 + 2.00 + 4.00 = 7.20 ; Leclerc : 1.00 + 2.20 + 3.50 = 6.70
      expect(basket.stores.map((s) => s.storeName), ['Leclerc', 'Carrefour']);
      expect(basket.bestStore.total, closeTo(6.70, 0.001));
      expect(basket.savingVsMostExpensive, closeTo(0.50, 0.001));
      // Optimal : Lait et Café chez Leclerc, Pain chez Carrefour = 1.00 + 2.00 + 3.50
      expect(basket.optimalTotal, closeTo(6.50, 0.001));
      expect(basket.optimalSavingVsBestStore, closeTo(0.20, 0.001));
      expect(basket.optimalPlan['Carrefour']!.map((p) => p.name), ['Pain']);
    });

    test('un prix inconnu dans un magasin est estimé au prix moyen observé ailleurs', () {
      final basket = ShoppingBasketAnalysis.calculate([
        _trip('t1', 0, [_buy('Lait', 1.00, 'A', 0), _buy('Pain', 2.00, 'A', 0)]),
        _trip('t2', 1, [_buy('Lait', 1.40, 'B', 1)]),
      ])!;
      expect(basket.usesRegularPurchases, isFalse);
      final storeB = basket.stores.firstWhere((s) => s.storeName == 'B');
      expect(storeB.pricedCount, 1);
      expect(storeB.estimatedCount, 1);
      expect(storeB.total, closeTo(3.40, 0.001));
    });

    test('rien à comparer avec un seul magasin', () {
      expect(ShoppingBasketAnalysis.calculate([sessions.first]), isNull);
    });
  });

  group('PriceChange', () {
    final sessions = [
      _trip('t1', 0, [
        _buy('Lait', 1.00, 'Carrefour', 0),
        _buy('Pain', 2.00, 'Carrefour', 0),
        _buy('Beurre', 3.00, 'Carrefour', 0),
      ]),
      _trip('t2', 3, [_buy('Lait', 0.95, 'Leclerc', 3)]),
      _trip('t3', 7, [
        _buy('Lait', 1.15, 'Carrefour', 7),
        _buy('Pain', 1.80, 'Carrefour', 7),
        _buy('Beurre', 3.005, 'Carrefour', 7),
      ]),
    ];

    test('hausses et baisses dans le même magasin, de la plus forte hausse à la plus forte baisse', () {
      final changes = PriceChange.calculate(sessions);
      expect(changes.map((c) => c.name), ['Lait', 'Pain']);

      final lait = changes.first;
      expect(lait.isIncrease, isTrue);
      expect(lait.storeName, 'Carrefour');
      expect(lait.percent, closeTo(15, 0.01));
      expect(lait.cheaperStore, 'Leclerc');
      expect(lait.cheaperPrice, 0.95);

      final pain = changes.last;
      expect(pain.isIncrease, isFalse);
      expect(pain.percent, closeTo(-10, 0.01));
    });

    test('un écart d\'un centime ou moins n\'est pas un changement', () {
      expect(PriceChange.calculate(sessions).any((c) => c.name == 'Beurre'), isFalse);
    });

    test('pas de changement entre deux magasins différents', () {
      // Lait : 1.00 chez Carrefour puis 0.95 chez Leclerc, un seul achat dans chaque magasin
      expect(PriceChange.calculate(sessions.take(2).toList()), isEmpty);
    });
  });

  group('onglets du Dashboard', () {
    testWidgets('« Où faire mes courses ? » affiche les magasins et le total en panachant', (tester) async {
      final basket = ShoppingBasketAnalysis.calculate([
        _trip('t1', 0, [_buy('Lait', 1.20, 'Carrefour', 0), _buy('Pain', 2.00, 'Carrefour', 0)]),
        _trip('t2', 1, [_buy('Lait', 1.00, 'Leclerc', 1), _buy('Pain', 2.20, 'Leclerc', 1)]),
      ]);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: BasketCard(analysis: basket))),
      ));

      expect(find.text('Où faire mes courses ?'), findsOneWidget);
      expect(find.text('3.20 €'), findsWidgets);
      expect(find.text('2 prix relevés sur 2'), findsWidgets);
      expect(
        find.text('En achetant chaque produit là où il est le moins cher : 3.00 € (0.20 € de moins).'),
        findsOneWidget,
      );
    });

    testWidgets('« Où faire mes courses ? » sans données explique quoi faire', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: BasketCard(analysis: null))));
      expect(find.textContaining('au moins deux magasins'), findsOneWidget);
    });

    testWidgets('onglet Prix : hausse avec magasin moins cher, baisse, tap vers la fiche', (tester) async {
      final changes = PriceChange.calculate([
        _trip('t1', 0, [_buy('Lait', 1.00, 'Carrefour', 0), _buy('Pain', 2.00, 'Carrefour', 0)]),
        _trip('t2', 3, [_buy('Lait', 0.95, 'Leclerc', 3)]),
        _trip('t3', 7, [_buy('Lait', 1.07, 'Carrefour', 7), _buy('Pain', 1.80, 'Carrefour', 7)]),
      ]);
      String? tapped;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PricesTab(
            increases: changes.where((c) => c.isIncrease).toList(),
            decreases: changes.where((c) => !c.isIncrease).toList(),
            onProductTap: (id, _) => tapped = id,
          ),
        ),
      ));

      expect(find.text('+7 %'), findsOneWidget);
      expect(find.text('1.07 € chez Carrefour (avant 1.00 €)'), findsOneWidget);
      expect(find.text('Moins cher chez Leclerc : 0.95 €'), findsOneWidget);
      expect(find.text('−10 %'), findsOneWidget);

      await tester.tap(find.text('Lait'));
      expect(tapped, 'ean_Lait');
    });

    testWidgets('onglet Prix vide', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PricesTab(increases: const [], decreases: const [], onProductTap: (_, _) {})),
      ));
      expect(find.text('Aucune hausse depuis tes derniers achats.'), findsOneWidget);
      expect(find.text('Aucune baisse depuis tes derniers achats.'), findsOneWidget);
    });
  });
}
