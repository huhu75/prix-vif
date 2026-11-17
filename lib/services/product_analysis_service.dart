import '../models/hive_models.dart';
import '../models/product_analysis_models.dart';
import 'open_food_facts_service.dart';
import 'scan_repository.dart';

/// Données affichées par la fiche produit
class ProductAnalysisData {
  final ProductAnalysisResult analysis;

  /// Fiche Open Food Facts (en ligne, en cache, ou reconstituée depuis l'article local)
  final OFFProduct? offProduct;

  const ProductAnalysisData({required this.analysis, this.offProduct});
}

/// Rassemble tout ce que la fiche produit affiche : historique des prix par
/// magasin, comparaison entre magasins, produits similaires et fiche OFF.
class ProductAnalysisService {
  final ScanRepository repository;

  /// Recherche OFF par code-barres ; remplaçable dans les tests (pas de réseau)
  final Future<OFFProduct?> Function(String barcode) lookupBarcode;

  ProductAnalysisService(this.repository, {Future<OFFProduct?> Function(String barcode)? lookupBarcode})
      : lookupBarcode = lookupBarcode ??
            ((barcode) => (OpenFoodFactsService()..setRepository(repository)).lookupBarcode(barcode));

  /// Article de référence : même id, même code-barres ou même nom
  StoredArticle? _findReference(String productId, String productName) {
    for (final article in repository.getAllStoredArticles()) {
      if (article.id == productId || article.barcode == productId || article.name == productName) {
        return article;
      }
    }
    return null;
  }

  /// Analyse locale du produit (sans réseau)
  ProductAnalysisResult buildAnalysis(String productId, String productName) {
    final historyByStore = repository.getPriceHistoryByStore(productId);
    final reference = _findReference(productId, productName);

    // Historique par magasin
    final priceHistoryByStore = <String, ProductPriceHistory>{};
    for (final entry in historyByStore.entries) {
      priceHistoryByStore[entry.key] = ProductPriceHistory(
        productId: productId,
        productName: productName,
        barcode: reference?.barcode,
        brand: reference?.brand,
        storeName: entry.key,
        pricePoints: entry.value
            .map((raw) => PricePoint(
                  date: DateTime.parse(raw['date'] as String),
                  price: (raw['price'] as num).toDouble(),
                  quantity: (raw['quantity'] as num?)?.toDouble(),
                  unit: raw['unit'] as String?,
                  articleId: raw['id'] as String,
                ))
            .toList(),
      );
    }

    // Comparaison entre magasins
    final storePrices = <String, StorePriceInfo>{};
    for (final entry in historyByStore.entries) {
      final rawPoints = entry.value;
      if (rawPoints.isEmpty) continue;
      final prices = rawPoints.map((p) => (p['price'] as num).toDouble()).toList();
      storePrices[entry.key] = StorePriceInfo(
        storeName: entry.key,
        averagePrice: prices.reduce((a, b) => a + b) / prices.length,
        lastPrice: prices.last,
        lastScanDate: DateTime.parse(rawPoints.last['date'] as String),
        scanCount: rawPoints.length,
        barcode: reference?.barcode,
      );
    }

    // Produits similaires
    SimilarProductsComparison? similarProducts;
    if (reference != null) {
      final category = reference.categories?.isNotEmpty == true ? reference.categories!.first : null;
      final similarList = repository
          .getSimilarProducts(productId, category: category)
          .map((raw) => SimilarProductInfo(
                productId: raw['id'] as String,
                productName: raw['name'] as String,
                brand: raw['brand'] as String?,
                barcode: raw['barcode'] as String?,
                storeName: raw['storeName'] as String?,
                price: (raw['price'] as num).toDouble(),
                quantity: (raw['quantity'] as num?)?.toDouble(),
                unit: raw['unit'] as String?,
                scanDate: raw['scanDate'] as DateTime,
                nutriscore: raw['nutriscore'] as String?,
                imageUrl: raw['imageUrl'] as String?,
                categories: (raw['categories'] as List<dynamic>?)?.cast<String>(),
              ))
          .toList();
      if (similarList.isNotEmpty) {
        similarProducts = SimilarProductsComparison(
          category: category ?? 'Produits similaires',
          referenceProductId: productId,
          similarProducts: similarList,
        );
      }
    }

    return ProductAnalysisResult(
      productId: productId,
      productName: productName,
      barcode: reference?.barcode,
      brand: reference?.brand,
      imageUrl: reference?.imageUrl,
      nutriscore: reference?.nutriscore,
      categories: reference?.categories,
      priceHistoryByStore: priceHistoryByStore,
      storeComparison: StorePriceComparison(
        productId: productId,
        productName: productName,
        barcode: reference?.barcode,
        brand: reference?.brand,
        storePrices: storePrices,
      ),
      similarProducts: similarProducts,
    );
  }

  /// Analyse complète : analyse locale + fiche Open Food Facts
  Future<ProductAnalysisData> load(String productId, String productName) async {
    final analysis = buildAnalysis(productId, productName);
    final reference = _findReference(productId, productName);

    OFFProduct? offProduct;
    final barcode = reference?.barcode ?? (RegExp(r'^\d+$').hasMatch(productId) ? productId : null);
    if (barcode != null && barcode.isNotEmpty) {
      offProduct = await lookupBarcode(barcode);
    }

    // Hors-ligne ou produit inconnu d'OFF : fiche reconstituée depuis l'article enregistré
    if (offProduct == null && reference != null) {
      offProduct = OFFProduct(
        barcode: reference.barcode ?? '',
        name: reference.name,
        brand: reference.brand ?? 'Marque inconnue',
        nutriscore: reference.nutriscore,
        categories: reference.categories ?? [],
        imageUrl: reference.imageUrl,
        allergens: [],
        nutrientLevels: {},
        nutriments: {},
      );
    }

    return ProductAnalysisData(analysis: analysis, offProduct: offProduct);
  }
}
