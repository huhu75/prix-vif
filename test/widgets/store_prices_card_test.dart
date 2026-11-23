import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prix_vif/analytics/analytics.dart';
import 'package:prix_vif/models.dart';
import 'package:prix_vif/theme.dart';
import 'package:prix_vif/widgets/scan/price_input_sheet.dart';
import 'package:prix_vif/widgets/store_prices_card.dart';

ScannedItem _milk(String id, double price, String store, DateTime date) => ScannedItem(
      id: id,
      name: 'Lait',
      brand: 'Lactel',
      price: price,
      scanDate: date,
      barcode: '123',
      storeName: store,
    );

/// Lait vu chez Lidl (0.95), Carrefour (1.09) et Monoprix (1.35) ; le prix
/// Carrefour le plus récent compte, pas l'ancien
List<ScanSession> _sessions() => [
      for (final (id, price, store, day) in [
        ('a', 0.95, 'Lidl', 5),
        ('b', 1.20, 'Carrefour', 1),
        ('c', 1.09, 'Carrefour', 8),
        ('d', 1.35, 'Monoprix', 6),
      ])
        ScanSession(id: id, date: DateTime(2026, 11, day), storeName: store, items: [_milk(id, price, store, DateTime(2026, 11, day))]),
      ScanSession(id: 'e', date: DateTime(2026, 11, 2), storeName: 'Lidl', items: [
        ScannedItem(id: 'e', name: 'Pain', price: 1, scanDate: DateTime(2026, 11, 2), barcode: '999', storeName: 'Lidl'),
      ]),
    ];

void main() {
  final milk = ProductStorePrices.forProduct(_sessions(), 'bc_123')!;

  group('ProductStorePrices.forProduct', () {
    test('dernier prix de chaque magasin, du moins cher au plus cher', () {
      expect(milk.storePrices.map((p) => (p.storeName, p.price)), [
        ('Lidl', 0.95),
        ('Carrefour', 1.09),
        ('Monoprix', 1.35),
      ]);
    });

    test('produit jamais vu : null', () {
      expect(ProductStorePrices.forProduct(_sessions(), 'bc_000'), isNull);
    });
  });

  group('buildStorePriceRows', () {
    test('le moins cher à privilégier, le plus cher à éviter', () {
      final rows = buildStorePriceRows(milk, currentStore: 'Carrefour');
      expect(rows.map((r) => (r.storeName, r.role)), [
        ('Lidl', StorePriceRole.best),
        ('Carrefour', StorePriceRole.other),
        ('Monoprix', StorePriceRole.avoid),
      ]);
      expect(rows[1].isCurrentStore, isTrue);
      expect(rows[2].diff, closeTo(0.40, 0.001));
    });

    test('le prix saisi remplace le dernier prix du magasin où l\'on est', () {
      final rows = buildStorePriceRows(milk, currentStore: 'Carrefour', typedPrice: 1.50);
      expect(rows.last.storeName, 'Carrefour');
      expect(rows.last.role, StorePriceRole.avoid);
      expect(rows.last.isTyped, isTrue);
    });

    test('un nouveau magasin s\'ajoute avec le prix saisi', () {
      final rows = buildStorePriceRows(milk, currentStore: 'Aldi', typedPrice: 0.89);
      expect(rows.first.storeName, 'Aldi');
      expect(rows.first.role, StorePriceRole.best);
      expect(rows.length, 4);
    });

    test('un seul magasin : rien à comparer ; même prix partout : pas de magasin à éviter', () {
      final single = ProductStorePrices(productId: '1', name: 'X', storePrices: [StorePrice('Lidl', 1, DateTime(2026))]);
      expect(buildStorePriceRows(single).single.role, StorePriceRole.alone);

      final rows = buildStorePriceRows(single, currentStore: 'Aldi', typedPrice: 1);
      expect(rows.map((r) => r.role), everyElement(StorePriceRole.best));
    });
  });

  group('StorePricesCard', () {
    Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
          MaterialApp(theme: AppTheme.theme, home: Scaffold(body: SingleChildScrollView(child: child))),
        );

    testWidgets('où aller, où ne pas aller, et le magasin où l\'on est', (tester) async {
      await pump(tester, StorePricesCard(prices: milk, currentStore: 'Carrefour'));

      expect(find.text('Où l\'acheter ? 3 magasins comparés'), findsOneWidget);
      expect(find.textContaining('Le moins cher · vas-y'), findsOneWidget);
      expect(find.textContaining('À éviter · +0.40 €'), findsOneWidget);
      expect(find.text('ici'), findsOneWidget);
      expect(find.text('0.14 € de plus ici que chez Lidl.'), findsOneWidget);
    });

    testWidgets('dans le magasin le moins cher', (tester) async {
      await pump(tester, StorePricesCard(prices: milk, currentStore: 'Lidl'));
      expect(find.text('Tu es au bon endroit : c\'est ici le moins cher.'), findsOneWidget);
    });
  });

  testWidgets('scan d\'un produit connu : le comparatif s\'affiche dès le scan et suit le prix tapé', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showPriceInputSheet(context, '123', null, knownPrices: milk, currentStore: 'Monoprix'),
            child: const Text('scan'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('scan'));
    // Le bouton VALIDER (MagicButton) s'anime en boucle : pas de pumpAndSettle
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('store_prices_card')), findsOneWidget);
    expect(find.text('Le plus cher ici : 0.40 € de moins chez Lidl.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '0,90');
    await tester.pump();
    expect(find.text('Tu es au bon endroit : c\'est ici le moins cher.'), findsOneWidget);
  });
}
