import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prix_vif/analytics/analytics.dart';
import 'package:prix_vif/screens/home_screen.dart';
import 'package:prix_vif/theme.dart';

ProductStorePrices _product(String id, String name, List<(String, double, int)> prices, {String? brand}) =>
    ProductStorePrices(
      productKey: 'bc_$id',
      productId: id,
      name: name,
      brand: brand,
      storePrices: [for (final (store, price, day) in prices) StorePrice(store, price, DateTime(2026, 11, day))]
        ..sort((a, b) => a.price.compareTo(b.price)),
    );

final _products = [
  _product('lait', 'Lait demi-écrémé', [('Lidl', 0.95, 3), ('Carrefour', 1.09, 4)], brand: 'Lactel'),
  _product('cafe', 'Café moulu', [('Carrefour', 3.50, 10)]),
  _product('pates', 'Pâtes Penne', [('Auchan', 1.10, 1)], brand: 'Barilla'),
  _product('yaourt', 'Yaourt nature', [('Lidl', 1.50, 7)]),
];

void main() {
  late List<String> opened;
  late List<String> dashboardQueries;
  late int scans;

  Future<void> pumpHome(WidgetTester tester, {List<ProductStorePrices>? products}) async {
    opened = [];
    dashboardQueries = [];
    scans = 0;
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: HomeScreen(
        onScanBarcode: () => scans++,
        onScanTicket: () {},
        onOpenAnalysis: () {},
        products: products ?? _products,
        categoryOf: (p) => p.productId == 'yaourt' ? 'Yaourts' : null,
        onProductTap: (id, name) => opened.add(id),
        onSearchInDashboard: dashboardQueries.add,
      ),
    ));
  }

  final search = find.byKey(const ValueKey('home_product_search'));

  testWidgets('taper un mot sans accent trouve le produit et le magasin le moins cher', (tester) async {
    await pumpHome(tester);
    await tester.enterText(search, 'pate');
    await tester.pump();

    expect(find.text('Pâtes Penne'), findsOneWidget);
    expect(find.text('Lait demi-écrémé'), findsNothing);
    expect(find.text('Vu seulement chez Auchan · Barilla'), findsOneWidget);

    await tester.tap(find.text('Pâtes Penne'));
    expect(opened, ['pates']);
  });

  testWidgets('cherche aussi par magasin, marque et catégorie', (tester) async {
    await pumpHome(tester);
    await tester.enterText(search, 'lidl');
    await tester.pump();
    expect(find.text('Lait demi-écrémé'), findsOneWidget);
    expect(find.text('Yaourt nature'), findsOneWidget);
    expect(find.text('Moins cher chez Lidl · 2 magasins · Lactel'), findsOneWidget);

    await tester.enterText(search, 'yaourts');
    await tester.pump();
    expect(find.text('Yaourt nature'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home_search_see_all')));
    expect(dashboardQueries, ['yaourts']);
  });

  testWidgets('champ vide et sélectionné : les produits scannés récemment, le plus récent d\'abord', (tester) async {
    await pumpHome(tester);
    expect(find.text('Récemment scannés'), findsNothing);

    await tester.tap(search);
    await tester.pump();
    expect(find.text('Récemment scannés'), findsOneWidget);
    final first = tester.getTopLeft(find.text('Café moulu')).dy;
    final last = tester.getTopLeft(find.text('Pâtes Penne')).dy;
    expect(first, lessThan(last));
  });

  testWidgets('rien trouvé : proposer de scanner le produit', (tester) async {
    await pumpHome(tester);
    await tester.enterText(search, 'chocolat');
    await tester.pump();
    expect(find.text('Aucun produit scanné ne correspond à « chocolat ».'), findsOneWidget);

    await tester.tap(find.text('Le scanner pour l\'ajouter'));
    expect(scans, 1);
  });

  testWidgets('aucun produit scanné : pas de recherche', (tester) async {
    await pumpHome(tester, products: const []);
    expect(search, findsNothing);
    expect(find.text('Scanner un code-barres'), findsOneWidget);
  });
}
