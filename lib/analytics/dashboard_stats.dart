import 'package:intl/intl.dart';

import '../models.dart';
import '../utils/product_type_utils.dart';
import 'price_evolution.dart';
import 'product_observation.dart';
import 'recommendations.dart';
import 'store_comparison.dart';

/// Statistiques d'un magasin pour un type de produit donné
class ProductTypeStoreStats {
  final String storeName;
  int itemCount = 0;
  double totalAmount = 0.0;
  double minPrice = double.infinity;
  double maxPrice = 0.0;

  ProductTypeStoreStats({required this.storeName});

  void addItem(double price) {
    itemCount += 1;
    totalAmount += price;
    if (price < minPrice) minPrice = price;
    if (price > maxPrice) maxPrice = price;
  }

  double get averagePrice => itemCount > 0 ? totalAmount / itemCount : 0.0;
}

/// Statistiques agrégées pour un type de produit (catégorie OFF)
class ProductTypeStats {
  int itemCount = 0;
  double totalAmount = 0.0;
  double minPrice = double.infinity;
  double maxPrice = 0.0;
  final Map<String, ProductTypeStoreStats> storeStats = {};

  void addItem(double price, {String? storeName}) {
    itemCount += 1;
    totalAmount += price;
    if (price < minPrice) minPrice = price;
    if (price > maxPrice) maxPrice = price;

    if (storeName != null && storeName.trim().isNotEmpty) {
      final clean = storeName.trim();
      storeStats.putIfAbsent(clean, () => ProductTypeStoreStats(storeName: clean)).addItem(price);
    }
  }

  double get averagePrice => itemCount > 0 ? totalAmount / itemCount : 0.0;

  /// Magasins triés du moins cher au plus cher en moyenne
  List<ProductTypeStoreStats> get storesSortedByAveragePrice {
    final list = storeStats.values.toList()
      ..sort((a, b) => a.averagePrice.compareTo(b.averagePrice));
    return list;
  }

  /// Écart absolu entre le magasin le plus cher et le moins cher pour ce type
  double get storePriceSpread {
    final sorted = storesSortedByAveragePrice;
    if (sorted.length < 2) return 0.0;
    return sorted.last.averagePrice - sorted.first.averagePrice;
  }
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
          .addItem(observation.price, storeName: observation.storeName);
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
