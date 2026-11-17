import 'package:intl/intl.dart';

import '../models.dart';
import '../utils/product_type_utils.dart';
import '../utils/unit_price.dart';
import 'price_evolution.dart';
import 'product_observation.dart';
import 'recommendations.dart';
import 'shopping_basket.dart';
import 'store_comparison.dart';

/// Moyenne incrémentale
class _Average {
  int count = 0;
  double total = 0.0;

  void add(double value) {
    count += 1;
    total += value;
  }

  double get value => count > 0 ? total / count : 0.0;
}

/// Statistiques d'un magasin pour un type de produit donné
class ProductTypeStoreStats {
  final String storeName;
  int itemCount = 0;
  double totalAmount = 0.0;
  double minPrice = double.infinity;
  double maxPrice = 0.0;
  final Map<PriceUnit, _Average> _unitPrices = {};

  ProductTypeStoreStats({required this.storeName});

  void addItem(double price, {UnitPrice? unitPrice}) {
    itemCount += 1;
    totalAmount += price;
    if (price < minPrice) minPrice = price;
    if (price > maxPrice) maxPrice = price;
    if (unitPrice != null) {
      _unitPrices.putIfAbsent(unitPrice.unit, _Average.new).add(unitPrice.value);
    }
  }

  /// Prix moyen par article
  double get averagePrice => itemCount > 0 ? totalAmount / itemCount : 0.0;

  /// Prix moyen au kg / L / unité pour [unit], `null` sans article de cette unité
  double? averageUnitPrice(PriceUnit unit) => _unitPrices[unit]?.value;
}

/// Statistiques agrégées pour un type de produit (catégorie OFF)
///
/// Les magasins sont comparés au kg, au litre ou à l'unité dès que la
/// contenance des articles est connue ([comparisonUnit]) ; sinon par article.
class ProductTypeStats {
  int itemCount = 0;
  double totalAmount = 0.0;
  double minPrice = double.infinity;
  double maxPrice = 0.0;
  final Map<String, ProductTypeStoreStats> storeStats = {};
  final Map<PriceUnit, _Average> _unitPrices = {};

  void addItem(double price, {String? storeName, UnitPrice? unitPrice}) {
    itemCount += 1;
    totalAmount += price;
    if (price < minPrice) minPrice = price;
    if (price > maxPrice) maxPrice = price;
    if (unitPrice != null) {
      _unitPrices.putIfAbsent(unitPrice.unit, _Average.new).add(unitPrice.value);
    }

    if (storeName != null && storeName.trim().isNotEmpty) {
      final clean = storeName.trim();
      storeStats
          .putIfAbsent(clean, () => ProductTypeStoreStats(storeName: clean))
          .addItem(price, unitPrice: unitPrice);
    }
  }

  /// Prix moyen par article
  double get averagePrice => itemCount > 0 ? totalAmount / itemCount : 0.0;

  /// Unité de comparaison : la plus fréquente parmi les articles de contenance connue
  PriceUnit? get comparisonUnit {
    PriceUnit? best;
    for (final entry in _unitPrices.entries) {
      if (best == null || entry.value.count > _unitPrices[best]!.count) best = entry.key;
    }
    return best;
  }

  /// Prix moyen dans l'unité de comparaison (ex. 1.42 €/L), `null` si aucune contenance connue
  UnitPrice? get averageUnitPrice {
    final unit = comparisonUnit;
    return unit == null ? null : UnitPrice(_unitPrices[unit]!.value, unit);
  }

  /// Nombre d'articles comparés dans l'unité de comparaison
  int get unitPricedCount => comparisonUnit == null ? 0 : _unitPrices[comparisonUnit]!.count;

  /// Prix d'un magasin servant au classement : au kg / L / unité si possible, sinon par article.
  /// `null` quand le type se compare à l'unité mais que ce magasin n'a aucune contenance connue.
  double? comparablePriceOf(ProductTypeStoreStats store) {
    final unit = comparisonUnit;
    return unit == null ? store.averagePrice : store.averageUnitPrice(unit);
  }

  /// Libellé du prix comparable d'un magasin (« 1.42 €/L » ou « 1.50 €/art »)
  String formatStorePrice(ProductTypeStoreStats store) {
    final unit = comparisonUnit;
    final price = comparablePriceOf(store);
    if (unit != null && price != null) return '${price.toStringAsFixed(2)} ${unit.label}';
    return '${store.averagePrice.toStringAsFixed(2)} €/art';
  }

  /// Magasins comparables, du moins cher au plus cher
  List<ProductTypeStoreStats> get storesSortedByAveragePrice {
    final list = storeStats.values.where((s) => comparablePriceOf(s) != null).toList()
      ..sort((a, b) => comparablePriceOf(a)!.compareTo(comparablePriceOf(b)!));
    return list;
  }

  /// Indique si [store] est (ex aequo) le moins cher des magasins comparables
  bool isCheapestStore(ProductTypeStoreStats store) {
    final sorted = storesSortedByAveragePrice;
    final price = comparablePriceOf(store);
    if (sorted.isEmpty || price == null) return false;
    return price <= comparablePriceOf(sorted.first)! + 0.001;
  }

