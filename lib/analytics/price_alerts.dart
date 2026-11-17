import '../models.dart';
import 'product_observation.dart';

/// Hausse de prix d'un produit dans un magasin, entre ses deux derniers scans dans ce magasin
class PriceAlert {
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

  PriceAlert({
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

  double get increaseAmount => latestPrice - previousPrice;
  double get increasePercent => previousPrice > 0 ? increaseAmount / previousPrice * 100 : 0.0;

  /// Seuils proposés dans l'interface (en %)
  static const List<int> thresholdChoices = [5, 10, 20];
  static const int defaultThreshold = 10;

  /// Produits dont le dernier prix dans un magasin a augmenté d'au moins
  /// [thresholdPercent] % par rapport au scan précédent dans ce même magasin.
  /// Triés de la plus forte hausse à la plus faible.
  static List<PriceAlert> calculate(List<ScanSession> sessions, {num thresholdPercent = defaultThreshold}) {
    final groups = groupByProduct(
      ProductObservation.fromSessions(sessions).where((o) => o.storeName != null),
    );
    final alerts = <PriceAlert>[];

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
        if (previous.price <= 0) continue;
        final percent = (latest.price - previous.price) / previous.price * 100;
        if (latest.price - previous.price <= 0.01 || percent < thresholdPercent) continue;

        MapEntry<String, ProductObservation>? cheaper;
        for (final other in latestPrices.entries) {
          if (other.key == entry.key || other.value.price >= latest.price - 0.01) continue;
          if (cheaper == null || other.value.price < cheaper.value.price) cheaper = other;
        }

        alerts.add(PriceAlert(
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

    alerts.sort((a, b) => b.increasePercent.compareTo(a.increasePercent));
    return alerts;
  }
}
