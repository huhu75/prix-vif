import '../models.dart';
import '../utils/product_type_utils.dart';
import '../utils/unit_price.dart';
import 'product_observation.dart';

/// Profil d'un produit : identité, catégories et dernier prix connu par magasin
class _ProductProfile {
  final String key;
  final String productId;
  final String name;
  final String? brand;
  final String? barcode;
  final String? imageUrl;
  final List<String>? categories;
  final Map<String, ProductObservation> storePrices;

  _ProductProfile(List<ProductObservation> observations)
      : key = observations.first.key,
        productId = observations.first.productId,
        name = observations.first.item.name,
        brand = observations.first.item.brand,
        barcode = observations.first.item.barcode,
        imageUrl = observations.first.item.imageUrl,
        categories = observations
            .map((o) => o.item.categories)
            .firstWhere((c) => c != null, orElse: () => null),
        storePrices = latestByStore(observations);
}

/// Recommandation d'un produit équivalent moins cher pour le tableau de bord
class ProductRecommendationItem {
  final String referenceProductId;
  final String referenceProductName;
  final String? referenceBrand;
  final String? referenceBarcode;
  final String? referenceImageUrl;
  final String? referenceStore;
  final double referencePrice;

  final String alternativeProductId;
  final String alternativeProductName;
  final String? alternativeBrand;
  final String? alternativeBarcode;
  final String? alternativeImageUrl;
  final String? alternativeStore;
  final double alternativePrice;

  /// Prix au kg / L / unité des deux produits quand leurs contenances sont connues :
  /// la comparaison se fait alors à quantité égale.
  final UnitPrice? referenceUnitPrice;
  final UnitPrice? alternativeUnitPrice;

  final String category;

  ProductRecommendationItem({
    required this.referenceProductId,
    required this.referenceProductName,
    this.referenceBrand,
    this.referenceBarcode,
    this.referenceImageUrl,
    this.referenceStore,
    required this.referencePrice,
    required this.alternativeProductId,
    required this.alternativeProductName,
    this.alternativeBrand,
    this.alternativeBarcode,
    this.alternativeImageUrl,
    this.alternativeStore,
    required this.alternativePrice,
    this.referenceUnitPrice,
    this.alternativeUnitPrice,
    required this.category,
  });

  /// Comparaison faite au kg / L / unité (et non par article)
  bool get comparesByUnit => referenceUnitPrice != null && alternativeUnitPrice != null;

  /// Montant économisé en euros, pour la même quantité que le produit de référence
  double get savingAmount {
    if (comparesByUnit) {
      return referencePrice * (1 - alternativeUnitPrice!.value / referenceUnitPrice!.value);
    }
    return referencePrice - alternativePrice;
  }

  /// Pourcentage d'économie
  double get savingPercent {
    if (referencePrice <= 0) return 0.0;
    return (savingAmount / referencePrice) * 100;
  }

  /// Économie d'une observation A remplacée par B, ou `null` si les deux ne sont pas comparables.
  /// Contenances connues des deux côtés et de même nature : comparaison au kg / L / unité.
  /// Contenances inconnues des deux côtés : comparaison par article.
  /// Sinon (une seule connue, ou kg contre L) : pas de comparaison possible.
  static double? _saving(ProductObservation a, ProductObservation b) {
    final unitA = a.unitPrice;
    final unitB = b.unitPrice;
    if (unitA != null && unitB != null) {
      if (unitA.unit != unitB.unit) return null;
      return a.price * (1 - unitB.value / unitA.value);
    }
    if (unitA == null && unitB == null) return a.price - b.price;
    return null;
  }

  /// Indique s'il y a un gain financier notable (> 1 centime)
  bool get hasSaving => savingAmount > 0.01;

  static const _stopWords = {
    'le', 'la', 'les', 'de', 'du', 'des', 'au', 'aux', 'd', 'l', 'un', 'une', 'uht', 'bio',
    'en', 'et', 'a', 'sur', 'pour', 'pur', 'pure', '100%'
  };