  /// Écart entre le magasin le plus cher et le moins cher, dans l'unité de comparaison
  double get storePriceSpread {
    final sorted = storesSortedByAveragePrice;
    if (sorted.length < 2) return 0.0;
    return comparablePriceOf(sorted.last)! - comparablePriceOf(sorted.first)!;
  }

  /// Unité affichée avec [storePriceSpread] (« €/L » ou « €/art »)
  String get spreadLabel => comparisonUnit?.label ?? '€/art';
}

/// Statistiques pour une période
class PeriodStats {
  int scanCount;
  int itemCount;
  double totalAmount;

  PeriodStats({
    this.scanCount = 0,
    this.itemCount = 0,
    this.totalAmount = 0.0,
  });
}

/// Statistiques complètes du tableau de bord
class DashboardStats {
  final int totalScans;
  final int totalItems;
  final double totalAmount;
  final double averagePrice;
  final Map<String, int> nutriScoreDistribution;
  final Map<String, ProductTypeStats> productTypeStats;
  final List<ProductPriceEvolutionItem> productEvolutions;
  final List<ProductStoreComparisonItem> storeComparisons;
  final List<ProductRecommendationItem> recommendations;

  /// « Où faire mes courses ? », `null` tant qu'il n'y a pas 2 magasins à comparer
  final ShoppingBasketAnalysis? shoppingBasket;
  final Map<String, PeriodStats> weeklyStats;
  final Map<String, PeriodStats> monthlyStats;
  final double weeklyTotal;
  final double monthlyTotal;

  DashboardStats({
    required this.totalScans,
    required this.totalItems,
    required this.totalAmount,
    required this.averagePrice,
    required this.nutriScoreDistribution,
    required this.productTypeStats,
    required this.productEvolutions,
    required this.storeComparisons,
    required this.recommendations,
    this.shoppingBasket,
    required this.weeklyStats,
    required this.monthlyStats,
    required this.weeklyTotal,
    required this.monthlyTotal,
  });

  /// Calcule toutes les statistiques du tableau de bord.
  /// [now] permet de fixer la date de référence des totaux par période (tests).
  factory DashboardStats.fromSessions(List<ScanSession> sessions, {DateTime? now}) {
    final observations = ProductObservation.fromSessions(sessions);

    // Répartition Nutri-Score
    final nutriscoreCounts = <String, int>{};
    for (final observation in observations) {
      final score = observation.item.nutriscore?.toLowerCase();
      if (score != null) {
        nutriscoreCounts[score] = (nutriscoreCounts[score] ?? 0) + 1;
      }
    }

    // Statistiques par type de produit (catégorie OFF la plus spécifique)
    final productTypeStats = <String, ProductTypeStats>{};
    for (final observation in observations) {
      productTypeStats
          .putIfAbsent(productTypeLabel(observation.item.categories), () => ProductTypeStats())
          .addItem(observation.price,
              storeName: observation.storeName, unitPrice: observation.unitPrice);
    }

    final totalAmount = observations.fold(0.0, (sum, o) => sum + o.price);
    final totalItems = observations.length;
    final reference = now ?? DateTime.now();

    return DashboardStats(
      totalScans: sessions.length,
      totalItems: totalItems,
      totalAmount: totalAmount,
      averagePrice: totalItems > 0 ? totalAmount / totalItems : 0.0,
      nutriScoreDistribution: nutriscoreCounts,
      productTypeStats: productTypeStats,
      productEvolutions: ProductPriceEvolutionItem.calculate(sessions),
      storeComparisons: ProductStoreComparisonItem.calculate(sessions),
      recommendations: ProductRecommendationItem.calculate(sessions),
      shoppingBasket: ShoppingBasketAnalysis.calculate(sessions),
      weeklyStats: _groupByPeriod(sessions, formatWeekKey),
      monthlyStats: _groupByPeriod(sessions, formatMonthKey),
      weeklyTotal: _periodTotal(sessions, reference, 7),
      monthlyTotal: _periodTotal(sessions, reference, 30),
    );
  }

  static Map<String, PeriodStats> _groupByPeriod(
    List<ScanSession> sessions,
    String Function(DateTime) keyOf,
  ) {
    final stats = <String, PeriodStats>{};
    for (final session in sessions) {
      final period = stats.putIfAbsent(keyOf(session.date), () => PeriodStats());
      period.scanCount += 1;
      period.itemCount += session.items.length;
      period.totalAmount += session.totalAmount;
    }
    return stats;
  }

  static double _periodTotal(List<ScanSession> sessions, DateTime now, int days) {
    final cutoff = now.subtract(Duration(days: days));
    return sessions
        .where((s) => !s.date.isBefore(cutoff))
        .fold(0.0, (sum, s) => sum + s.totalAmount);
  }
}

/// Libellé de la semaine (lundi – dimanche) contenant [date]
String formatWeekKey(DateTime date) {
  final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
  final endOfWeek = startOfWeek.add(const Duration(days: 6));
  final formatter = DateFormat('dd MMM', 'fr_FR');
  return '${formatter.format(startOfWeek)} - ${formatter.format(endOfWeek)}';
}

/// Libellé du mois contenant [date]
String formatMonthKey(DateTime date) => DateFormat('MMM yyyy', 'fr_FR').format(date);
