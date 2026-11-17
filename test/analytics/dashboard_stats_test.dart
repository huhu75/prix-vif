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

  group('DashboardStats.fromSessions', () {
    final sessions = [
      ScanSession(id: 'recent', date: now.subtract(const Duration(days: 2)), items: [
        _item('a', price: 2.0, date: now, store: 'Carrefour', categories: ['Milks'], nutriscore: 'A'),
        _item('b', price: 3.0, date: now, store: 'Leclerc', categories: ['Milks'], nutriscore: 'a'),
      ]),
      ScanSession(id: 'old', date: now.subtract(const Duration(days: 20)), items: [
        _item('c', price: 5.0, date: now, name: 'Pain', categories: ['Breads'], nutriscore: 'C'),
      ]),
    ];

    test('totaux, moyenne et Nutri-Score', () {
      final stats = DashboardStats.fromSessions(sessions, now: now);
      expect(stats.totalScans, 2);
      expect(stats.totalItems, 3);
      expect(stats.totalAmount, 10.0);
      expect(stats.averagePrice, closeTo(3.33, 0.01));
      expect(stats.nutriScoreDistribution, {'a': 2, 'c': 1});
    });

    test('totaux sur 7 et 30 jours', () {
      final stats = DashboardStats.fromSessions(sessions, now: now);
      expect(stats.weeklyTotal, 5.0);
      expect(stats.monthlyTotal, 10.0);
    });

    test('statistiques par type et classement des magasins', () {
      final milks = DashboardStats.fromSessions(sessions, now: now).productTypeStats['Milks']!;
      expect(milks.itemCount, 2);
      expect(milks.averagePrice, 2.5);
      expect(milks.storesSortedByAveragePrice.map((s) => s.storeName), ['Carrefour', 'Leclerc']);
      expect(milks.storePriceSpread, 1.0);
    });
  });
}
