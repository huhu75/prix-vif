import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prix_vif/screens/dashboard_screen.dart';
import 'package:prix_vif/analytics/analytics.dart';
import 'package:prix_vif/models.dart';
import 'package:intl/date_symbol_data_local.dart';

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

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  String? openedProduct;
  int? openedTab;

  Widget dashboard(List<ScanSession> sessions, {VoidCallback? onAllProducts}) {
    openedProduct = null;
    openedTab = null;
    return MaterialApp(
      home: DashboardScreen(
        sessions: sessions,
        onProductAnalysisRequested: onAllProducts,
        onProductSelected: (id, _, {initialTabIndex = 0}) {
          openedProduct = id;
          openedTab = initialTabIndex;
        },
      ),
    );
  }

  testWidgets('s\'ouvre sur l\'onglet Produits : où chaque produit est le moins cher', (tester) async {
    await tester.pumpWidget(dashboard(_sessions()));
    expect(find.byKey(const ValueKey('dashboard_scaffold')), findsOneWidget);
    expect(find.text('Produits'), findsOneWidget);
    expect(find.text('Magasins'), findsOneWidget);
    expect(find.text('Évolution'), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard_products_tab')), findsOneWidget);

    // Lait comparé : Leclerc en tête, Carrefour avec l'écart
    expect(find.text('Où chaque produit est le moins cher'), findsOneWidget);
    expect(find.text('0.99 €'), findsOneWidget);
    expect(find.text('1.20 €  (+0.21 €)'), findsOneWidget);
    // Beurre : un seul magasin
    expect(find.text('Vus dans un seul magasin (1)'), findsOneWidget);
    expect(find.text('Vu seulement chez Carrefour'), findsOneWidget);

    await tester.tap(find.text('Lait'));
    expect(openedProduct, 'lait');
    expect(openedTab, 2);
  });

  testWidgets('onglet Produits : la recherche filtre les produits', (tester) async {
    await tester.pumpWidget(dashboard(_sessions()));
    await tester.enterText(find.byKey(const ValueKey('dashboard_product_search')), 'beur');
    await tester.pump();
    expect(find.text('Beurre'), findsOneWidget);
    expect(find.text('Lait'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('dashboard_product_search')), 'xyz');
    await tester.pump();
    expect(find.text('Aucun produit ne correspond à « xyz ».'), findsOneWidget);
  });

  testWidgets('sans scan : état vide, sans onglets', (tester) async {
    await tester.pumpWidget(dashboard(const []));
    expect(find.text('Aucune donnée'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('onglet Magasins : ce que chaque magasin a de moins cher', (tester) async {
    await tester.pumpWidget(dashboard(_sessions()));
    await tester.tap(find.text('Magasins'));
    await tester.pumpAndSettle();

    expect(find.text('Où faire mes courses ?'), findsOneWidget);
    expect(find.text('Ce que chaque magasin a de moins cher'), findsOneWidget);
    expect(find.text('Leclerc · 1 produit moins cher'), findsOneWidget);

    await tester.tap(find.text('Lait'));
    expect(openedProduct, 'lait');
    expect(openedTab, 2);
  });

  testWidgets('onglet Évolution : une hausse ouvre la fiche sur l\'onglet Évolution', (tester) async {
    await tester.pumpWidget(dashboard(_sessions()));
    await tester.tap(find.text('Évolution'));
    await tester.pumpAndSettle();

    expect(find.text('Ce qui a augmenté'), findsOneWidget);
    expect(find.text('+20 %'), findsOneWidget);
    expect(find.text('Moins cher chez Leclerc : 0.99 €'), findsOneWidget);
    expect(find.text('Aucune baisse depuis tes derniers achats.'), findsOneWidget);

    await tester.tap(find.text('Lait'));
    expect(openedProduct, 'lait');
    expect(openedTab, 1);
  });

  testWidgets('le bouton « Tous mes produits » ouvre la liste des produits', (tester) async {
    var opened = 0;
    await tester.pumpWidget(dashboard(_sessions(), onAllProducts: () => opened++));
    expect(find.byTooltip('Tous mes produits'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dashboard_all_products')));
    expect(opened, 1);
  });

  test('ProductStorePrices.calculate identifie magasin le moins cher et écart', () {
    final t0 = DateTime(2026, 11, 2);
    final sessions = [
      ScanSession(id: 'sess_leclerc', date: t0, storeName: 'Leclerc', items: [
        ScannedItem(
          id: 'm1',
          name: 'Pâte à Tartiner',
          brand: 'Nocciolata',
          barcode: '8001234567890',
          price: 3.20,
          scanDate: t0,
          storeName: 'Leclerc',
        ),
      ]),
      ScanSession(id: 'sess_monoprix', date: t0, storeName: 'Monoprix', items: [
        ScannedItem(
          id: 'm2',
          name: 'Pâte à Tartiner',
          brand: 'Nocciolata',
          barcode: '8001234567890',
          price: 4.10,
          scanDate: t0,
          storeName: 'Monoprix',
        ),
      ]),
    ];

    final item = ProductStorePrices.calculate(sessions).single;
    expect(item.name, 'Pâte à Tartiner');
    expect(item.cheapest.storeName, 'Leclerc');
    expect(item.cheapest.price, 3.20);
    expect(item.mostExpensive.storeName, 'Monoprix');
    expect(item.mostExpensive.price, 4.10);
    expect(item.priceDiff, closeTo(0.90, 0.001));
    expect(item.savingPercent, closeTo(21.95, 0.1));
    expect(item.hasPriceDifference, isTrue);
  });
}
