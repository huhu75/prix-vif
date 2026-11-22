// ===================================================
// Modèles pour l'analyse par produit (Étape 6)
// ===================================================

import 'package:flutter/material.dart';

/// Point de prix pour l'historique d'un produit dans un magasin
class PricePoint {
  final DateTime date;
  final double price;
  final double? quantity;
  final String? unit;
  final String articleId;

  PricePoint({
    required this.date,
    required this.price,
    this.quantity,
    this.unit,
    required this.articleId,
  });

  /// Crée un PricePoint depuis un article stocké
  factory PricePoint.fromStoredArticle(Map<String, dynamic> articleMap, String articleId) {
    return PricePoint(
      date: DateTime.parse(articleMap['scanDate'] as String),
      price: (articleMap['price'] as num).toDouble(),
      quantity: (articleMap['quantity'] as num?)?.toDouble(),
      unit: articleMap['unit'] as String?,
      articleId: articleId,
    );
  }

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'price': price,
    'quantity': quantity,
    'unit': unit,
    'articleId': articleId,
  };

  @override
  String toString() => 'PricePoint(date: $date, price: $price, quantity: $quantity, unit: $unit)';
}

/// Historique des prix d'un produit dans un magasin spécifique
class ProductPriceHistory {
  final String productId;
  final String productName;
  final String? barcode;
  final String? brand;
  final String storeName;
  final List<PricePoint> pricePoints;

  ProductPriceHistory({
    required this.productId,
    required this.productName,
    this.barcode,
    this.brand,
    required this.storeName,
    required this.pricePoints,
  });

  /// Trie les points de prix par date croissante
  ProductPriceHistory sortedByDate() {
    final sortedPoints = List<PricePoint>.from(pricePoints)
      ..sort((a, b) => a.date.compareTo(b.date));
    return ProductPriceHistory(
      productId: productId,
      productName: productName,
      barcode: barcode,
      brand: brand,
      storeName: storeName,
      pricePoints: sortedPoints,
    );
  }

  /// Calcule l'évolution du prix (en %)
  double get priceEvolutionPercent {
    if (pricePoints.length < 2) return 0.0;
    final sorted = sortedByDate();
    final firstPrice = sorted.pricePoints.first.price;
    final lastPrice = sorted.pricePoints.last.price;
    return ((lastPrice - firstPrice) / firstPrice) * 100;
  }

  /// Calcule la tendance
  PriceTrend get trend {
    final evolution = priceEvolutionPercent;
    if (evolution < -5) return PriceTrend.down;
    if (evolution > 5) return PriceTrend.up;
    return PriceTrend.stable;
  }

  /// Prix moyen
  double get averagePrice {
    if (pricePoints.isEmpty) return 0.0;
    return pricePoints.fold(0.0, (sum, point) => sum + point.price) / pricePoints.length;
  }

  /// Dernier prix
  double? get lastPrice {
    if (pricePoints.isEmpty) return null;
    return sortedByDate().pricePoints.last.price;
  }

  /// Premier prix
  double? get firstPrice {
    if (pricePoints.isEmpty) return null;
    return sortedByDate().pricePoints.first.price;
  }

  @override
  String toString() => 'ProductPriceHistory(product: $productName, store: $storeName, points: ${pricePoints.length})';
}

/// Tendance de prix
enum PriceTrend {
  down,   // ⬇️ Baisse
  stable, // ➡️ Stable
  up,     // ⬆️ Hausse
}

/// Extension pour afficher les icônes de tendance
extension PriceTrendExtension on PriceTrend {
  IconData get icon {
    switch (this) {
      case PriceTrend.down:
        return Icons.trending_down;
      case PriceTrend.up:
        return Icons.trending_up;
      case PriceTrend.stable:
        return Icons.trending_flat;
    }
  }

  Color get color {
    switch (this) {
      case PriceTrend.down:
        return Colors.green;
      case PriceTrend.up:
        return Colors.red;
      case PriceTrend.stable:
        return Colors.orange;
    }
  }

  String get label {
    switch (this) {
      case PriceTrend.down:
        return 'Baisse';
      case PriceTrend.up:
        return 'Hausse';
      case PriceTrend.stable:
        return 'Stable';
    }
  }
}

