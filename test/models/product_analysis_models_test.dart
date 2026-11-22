import 'package:flutter_test/flutter_test.dart';
import 'package:prix_vif/models/product_analysis_models.dart';
import 'package:flutter/material.dart';

void main() {
  group('ProductPriceHistory Tests', () {
    test('Calcul d\'évolution des prix - Hausse', () {
      final history = ProductPriceHistory(
        productId: '1',
        productName: 'Lait',
        storeName: 'Carrefour',
        pricePoints: [
          PricePoint(date: DateTime(2026, 1, 1), price: 1.00, articleId: 'a1'),
          PricePoint(date: DateTime(2026, 6, 1), price: 1.50, articleId: 'a2'),
        ],
      );
      
      expect(history.priceEvolutionPercent, closeTo(50.0, 0.01));
      expect(history.trend, PriceTrend.up);
      expect(history.firstPrice, 1.00);
      expect(history.lastPrice, 1.50);
      expect(history.averagePrice, 1.25);
    });

    test('Calcul d\'évolution des prix - Baisse', () {
      final history = ProductPriceHistory(
        productId: '1',
        productName: 'Lait',
        storeName: 'Carrefour',
        pricePoints: [
          PricePoint(date: DateTime(2026, 1, 1), price: 2.00, articleId: 'a1'),
          PricePoint(date: DateTime(2026, 6, 1), price: 1.50, articleId: 'a2'),
        ],
      );
      
      expect(history.priceEvolutionPercent, closeTo(-25.0, 0.01));
      expect(history.trend, PriceTrend.down);
    });

    test('Calcul d\'évolution des prix - Stable', () {
      final history = ProductPriceHistory(
        productId: '1',
        productName: 'Lait',
        storeName: 'Carrefour',
        pricePoints: [
          PricePoint(date: DateTime(2026, 1, 1), price: 1.00, articleId: 'a1'),
          PricePoint(date: DateTime(2026, 6, 1), price: 1.02, articleId: 'a2'),
        ],
      );
      
      // Évolution de 2% -> stable (seuil à 5%)
      expect(history.priceEvolutionPercent, closeTo(2.0, 0.01));
      expect(history.trend, PriceTrend.stable);
    });

    test('Calcul d\'évolution des prix - Seuil exact 5%', () {
      // Test du seuil supérieur pour "up"
      final historyUp = ProductPriceHistory(
        productId: '1',
        productName: 'Lait',
        storeName: 'Carrefour',
        pricePoints: [
          PricePoint(date: DateTime(2026, 1, 1), price: 1.00, articleId: 'a1'),
          PricePoint(date: DateTime(2026, 6, 1), price: 1.0501, articleId: 'a2'),
        ],
      );
      
      expect(historyUp.priceEvolutionPercent, greaterThan(5.0));
      expect(historyUp.trend, PriceTrend.up);
      
      // Test du seuil inférieur pour "down"
      final historyDown = ProductPriceHistory(
        productId: '1',
        productName: 'Lait',
        storeName: 'Carrefour',
        pricePoints: [
          PricePoint(date: DateTime(2026, 1, 1), price: 1.00, articleId: 'a1'),
          PricePoint(date: DateTime(2026, 6, 1), price: 0.9499, articleId: 'a2'),
        ],
      );
      
      expect(historyDown.priceEvolutionPercent, lessThan(-5.0));
      expect(historyDown.trend, PriceTrend.down);
    });

    test('Calcul d\'évolution des prix - Un seul point', () {
      final history = ProductPriceHistory(
        productId: '1',
        productName: 'Lait',
        storeName: 'Carrefour',
        pricePoints: [
          PricePoint(date: DateTime(2026, 1, 1), price: 1.00, articleId: 'a1'),
        ],
      );
      
      expect(history.priceEvolutionPercent, 0.0);
      expect(history.trend, PriceTrend.stable);
    });

    test('Calcul d\'évolution des prix - Points non triés', () {
      final history = ProductPriceHistory(
        productId: '1',
        productName: 'Lait',
        storeName: 'Carrefour',
        pricePoints: [
          PricePoint(date: DateTime(2026, 6, 1), price: 1.50, articleId: 'a2'),
          PricePoint(date: DateTime(2026, 1, 1), price: 1.00, articleId: 'a1'),
        ],
      );
      
      // Le calcul devrait trier automatiquement
      expect(history.priceEvolutionPercent, closeTo(50.0, 0.01));
      expect(history.trend, PriceTrend.up);
    });

    test('sortedByDate trie correctement les points', () {
      final history = ProductPriceHistory(
        productId: '1',
        productName: 'Lait',
        storeName: 'Carrefour',
        pricePoints: [
          PricePoint(date: DateTime(2026, 6, 1), price: 1.50, articleId: 'a2'),
          PricePoint(date: DateTime(2026, 1, 1), price: 1.00, articleId: 'a1'),
          PricePoint(date: DateTime(2026, 3, 1), price: 1.20, articleId: 'a3'),
        ],
      );
      
      final sorted = history.sortedByDate();
      expect(sorted.pricePoints[0].date, DateTime(2026, 1, 1));
      expect(sorted.pricePoints[1].date, DateTime(2026, 3, 1));
      expect(sorted.pricePoints[2].date, DateTime(2026, 6, 1));
    });
  });

  group('StorePriceComparison Tests', () {
    test('Identification du magasin le moins cher', () {
      final comparison = StorePriceComparison(
        productId: '1',
        productName: 'Lait',
        storePrices: {
          'Carrefour': StorePriceInfo(
            storeName: 'Carrefour',
            averagePrice: 1.20,
            lastPrice: 1.20,
            lastScanDate: DateTime.now(),
            scanCount: 5,
          ),
          'Leclerc': StorePriceInfo(
            storeName: 'Leclerc',
            averagePrice: 1.10,
            lastPrice: 1.10,
            lastScanDate: DateTime.now(),
            scanCount: 3,
          ),
          'Monoprix': StorePriceInfo(
            storeName: 'Monoprix',
            averagePrice: 1.30,
            lastPrice: 1.30,
            lastScanDate: DateTime.now(),
            scanCount: 2,
          ),
        },
      );
      
      expect(comparison.cheapestStore?.storeName, 'Leclerc');
      expect(comparison.cheapestStore?.lastPrice, 1.10);
    });

    test('storesSortedByPrice trie correctement', () {
      final comparison = StorePriceComparison(
        productId: '1',
        productName: 'Lait',
        storePrices: {
          'Carrefour': StorePriceInfo(
            storeName: 'Carrefour',
            averagePrice: 1.20,
            lastPrice: 1.20,
            lastScanDate: DateTime.now(),
            scanCount: 5,
          ),
          'Leclerc': StorePriceInfo(
            storeName: 'Leclerc',
            averagePrice: 1.10,
            lastPrice: 1.10,
            lastScanDate: DateTime.now(),
            scanCount: 3,
          ),
          'Monoprix': StorePriceInfo(
            storeName: 'Monoprix',
            averagePrice: 1.30,
            lastPrice: 1.30,
            lastScanDate: DateTime.now(),
            scanCount: 2,
          ),
        },
      );
      
      final sorted = comparison.storesSortedByPrice;
      expect(sorted[0].storeName, 'Leclerc');
      expect(sorted[1].storeName, 'Carrefour');
      expect(sorted[2].storeName, 'Monoprix');
    });

    test('Identification du magasin le moins cher - égalité', () {
      final comparison = StorePriceComparison(
        productId: '1',
        productName: 'Lait',
        storePrices: {
          'Carrefour': StorePriceInfo(
            storeName: 'Carrefour',
            averagePrice: 1.10,
            lastPrice: 1.10,
            lastScanDate: DateTime.now(),
            scanCount: 5,
          ),
          'Leclerc': StorePriceInfo(
            storeName: 'Leclerc',
            averagePrice: 1.10,
            lastPrice: 1.10,
            lastScanDate: DateTime.now(),
            scanCount: 3,
          ),
        },
      );
      
      // En cas d'égalité, retourne le premier trouvé (comportement Map)
      expect(comparison.cheapestStore?.lastPrice, 1.10);
      expect(['Carrefour', 'Leclerc'], contains(comparison.cheapestStore?.storeName));
    });

    test('cheapestStore retourne null si pas de magasin', () {
      final comparison = StorePriceComparison(
        productId: '1',
        productName: 'Lait',
        storePrices: {},
      );
      
      expect(comparison.cheapestStore, isNull);
    });
  });

  group('ProductAnalysisResult Tests', () {
    test('Calcul de la tendance globale', () {
      final result = ProductAnalysisResult(
        productId: '1',
        productName: 'Lait',
        priceHistoryByStore: {
          'Carrefour': ProductPriceHistory(
            productId: '1',
            productName: 'Lait',
            storeName: 'Carrefour',
            pricePoints: [
              PricePoint(date: DateTime(2026, 1, 1), price: 1.00, articleId: 'a1'),
              PricePoint(date: DateTime(2026, 6, 1), price: 1.30, articleId: 'a2'),
            ],
          ),
          'Leclerc': ProductPriceHistory(
            productId: '1',
            productName: 'Lait',
            storeName: 'Leclerc',
            pricePoints: [
              PricePoint(date: DateTime(2026, 1, 1), price: 1.00, articleId: 'a1'),
              PricePoint(date: DateTime(2026, 6, 1), price: 1.40, articleId: 'a2'),
            ],
          ),
        },
        storeComparison: StorePriceComparison(
          productId: '1',
          productName: 'Lait',
          storePrices: {},
        ),
      );
      
      // Moyenne des évolutions: (30% + 40%) / 2 = 35% -> up
      expect(result.overallTrend, PriceTrend.up);
    });

    test('Tendance globale stable si une seule évolution stable', () {
      final result = ProductAnalysisResult(
        productId: '1',
        productName: 'Lait',
        priceHistoryByStore: {
          'Carrefour': ProductPriceHistory(
            productId: '1',
            productName: 'Lait',
            storeName: 'Carrefour',
            pricePoints: [
              PricePoint(date: DateTime(2026, 1, 1), price: 1.00, articleId: 'a1'),
              PricePoint(date: DateTime(2026, 6, 1), price: 1.03, articleId: 'a2'),
            ],
          ),
        },
        storeComparison: StorePriceComparison(
          productId: '1',
          productName: 'Lait',
          storePrices: {},
        ),
      );
      
      expect(result.overallTrend, PriceTrend.stable);
    });

    test('Tendance globale stable si pas d\'historique suffisant', () {
      final result = ProductAnalysisResult(
        productId: '1',
        productName: 'Lait',
        priceHistoryByStore: {
          'Carrefour': ProductPriceHistory(
            productId: '1',
            productName: 'Lait',
            storeName: 'Carrefour',
            pricePoints: [
              PricePoint(date: DateTime(2026, 1, 1), price: 1.00, articleId: 'a1'),
            ],
          ),
        },
        storeComparison: StorePriceComparison(
          productId: '1',
          productName: 'Lait',
          storePrices: {},
        ),
      );
      
      expect(result.overallTrend, PriceTrend.stable);
    });
  });

  group('PriceTrendExtension Tests', () {
    test('PriceTrend icons are correct', () {
      expect(PriceTrend.down.icon, Icons.trending_down);
      expect(PriceTrend.stable.icon, Icons.trending_flat);
      expect(PriceTrend.up.icon, Icons.trending_up);
    });

    test('PriceTrend colors are correct', () {
      expect(PriceTrend.down.color, Colors.green);
      expect(PriceTrend.stable.color, Colors.orange);
      expect(PriceTrend.up.color, Colors.red);
    });

    test('PriceTrend labels are correct', () {
      expect(PriceTrend.down.label, 'Baisse');
      expect(PriceTrend.stable.label, 'Stable');
      expect(PriceTrend.up.label, 'Hausse');
    });
  });

  group('PricePoint Tests', () {
    test('fromStoredArticle creates correct PricePoint', () {
      final articleMap = {
        'scanDate': '2026-01-01T00:00:00.000',
        'price': 1.50,
        'quantity': 1.0,
        'unit': 'L',
      };
      
      final pricePoint = PricePoint.fromStoredArticle(articleMap, 'article1');
      
      expect(pricePoint.date, DateTime(2026, 1, 1));
      expect(pricePoint.price, 1.50);
      expect(pricePoint.quantity, 1.0);
      expect(pricePoint.unit, 'L');
      expect(pricePoint.articleId, 'article1');
    });

    test('toMap creates correct map', () {
      final pricePoint = PricePoint(
        date: DateTime(2026, 1, 1),
        price: 1.50,
        quantity: 1.0,
        unit: 'L',
        articleId: 'article1',
      );
      
      final map = pricePoint.toMap();
      
      expect(map['date'], '2026-01-01T00:00:00.000');
      expect(map['price'], 1.50);
      expect(map['quantity'], 1.0);
      expect(map['unit'], 'L');
      expect(map['articleId'], 'article1');
    });
  });
}
