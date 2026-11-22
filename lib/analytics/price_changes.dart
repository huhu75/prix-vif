import '../models.dart';
import 'product_observation.dart';

/// Changement de prix d'un produit dans un magasin, entre ses deux derniers
/// achats dans ce magasin (onglet « Prix » du tableau de bord)
class PriceChange {
  final String productId;
  final String name;
  final String? brand;
  final String storeName;
  final double previousPrice;
  final double latestPrice;
  final DateTime latestDate;

  /// Magasin où ce produit est moins cher (dernier prix connu), s'il y en a un
  final String? cheaperStore;
  final double? cheaperPrice;

  PriceChange({
    required this.productId,
    required this.name,
    this.brand,
    required this.storeName,
    required this.previousPrice,
    required this.latestPrice,
    required this.latestDate,
    this.cheaperStore,
    this.cheaperPrice,
  });

  double get amount => latestPrice - previousPrice;
  double get percent => previousPrice > 0 ? amount / previousPrice * 100 : 0.0;
  bool get isIncrease => amount > 0;

  /// Tous les changements de plus d'un centime, de la plus forte hausse à la
  /// plus forte baisse (en %).
  static List<PriceChange> calculate(List<ScanSession> sessions) {
    final groups = groupByProduct(
      ProductObservation.fromSessions(sessions).where((o) => o.storeName != null),
    );
    final changes = <PriceChange>[];

    for (final observations in groups.values) {
      final byStore = <String, List<ProductObservation>>{};
      for (final o in observations) {
        byStore.putIfAbsent(o.storeName!, () => []).add(o);
      }
      final latestPrices = latestByStore(observations);

      for (final entry in byStore.entries) {
        final history = entry.value..sort((a, b) => a.date.compareTo(b.date));
        if (history.length < 2) continue;
        final previous = history[history.length - 2];
        final latest = history.last;
        if (previous.price <= 0 || (latest.price - previous.price).abs() <= 0.01) continue;

        MapEntry<String, ProductObservation>? cheaper;
        for (final other in latestPrices.entries) {
          if (other.key == entry.key || other.value.price >= latest.price - 0.01) continue;
          if (cheaper == null || other.value.price < cheaper.value.price) cheaper = other;
        }

        changes.add(PriceChange(
          productId: latest.productId,
          name: latest.item.name,
          brand: latest.item.brand,
          storeName: entry.key,
          previousPrice: previous.price,
          latestPrice: latest.price,
          latestDate: latest.date,
          cheaperStore: cheaper?.key,
          cheaperPrice: cheaper?.value.price,
        ));
      }
    }

    changes.sort((a, b) => b.percent.compareTo(a.percent));
    return changes;
  }
}