/// Informations sur les prix d'un produit dans un magasin
class StorePriceInfo {
  final String storeName;
  final double averagePrice;
  final double lastPrice;
  final DateTime lastScanDate;
  final int scanCount;
  final String? barcode;

  StorePriceInfo({
    required this.storeName,
    required this.averagePrice,
    required this.lastPrice,
    required this.lastScanDate,
    required this.scanCount,
    this.barcode,
  });

  @override
  String toString() => 'StorePriceInfo(store: $storeName, avg: $averagePrice, last: $lastPrice, scans: $scanCount)';
}

/// Comparaison des prix d'un produit entre différents magasins
class StorePriceComparison {
  final String productId;
  final String productName;
  final String? barcode;
  final String? brand;
  final Map<String, StorePriceInfo> storePrices;

  StorePriceComparison({
    required this.productId,
    required this.productName,
    this.barcode,
    this.brand,
    required this.storePrices,
  });

  /// Récupère le magasin le moins cher
  StorePriceInfo? get cheapestStore {
    if (storePrices.isEmpty) return null;
    
    StorePriceInfo? cheapest;
    for (final entry in storePrices.entries) {
      if (cheapest == null || entry.value.lastPrice < cheapest.lastPrice) {
        cheapest = entry.value;
      }
    }
    return cheapest;
  }

  /// Récupère la liste des magasins triés par prix croissant
  List<StorePriceInfo> get storesSortedByPrice {
    final list = storePrices.values.toList()
      ..sort((a, b) => a.lastPrice.compareTo(b.lastPrice));
    return list;
  }

  @override
  String toString() => 'StorePriceComparison(product: $productName, stores: ${storePrices.length})';
}

/// Résultat complet de l'analyse d'un produit
class ProductAnalysisResult {
  final String productId;
  final String productName;
  final String? barcode;
  final String? brand;
  final String? imageUrl;
  final String? nutriscore;
  final List<String>? categories;
  
  /// Historique des prix par magasin
  final Map<String, ProductPriceHistory> priceHistoryByStore;
  
  /// Comparaison entre magasins
  final StorePriceComparison storeComparison;
  
  /// Produits similaires

  ProductAnalysisResult({
    required this.productId,
    required this.productName,
    this.barcode,
    this.brand,
    this.imageUrl,
    this.nutriscore,
    this.categories,
    required this.priceHistoryByStore,
    required this.storeComparison,
  });

  /// Tendance globale (basée sur tous les magasins)
  PriceTrend get overallTrend {
    if (priceHistoryByStore.isEmpty) return PriceTrend.stable;
    
    // Calculer la tendance moyenne
    double totalEvolution = 0;
    int count = 0;
    for (final history in priceHistoryByStore.values) {
      if (history.pricePoints.length >= 2) {
        totalEvolution += history.priceEvolutionPercent;
        count++;
      }
    }
    
    if (count == 0) return PriceTrend.stable;
    final avgEvolution = totalEvolution / count;
    
    if (avgEvolution < -5) return PriceTrend.down;
    if (avgEvolution > 5) return PriceTrend.up;
    return PriceTrend.stable;
  }

  @override
  String toString() => 'ProductAnalysisResult(product: $productName, stores: ${priceHistoryByStore.length})';
}

/// Information sur un produit unique (pour la liste de sélection)
class UniqueProductInfo {
  final String productId;
  final String productName;
  final String? brand;
  final String? barcode;
  final String? imageUrl;
  final String? nutriscore;
  final int scanCount;
  final double averagePrice;
  final DateTime lastScanDate;
  final List<String> storeNames;
  final List<String>? categories;

  UniqueProductInfo({
    required this.productId,
    required this.productName,
    this.brand,
    this.barcode,
    this.imageUrl,
    this.nutriscore,
    required this.scanCount,
    required this.averagePrice,
    required this.lastScanDate,
    required this.storeNames,
    this.categories,
  });

  @override
  String toString() => 'UniqueProductInfo(name: $productName, scans: $scanCount, avgPrice: $averagePrice)';
}
