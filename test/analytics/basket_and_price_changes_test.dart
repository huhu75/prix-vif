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

    test('compare les magasins à l\'identique et calcule le panier panaché', () {
      final basket = ShoppingBasketAnalysis.calculate(sessions)!;
      // Mêmes 3 produits : Carrefour 1.20 + 2.00 + 4.00 = 7.20 ; Leclerc 1.00 + 2.20 + 3.50 = 6.70
      expect(basket.stores.map((s) => s.storeName), ['Leclerc', 'Carrefour']);
      final carrefour = basket.comparisonStore!;
      expect(carrefour.storeName, 'Carrefour');
      expect(carrefour.commonWithBest, 3);
      expect(carrefour.total, closeTo(7.20, 0.001));
      expect(carrefour.bestTotal, closeTo(6.70, 0.001));
      expect(carrefour.extraVsBest, closeTo(0.50, 0.001));
      expect(carrefour.percentVsBest, closeTo(7.46, 0.01));
      expect(basket.isConclusive, isTrue);
      // Panaché : Pain chez Carrefour (2.00 au lieu de 2.20 chez Leclerc)
      expect(basket.optimalSavingVsBestStore, closeTo(0.20, 0.001));
      expect(basket.optimalPlan['Carrefour']!.map((p) => p.name), ['Pain']);
    });

    test('aucun prix n\'est estimé : un produit vu dans un seul magasin ne compte pas', () {
      // Pain seulement chez A : avant, il était « estimé » chez B au prix de A
      final basket = ShoppingBasketAnalysis.calculate([
        _trip('t1', 0, [_buy('Lait', 1.00, 'A', 0), _buy('Pain', 2.00, 'A', 0)]),
        _trip('t2', 1, [_buy('Lait', 1.40, 'B', 1)]),
        _trip('t3', 2, [_buy('Chips', 1.50, 'C', 2)]),
      ])!;
      expect(basket.usesRegularPurchases, isFalse);
      expect(basket.comparedProducts.map((p) => p.name), ['Lait']);
      final b = basket.stores.firstWhere((s) => s.storeName == 'B');
      expect((b.commonWithBest, b.total, b.bestTotal), (1, 1.40, 1.00));
      // Un seul produit en commun : pas assez pour conclure
      expect(basket.isConclusive, isFalse);
      expect(basket.comparisonStore, isNull);
      // C n'a aucun produit relevé ailleurs
      expect(basket.uncomparedStores, ['C']);
    });

    test('classe les magasins par indice de prix, même sans produit commun à tous', () {
      // A et B partagent Lait ; B et C partagent Pain. A est au prix le plus bas
      // partout où il est vu, C toujours 10 % plus cher.
      final basket = ShoppingBasketAnalysis.calculate([
        _trip('t1', 0, [_buy('Lait', 1.00, 'A', 0)]),
        _trip('t2', 1, [_buy('Lait', 1.05, 'B', 1), _buy('Pain', 2.00, 'B', 1)]),
        _trip('t3', 2, [_buy('Pain', 2.20, 'C', 2)]),
      ])!;
      expect(basket.stores.map((s) => s.storeName), ['A', 'B', 'C']);
      expect(basket.stores.map((s) => s.priceIndex), [closeTo(1.0, 0.001), closeTo(1.025, 0.001), closeTo(1.1, 0.001)]);
      // C n'a aucun produit en commun avec A
      expect(basket.stores.last.commonWithBest, 0);
    });

    test('rien à comparer sans produit relevé dans deux magasins', () {
      expect(ShoppingBasketAnalysis.calculate([sessions.first]), isNull);
      expect(
        ShoppingBasketAnalysis.calculate([
          _trip('t1', 0, [_buy('Lait', 1.00, 'A', 0)]),
          _trip('t2', 1, [_buy('Pain', 2.00, 'B', 1)]),
        ]),
        isNull,
      );
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
    testWidgets('« Où faire mes courses ? » compare à l\'identique et conclut à partir de 3 produits', (tester) async {
      final basket = ShoppingBasketAnalysis.calculate([
        _trip('t1', 0, [
          _buy('Lait', 1.20, 'Carrefour', 0),
          _buy('Pain', 2.00, 'Carrefour', 0),
          _buy('Café', 4.00, 'Carrefour', 0),
        ]),
        _trip('t2', 1, [
          _buy('Lait', 1.00, 'Leclerc', 1),
          _buy('Pain', 2.20, 'Leclerc', 1),
          _buy('Café', 3.50, 'Leclerc', 1),
        ]),
      ]);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: BasketCard(analysis: basket))),
      ));

      expect(find.text('Où faire mes courses ?'), findsOneWidget);
      expect(find.text('le moins cher'), findsOneWidget);
      expect(find.text('+0.50 €  (+7 %)'), findsOneWidget);
      expect(find.text('Sur 3 produits relevés aussi chez Leclerc'), findsOneWidget);
      expect(
        find.text('Chez Leclerc, tu paies 0.50 € de moins que chez Carrefour pour les 3 mêmes produits.'),
        findsOneWidget,
      );
      expect(
        find.text('En achetant chaque produit là où il est le moins cher, tu économiserais encore 0.20 € par rapport à Leclerc.'),
        findsOneWidget,
      );
      expect(find.text('Seuls les prix réellement relevés comptent : aucun prix n\'est estimé.'), findsOneWidget);
    });

    testWidgets('« Où faire mes courses ? » ne conclut pas sur un seul produit commun', (tester) async {
      final basket = ShoppingBasketAnalysis.calculate([
        _trip('t1', 0, [_buy('Lait', 1.20, 'Carrefour', 0)]),
        _trip('t2', 1, [_buy('Lait', 1.00, 'Leclerc', 1)]),
      ]);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: BasketCard(analysis: basket))),
      ));
      expect(find.byKey(const ValueKey('basket_not_conclusive')), findsOneWidget);
      expect(find.byKey(const ValueKey('basket_conclusion')), findsNothing);
    });

    testWidgets('« Où faire mes courses ? » sans données explique quoi faire', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: BasketCard(analysis: null))));
      expect(find.textContaining('le même produit dans deux magasins'), findsOneWidget);
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
