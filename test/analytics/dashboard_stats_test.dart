import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prix_vif/analytics/analytics.dart';
import 'package:prix_vif/models.dart';

ScannedItem _item(
  String id, {
  required double price,
  required DateTime date,
  String name = 'Lait',
  String? barcode,
  String? store,
  List<String>? categories,
  String? nutriscore,
}) {
  return ScannedItem(
    id: id,
    name: name,
    brand: 'Candia',
    price: price,
    scanDate: date,
    barcode: barcode,
    storeName: store,
    categories: categories,
    nutriscore: nutriscore,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  final now = DateTime(2026, 11, 17, 12);

  group('ProductObservation', () {
    test('identité produit : EAN prioritaire, sinon nom + marque', () {
      final withEan = _item('1', price: 1, date: now, barcode: ' 123 ');
      final withoutEan = _item('2', price: 1, date: now, name: ' Lait Entier ');
      expect(productKeyOf(withEan), 'bc_123');
      expect(productIdOf(withEan), '123');
      expect(productKeyOf(withoutEan), 'name_lait entier_candia');
      expect(productIdOf(withoutEan), 'Lait Entier');
    });

    test('le magasin de la session sert de repli', () {
      final session = ScanSession(
        id: 's',
        date: now,
        storeName: 'Leclerc',
        items: [_item('1', price: 1, date: now)],
      );
      expect(ProductObservation.fromSessions([session]).single.storeName, 'Leclerc');
    });

    test('latestByStore garde le scan le plus récent de chaque magasin', () {
      final session = ScanSession(id: 's', date: now, items: [
        _item('1', price: 1.00, date: now.subtract(const Duration(days: 3)), store: 'Carrefour'),
        _item('2', price: 1.20, date: now, store: 'Carrefour'),
        _item('3', price: 0.90, date: now, store: 'Leclerc'),
        _item('4', price: 0.10, date: now),
      ]);
      final latest = latestByStore(ProductObservation.fromSessions([session]));
      expect(latest.map((store, o) => MapEntry(store, o.price)), {'Carrefour': 1.20, 'Leclerc': 0.90});
    });
  });

  group('ProductStorePrices (onglet Produits)', () {
    final earlier = now.subtract(const Duration(days: 5));
    final sessions = [
      ScanSession(id: 's', date: now, items: [
        // Lait : 1.10 puis 1.00 chez Carrefour (le dernier prix compte), 0.90 chez Leclerc, 1.30 chez Monoprix
        _item('1', price: 1.10, date: earlier, barcode: 'lait', store: 'Carrefour'),
        _item('2', price: 1.00, date: now, barcode: 'lait', store: 'Carrefour'),
        _item('3', price: 0.90, date: now, barcode: 'lait', store: 'Leclerc'),
        _item('4', price: 1.30, date: now, barcode: 'lait', store: 'Monoprix'),
        // Pain : même prix dans deux magasins
        _item('5', price: 2.00, date: now, barcode: 'pain', name: 'Pain', store: 'Carrefour'),
        _item('6', price: 2.00, date: now, barcode: 'pain', name: 'Pain', store: 'Leclerc'),
        // Beurre : un seul magasin ; Café : petit écart
        _item('7', price: 3.00, date: now, barcode: 'beurre', name: 'Beurre', store: 'Leclerc'),
        _item('8', price: 4.00, date: now, barcode: 'cafe', name: 'Café', store: 'Carrefour'),
        _item('9', price: 3.90, date: now, barcode: 'cafe', name: 'Café', store: 'Monoprix'),
        // Sans magasin : ignoré
        _item('10', price: 0.50, date: now, barcode: 'chips', name: 'Chips'),
      ]),
    ];

    test('magasins du moins cher au plus cher, avec le dernier prix de chaque magasin', () {
      final lait = ProductStorePrices.calculate(sessions).firstWhere((p) => p.productId == 'lait');
      expect(lait.storePrices.map((s) => s.storeName), ['Leclerc', 'Carrefour', 'Monoprix']);
      expect(lait.storePrices.map((s) => s.price), [0.90, 1.00, 1.30]);
      expect(lait.cheapest.storeName, 'Leclerc');
      expect(lait.priceDiff, closeTo(0.40, 0.001));
      expect(lait.hasPriceDifference, isTrue);
    });

    test('écarts de prix d\'abord (du plus gros au plus petit), puis les autres par nom', () {
      expect(ProductStorePrices.calculate(sessions).map((p) => p.productId), ['lait', 'cafe', 'beurre', 'pain']);
    });
  });

  group('DashboardStats.fromSessions', () {
    test('ce que chaque magasin a de moins cher, magasins les mieux placés d\'abord', () {
      final stats = DashboardStats.fromSessions([
        ScanSession(id: 's', date: now, items: [
          _item('1', price: 1.00, date: now, barcode: 'lait', store: 'Carrefour'),
          _item('2', price: 0.90, date: now, barcode: 'lait', store: 'Leclerc'),
          _item('3', price: 2.00, date: now, barcode: 'pain', name: 'Pain', store: 'Carrefour'),
          _item('4', price: 2.20, date: now, barcode: 'pain', name: 'Pain', store: 'Leclerc'),
          _item('5', price: 4.00, date: now, barcode: 'cafe', name: 'Café', store: 'Carrefour'),
          _item('6', price: 4.50, date: now, barcode: 'cafe', name: 'Café', store: 'Leclerc'),
          _item('7', price: 3.00, date: now, barcode: 'beurre', name: 'Beurre', store: 'Leclerc'),
        ]),
      ]);
      expect(stats.comparedProducts.map((p) => p.productId).toSet(), {'lait', 'pain', 'cafe'});
      final byStore = stats.cheapestByStore;
      expect(byStore.keys, ['Carrefour', 'Leclerc']);
      expect(byStore['Carrefour']!.map((p) => p.productId), ['cafe', 'pain']);
      expect(byStore['Leclerc']!.map((p) => p.productId), ['lait']);
    });

    test('sépare hausses et baisses, des plus fortes aux plus faibles', () {
      final before = now.subtract(const Duration(days: 7));
      ScanSession trip(String id, DateTime date, double lait, double pain, double cafe) => ScanSession(
            id: id,
            date: date,
            items: [
              _item('${id}_l', price: lait, date: date, barcode: 'lait', store: 'Carrefour'),
              _item('${id}_p', price: pain, date: date, barcode: 'pain', name: 'Pain', store: 'Carrefour'),
              _item('${id}_c', price: cafe, date: date, barcode: 'cafe', name: 'Café', store: 'Carrefour'),
            ],
          );
      final stats = DashboardStats.fromSessions([
        trip('avant', before, 1.00, 2.00, 4.00),
        trip('apres', now, 1.20, 1.80, 4.20),
      ]);
      // Lait +20 %, Café +5 %, Pain −10 %
      expect(stats.increases.map((c) => c.productId), ['lait', 'cafe']);
      expect(stats.decreases.map((c) => c.productId), ['pain']);
    });
  });
}
