import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prix_vif/analytics/analytics.dart';
import 'package:prix_vif/models.dart';
import 'package:prix_vif/widgets/dashboard/price_alerts_section.dart';
import 'package:prix_vif/widgets/dashboard/shopping_basket_section.dart';

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

  group('PriceAlert', () {
    final sessions = [
      _trip('t1', 0, [_buy('Lait', 1.00, 'Carrefour', 0), _buy('Pain', 2.00, 'Carrefour', 0)]),
      _trip('t2', 3, [_buy('Lait', 0.95, 'Leclerc', 3)]),
      _trip('t3', 7, [_buy('Lait', 1.15, 'Carrefour', 7), _buy('Pain', 2.10, 'Carrefour', 7)]),
    ];

    test('détecte une hausse au-delà du seuil dans le même magasin', () {
      final alerts = PriceAlert.calculate(sessions, thresholdPercent: 10);
      expect(alerts.length, 1);
      final alert = alerts.single;
      expect(alert.name, 'Lait');
      expect(alert.storeName, 'Carrefour');
      expect(alert.increasePercent, closeTo(15, 0.01));
      expect(alert.cheaperStore, 'Leclerc');
      expect(alert.cheaperPrice, 0.95);
    });

    test('le seuil filtre les petites hausses', () {
      expect(PriceAlert.calculate(sessions, thresholdPercent: 6).map((a) => a.name), ['Lait']);
      expect(PriceAlert.calculate(sessions, thresholdPercent: 4).map((a) => a.name), ['Lait', 'Pain']);
      expect(PriceAlert.calculate(sessions, thresholdPercent: 20), isEmpty);
    });
  });

  group('sections du Dashboard', () {
    testWidgets('« Où faire mes courses ? » affiche le meilleur magasin et le panier combiné', (tester) async {
      final basket = ShoppingBasketAnalysis.calculate([
        _trip('t1', 0, [_buy('Lait', 1.20, 'Carrefour', 0), _buy('Pain', 2.00, 'Carrefour', 0)]),
        _trip('t2', 1, [_buy('Lait', 1.00, 'Leclerc', 1), _buy('Pain', 2.20, 'Leclerc', 1)]),
      ]);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: ShoppingBasketSection(analysis: basket))),
      ));

      expect(find.text('Où faire mes courses ?'), findsOneWidget);
      expect(find.text('3.20 €'), findsWidgets);
      expect(find.textContaining('En combinant les magasins : 3.00 €'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('basket_optimal_toggle')));
      await tester.pump();
      expect(find.text('• Pain — 2.00 €'), findsOneWidget);
    });

    testWidgets('« Où faire mes courses ? » sans données explique quoi faire', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ShoppingBasketSection(analysis: null))));
      expect(find.textContaining('au moins deux magasins'), findsOneWidget);
    });

    testWidgets('les alertes suivent le seuil choisi', (tester) async {
      final sessions = [
        _trip('t1', 0, [_buy('Lait', 1.00, 'Carrefour', 0)]),
        _trip('t2', 7, [_buy('Lait', 1.07, 'Carrefour', 7)]),
      ];
      String? tapped;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PriceAlertsSection(sessions: sessions, onProductTap: (id, _) => tapped = id),
          ),
        ),
      ));

      // +7 % : rien au seuil par défaut de 10 %
      expect(find.textContaining('Aucune hausse'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('alert_threshold_5')));
      await tester.pump();
      expect(find.text('+7 %'), findsOneWidget);

      await tester.tap(find.text('Lait'));
      expect(tapped, 'ean_Lait');
    });
  });
}