  static String? _firstSignificantWord(String name) {
    final cleaned = name
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w\sàâäéèêëîïôöùûüç]"), ' ');
    final parts = cleaned.split(RegExp(r'\s+'));
    for (final part in parts) {
      final p = part.trim();
      if (p.length >= 3 && !_stopWords.contains(p)) {
        return p;
      }
    }
    return null;
  }

  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  static String? _checkEquivalence(_ProductProfile a, _ProductProfile b) {
    // 1. Si les deux produits disposent de catégories OFF
    if (isCategorized(a.categories) && isCategorized(b.categories)) {
      final typeA = productTypeOf(a.categories);
      final typeB = productTypeOf(b.categories);
      if (typeA != null && typeA == typeB) {
        return typeA;
      }
      // Intersection sur les catégories
      if (a.categories != null && b.categories != null) {
        for (final cat in a.categories!) {
          final trimmed = cat.trim();
          if (trimmed.isNotEmpty &&
              b.categories!.any((c) => c.trim().toLowerCase() == trimmed.toLowerCase())) {
            return productTypeLabel(a.categories);
          }
        }
      }
    } else if (isCategorized(a.categories) || isCategorized(b.categories)) {
      final type = productTypeOf(a.categories) ?? productTypeOf(b.categories);
      final wordA = _firstSignificantWord(a.name);
      final wordB = _firstSignificantWord(b.name);
      if (wordA != null && wordA == wordB) {
        return type ?? _capitalize(wordA);
      }
    }

    // 2. Fallback par mot-clé principal de nom
    final wordA = _firstSignificantWord(a.name);
    final wordB = _firstSignificantWord(b.name);
    if (wordA != null && wordA.length >= 3 && wordA == wordB) {
      return _capitalize(wordA);
    }

    return null;
  }

  /// Calcule les recommandations de produits équivalents moins chers depuis les sessions
  static List<ProductRecommendationItem> calculate(List<ScanSession> sessions) {
    final products = groupByProduct(ProductObservation.fromSessions(sessions))
        .values
        .map(_ProductProfile.new)
        .toList();
    if (products.length < 2) return [];

    final recommendations = <ProductRecommendationItem>[];

    // Pour chaque produit A (produit acheté/scanné), chercher la meilleure alternative B moins chère dans un autre magasin
    for (final prodA in products) {
      if (prodA.storePrices.isEmpty) continue;
      ProductRecommendationItem? bestForA;

      for (final prodB in products) {
        if (prodA.key == prodB.key) continue;
        if (prodA.barcode != null && prodB.barcode != null && prodA.barcode == prodB.barcode) {
          continue;
        }
        if (prodB.storePrices.isEmpty) continue;

        final categoryMatch = _checkEquivalence(prodA, prodB);
        if (categoryMatch == null) continue;

        for (final storeAEntry in prodA.storePrices.entries) {
          final storeA = storeAEntry.key;
          final obsA = storeAEntry.value;

          for (final storeBEntry in prodB.storePrices.entries) {
            final storeB = storeBEntry.key;
            final obsB = storeBEntry.value;

            // Doit obligatoirement être dans un magasin différent
            if (storeA == storeB) continue;

            final diff = _saving(obsA, obsB);
            if (diff != null && diff > 0.01 && (bestForA == null || diff > bestForA.savingAmount)) {
              bestForA = ProductRecommendationItem(
                referenceProductId: prodA.productId,
                referenceProductName: prodA.name,
                referenceBrand: prodA.brand,
                referenceBarcode: prodA.barcode,
                referenceImageUrl: prodA.imageUrl,
                referenceStore: storeA,
                referencePrice: obsA.price,
                referenceUnitPrice: obsA.unitPrice,
                alternativeProductId: prodB.productId,
                alternativeProductName: prodB.name,
                alternativeBrand: prodB.brand,
                alternativeBarcode: prodB.barcode,
                alternativeImageUrl: prodB.imageUrl,
                alternativeStore: storeB,
                alternativePrice: obsB.price,
                alternativeUnitPrice: obsB.unitPrice,
                category: categoryMatch,
              );
            }
          }
        }
      }

      if (bestForA != null) {
        recommendations.add(bestForA);
      }
    }

    // Trier par montant d'économie décroissant
    recommendations.sort((a, b) => b.savingAmount.compareTo(a.savingAmount));

    return recommendations;
  }
}
