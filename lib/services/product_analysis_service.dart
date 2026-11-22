import '../analytics/analytics.dart';
import '../models/hive_models.dart';
import '../models/product_analysis_models.dart';
import '../models/product_category.dart';
import 'category_service.dart';
import 'open_food_facts_service.dart';
import 'scan_repository.dart';

/// Données affichées par la fiche produit
class ProductAnalysisData {
  final ProductAnalysisResult analysis;

  /// Fiche Open Food Facts (en ligne, en cache, ou reconstituée depuis l'article local)
  final OFFProduct? offProduct;

  /// Clé produit (voir [productKeyOf]) : sert à enregistrer sa catégorie
  final String productKey;

  /// Catégorie du produit, `null` si elle est inconnue
  final ProductCategory? category;

  /// Tous les produits de sa catégorie (toutes marques, tous magasins)
  final CategoryGroup? categoryGroup;

  /// Conseil d'achat dans chaque magasin où le produit a été vu (dernier prix)
  final Map<String, PriceAdvice> adviceByStore;

  const ProductAnalysisData({
    required this.analysis,
    this.offProduct,
    this.productKey = '',
    this.category,
    this.categoryGroup,
    this.adviceByStore = const {},
  });
}

/// Rassemble tout ce que la fiche produit affiche : historique des prix par
/// magasin, comparaison entre magasins, produits similaires et fiche OFF.
class ProductAnalysisService {
  final ScanRepository repository;

  /// Recherche OFF par code-barres ; remplaçable dans les tests (pas de réseau)
  final Future<OFFProduct?> Function(String barcode) lookupBarcode;

  /// Enregistre la catégorie OFF d'un produit qui n'en a pas encore
  final CategoryService categoryService;

  ProductAnalysisService(
    this.repository, {
    Future<OFFProduct?> Function(String barcode)? lookupBarcode,
    CategoryService? categoryService,
  })  : lookupBarcode = lookupBarcode ??
            ((barcode) => (OpenFoodFactsService()..setRepository(repository)).lookupBarcode(barcode)),
        categoryService = categoryService ?? CategoryService(repository);

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

    // Catégorie : connue, sinon celle de la fiche OFF (enregistrée pour la suite)
    final productKey = productKeyFor(
      barcode: reference?.barcode ?? barcode,
      name: reference?.name ?? productName,
      brand: reference?.brand,
    );
    var category = repository.getProductCategory(productKey);
    if (category == null && barcode != null && offProduct?.categoryId != null) {
      try {
        category = await categoryService.applyFromProduct(barcode, offProduct!).timeout(const Duration(seconds: 4));
      } catch (_) {
        // Taxonomie indisponible : la catégorie sera complétée plus tard
      }
    }

    // Catégorie et conseils d'achat à partir de tous les prix relevés
    final sessions = await repository.getAllScans();
    final categories = {
      ...repository.getAllProductCategories(),
      productKey: ?category,
    };
    final adviceByStore = {
      for (final store in analysis.storeComparison.storePrices.keys)
        store: PriceAdvice.calculate(
          sessions: sessions,
          categories: categories,
          productKey: productKey,
          store: store,
        ),
    };

    return ProductAnalysisData(
      analysis: analysis,
      offProduct: offProduct,
      productKey: productKey,
      category: category,
      categoryGroup: category == null ? null : CategoryGroup.forCategory(category.id, sessions, categories),
      adviceByStore: adviceByStore,
    );
  }
}
