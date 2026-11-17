import '../models.dart';
import '../models/product_analysis_models.dart';
import 'product_observation.dart';

/// Résumé d'évolution de prix d'un produit pour le tableau de bord
class ProductPriceEvolutionItem {
  final String productId;
  final String name;
  final String? brand;
  final String? barcode;
  final String? imageUrl;
  final double latestPrice;
  final double firstPrice;
  final double previousPrice;
  final DateTime latestDate;
  final String? latestStore;
  final int scanCount;
  final List<double> prices;
  final List<DateTime> dates;

  ProductPriceEvolutionItem({
    required this.productId,
    required this.name,
    this.brand,
    this.barcode,
    this.imageUrl,
    required this.latestPrice,
    required this.firstPrice,
    required this.previousPrice,
    required this.latestDate,
    this.latestStore,
    required this.scanCount,
    required this.prices,
    required this.dates,
  });

  /// Variation en euros par rapport au prix précédent (ou premier prix)
  double get priceDiff => latestPrice - (prices.length > 1 ? previousPrice : firstPrice);

  /// Variation globale depuis le tout premier scan
  double get totalDiff => latestPrice - firstPrice;

  /// Pourcentage de variation par rapport au prix précédent (ou premier prix)
  double get percentDiff {
    final base = prices.length > 1 ? previousPrice : firstPrice;
    if (base <= 0) return 0.0;
    return ((latestPrice - base) / base) * 100;
  }

  /// Tendance du prix
  PriceTrend get trend {
    final diff = priceDiff;
    if (diff > 0.01) return PriceTrend.up;
    if (diff < -0.01) return PriceTrend.down;
    return PriceTrend.stable;
  }

  bool get hasEvolution => prices.length >= 2;

  /// Calcule la liste des évolutions de produits à partir d'une liste de sessions
  static List<ProductPriceEvolutionItem> calculate(List<ScanSession> sessions) {
    final groups = groupByProduct(ProductObservation.fromSessions(sessions));
    final evolutions = <ProductPriceEvolutionItem>[];

    for (final observations in groups.values) {
      // Trier par date croissante
      observations.sort((a, b) => a.date.compareTo(b.date));

      final first = observations.first;
      final latest = observations.last;
      final previous = observations.length > 1 ? observations[observations.length - 2] : first;

      evolutions.add(ProductPriceEvolutionItem(
        productId: latest.productId,
        name: latest.item.name,
        brand: latest.item.brand,
        barcode: latest.item.barcode,
        imageUrl: latest.item.imageUrl,
        latestPrice: latest.price,
        firstPrice: first.price,
        previousPrice: previous.price,
        latestDate: latest.date,
        latestStore: latest.storeName,
        scanCount: observations.length,
        prices: observations.map((o) => o.price).toList(),
        dates: observations.map((o) => o.date).toList(),
      ));
    }

    // Priorité de tri :
    // 1. Produits avec vraie variation de prix (|diff| > 0.01)
    // 2. Produits avec plusieurs scans (historique prêt)
    // 3. Produits les plus récents
    evolutions.sort((a, b) {
      final aHasVar = a.hasEvolution && a.priceDiff.abs() > 0.01;
      final bHasVar = b.hasEvolution && b.priceDiff.abs() > 0.01;
      if (aHasVar && !bHasVar) return -1;
      if (!aHasVar && bHasVar) return 1;

      if (a.hasEvolution && !b.hasEvolution) return -1;
      if (!a.hasEvolution && b.hasEvolution) return 1;

      return b.latestDate.compareTo(a.latestDate);
    });

    return evolutions;
  }
}
