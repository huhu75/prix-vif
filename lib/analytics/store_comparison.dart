import '../models.dart';
import 'product_observation.dart';

/// Comparaison multi-magasins d'un produit pour le tableau de bord
class ProductStoreComparisonItem {
  final String productId;
  final String name;
  final String? brand;
  final String? barcode;
  final String? imageUrl;
  final String cheapestStore;
  final double cheapestPrice;
  final String mostExpensiveStore;
  final double mostExpensivePrice;
  final int storeCount;
  final Map<String, double> latestPriceByStore;

  ProductStoreComparisonItem({
    required this.productId,
    required this.name,
    this.brand,
    this.barcode,
    this.imageUrl,
    required this.cheapestStore,
    required this.cheapestPrice,
    required this.mostExpensiveStore,
    required this.mostExpensivePrice,
    required this.storeCount,
    required this.latestPriceByStore,
  });

  /// Écart absolu entre le magasin le plus cher et le moins cher
  double get priceDiff => mostExpensivePrice - cheapestPrice;

  /// Pourcentage d'économie possible
  double get savingPercent {
    if (mostExpensivePrice <= 0) return 0.0;
    return (priceDiff / mostExpensivePrice) * 100;
  }

  bool get hasPriceDifference => priceDiff > 0.01;

  /// Calcule les comparaisons inter-magasins depuis les sessions
  static List<ProductStoreComparisonItem> calculate(List<ScanSession> sessions) {
    final groups = groupByProduct(
      ProductObservation.fromSessions(sessions).where((o) => o.storeName != null),
    );
    final comparisons = <ProductStoreComparisonItem>[];

    for (final observations in groups.values) {
      final latestPriceByStore =
          latestByStore(observations).map((store, obs) => MapEntry(store, obs.price));
      if (latestPriceByStore.length < 2) continue;

      var cheapestStore = '';
      var cheapestPrice = double.infinity;
      var mostExpensiveStore = '';
      var mostExpensivePrice = 0.0;

      for (final entry in latestPriceByStore.entries) {
        if (entry.value < cheapestPrice) {
          cheapestPrice = entry.value;
          cheapestStore = entry.key;
        }
        if (entry.value > mostExpensivePrice) {
          mostExpensivePrice = entry.value;
          mostExpensiveStore = entry.key;
        }
      }

      final meta = observations.first;
      comparisons.add(ProductStoreComparisonItem(
        productId: meta.productId,
        name: meta.item.name,
        brand: meta.item.brand,
        barcode: meta.item.barcode,
        imageUrl: meta.item.imageUrl,
        cheapestStore: cheapestStore,
        cheapestPrice: cheapestPrice,
        mostExpensiveStore: mostExpensiveStore,
        mostExpensivePrice: mostExpensivePrice,
        storeCount: latestPriceByStore.length,
        latestPriceByStore: latestPriceByStore,
      ));
    }

    comparisons.sort((a, b) => b.priceDiff.compareTo(a.priceDiff));

    return comparisons;
  }
}
