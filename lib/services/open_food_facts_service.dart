import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/hive_models.dart';
import 'scan_repository.dart';

/// Configuration d'un fournisseur Open Facts (Open Food Facts, Open Products Facts, etc.)
class OFFProviderConfig {
  final String name;
  final String productBaseUrl;
  final String searchBaseUrl;

  const OFFProviderConfig({
    required this.name,
    required this.productBaseUrl,
    required this.searchBaseUrl,
  });
}

/// Modèle interne pour un produit récupéré d'Open Food / Products / Beauty Facts
class OFFProduct {
  final String barcode;
  final String name;
  final String brand;
  final String? nutriscore;
  final List<String> categories;
  final String? imageUrl;
  final double? quantity;
  final String? unit;
  final String? ecoscore;
  final int? novaGroup;
  final String? ingredients;
  final List<String> allergens;
  final Map<String, String> nutrientLevels;
  final Map<String, double> nutriments;
  final String source;

  OFFProduct({
    required this.barcode,
    required this.name,
    required this.brand,
    this.nutriscore,
    required this.categories,
    this.imageUrl,
    this.quantity,
    this.unit,
    this.ecoscore,
    this.novaGroup,
    this.ingredients,
    required this.allergens,
    required this.nutrientLevels,
    required this.nutriments,
    this.source = 'Open Food Facts',
  });

  factory OFFProduct.fromJson(String barcode, Map<String, dynamic> json, {String source = 'Open Food Facts'}) {
    final p = json['product'] as Map<String, dynamic>? ?? json;

    // Barcode fallback si absent
    String resolvedBarcode = barcode.trim();
    if (resolvedBarcode.isEmpty) {
      resolvedBarcode = (p['code'] ?? p['_id'] ?? '').toString().trim();
    }

    // Essayer de trouver le nom du produit (français d'abord, puis générique)
    String name = p['product_name_fr'] ?? p['product_name'] ?? p['product_name_en'] ?? p['name'] ?? 'Produit inconnu';
    name = name.trim();
    if (name.isEmpty) name = 'Produit inconnu';

    // Marque
    String brand = p['brands'] ?? p['brand_owner'] ?? 'Marque inconnue';
    brand = brand.trim();
    if (brand.isEmpty) brand = 'Marque inconnue';

    // Nutri-Score (grade en minuscule : a, b, c, d, e)
    String? nutriscore = p['nutriscore_grade']?.toString().toLowerCase().trim();
    if (nutriscore == 'unknown' || nutriscore == 'not-applicable') {
      nutriscore = null;
    }

    // Catégories (on nettoie les préfixes de langue comme 'fr:')
    final List<String> categories = [];
    final List<dynamic>? rawCategories = p['categories_tags'] ?? p['categories_hierarchy'];
    if (rawCategories != null) {
      for (var cat in rawCategories) {
        String catStr = cat.toString();
        if (catStr.contains(':')) {
          catStr = catStr.split(':').last;
        }
        // Capitaliser et remplacer les tirets
        catStr = catStr.replaceAll('-', ' ').trim();
        if (catStr.isNotEmpty) {
          categories.add(catStr[0].toUpperCase() + catStr.substring(1));
        }
      }
    }

    // Image URL
    String? imageUrl = p['image_front_url'] ?? p['image_url'];
    if (imageUrl != null && imageUrl.isEmpty) imageUrl = null;

    // Parser la quantité (ex: "400 g", "1.5 L")
    double? qty;
    String? unit;
    final String? rawQty = p['quantity']?.toString().trim();
    if (rawQty != null && rawQty.isNotEmpty) {
      final regExp = RegExp(r'^([\d.,]+)\s*([a-zA-Z%]+)$');
      final match = regExp.firstMatch(rawQty);
      if (match != null) {
        qty = double.tryParse(match.group(1)!.replaceAll(',', '.'));
        unit = match.group(2);
      } else {
        // Fallback simple si pas d'espace ou format différent
        unit = rawQty;
      }
    }

    // Eco-Score
    String? ecoscore = p['ecoscore_grade']?.toString().toLowerCase().trim();
    if (ecoscore == 'unknown' || ecoscore == 'not-applicable') {
      ecoscore = null;
    }

    // Groupe Nova
    int? novaGroup = int.tryParse(p['nova_group']?.toString() ?? '');

    // Ingrédients
    String? ingredients = p['ingredients_text_fr'] ?? p['ingredients_text'];
    if (ingredients != null && ingredients.isEmpty) ingredients = null;

    // Allergènes
    final List<String> allergens = [];
    final List<dynamic>? rawAllergens = p['allergens_tags'] ?? p['allergens_hierarchy'];
    if (rawAllergens != null) {
      for (var alg in rawAllergens) {
        String algStr = alg.toString();
        if (algStr.contains(':')) {
          algStr = algStr.split(':').last;
        }
        algStr = algStr.replaceAll('-', ' ').trim();
        if (algStr.isNotEmpty) {
          allergens.add(algStr[0].toUpperCase() + algStr.substring(1));
        }
      }
    }

    // Niveaux de nutriments
    final Map<String, String> nutrientLevels = {};
    final rawLevels = p['nutrient_levels'] as Map<dynamic, dynamic>?;
    if (rawLevels != null) {
      rawLevels.forEach((key, value) {
        nutrientLevels[key.toString()] = value.toString();
      });
    }

    // Nutriments détaillés pour 100g
    final Map<String, double> nutriments = {};
    final rawNutriments = p['nutriments'] as Map<dynamic, dynamic>?;
    if (rawNutriments != null) {
      rawNutriments.forEach((key, value) {
        if (value is num) {
          nutriments[key.toString()] = value.toDouble();
        }
      });
    }

    return OFFProduct(
      barcode: resolvedBarcode,
      name: name,
      brand: brand,
      nutriscore: nutriscore,
      categories: categories,
      imageUrl: imageUrl,
      quantity: qty,
      unit: unit,
      ecoscore: ecoscore,
      novaGroup: novaGroup,
      ingredients: ingredients,
      allergens: allergens,
      nutrientLevels: nutrientLevels,
      nutriments: nutriments,
      source: source,
    );
  }
}

/// Service d'interaction avec les APIs Open Food Facts et fallback
/// (Open Products Facts et Open Beauty Facts pour les produits non-alimentaires).
/// Supporte le cache via ScanRepository (étape 3c)
class OpenFoodFactsService {
  /// Fournisseurs interrogés dans l'ordre de priorité (fallback automatique)
  static const List<OFFProviderConfig> defaultProviders = [
    OFFProviderConfig(
      name: 'Open Food Facts',
      productBaseUrl: 'https://world.openfoodfacts.org/api/v2/product',
      searchBaseUrl: 'https://world.openfoodfacts.org/cgi/search.pl',
    ),
    OFFProviderConfig(
      name: 'Open Products Facts',
      productBaseUrl: 'https://world.openproductsfacts.org/api/v2/product',
      searchBaseUrl: 'https://world.openproductsfacts.org/cgi/search.pl',
    ),
    OFFProviderConfig(
      name: 'Open Beauty Facts',
      productBaseUrl: 'https://world.openbeautyfacts.org/api/v2/product',
      searchBaseUrl: 'https://world.openbeautyfacts.org/cgi/search.pl',
    ),
  ];

  final http.Client _client;
  final List<OFFProviderConfig> providers;

  /// Repository optionnel pour le cache produits
  ScanRepository? _repository;

  OpenFoodFactsService({
    http.Client? httpClient,
    List<OFFProviderConfig>? providers,
  })  : _client = httpClient ?? http.Client(),
        providers = providers ?? defaultProviders;

  /// Injecte le repository pour activer le cache OFF
  void setRepository(ScanRepository repository) {
    _repository = repository;
  }

  /// Recherche un produit par son code-barres (EAN)
  /// Vérifie le cache d'abord si un repository est disponible.
  /// Si Open Food Facts ne trouve rien (status == 0), bascule automatiquement
  /// sur Open Products Facts puis Open Beauty Facts.
  /// Retourne un objet [OFFProduct] si trouvé, sinon `null`
  Future<OFFProduct?> lookupBarcode(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return null;

    // Étape 3c — Vérifier le cache avant l'appel réseau
    if (_repository != null) {
      final cached = _repository!.getCachedProduct(cleanBarcode);
      if (cached != null) {
        print('Cache HIT pour EAN: $cleanBarcode');
        return OFFProduct(
          barcode: cached.ean,
          name: cached.productName,
          brand: cached.brands ?? 'Marque inconnue',
          nutriscore: cached.nutriscoreGrade,
          categories: cached.categories ?? [],
          imageUrl: cached.imageUrl,
          ecoscore: cached.ecoscoreGrade,
          novaGroup: cached.novaGroup,
          ingredients: cached.ingredients,
          allergens: cached.allergens ?? [],
          nutrientLevels: cached.nutrientLevels ?? {},
          nutriments: cached.nutriments ?? {},
          source: 'Cache',
        );
      }
    }

    // Essayer successivement chaque fournisseur configuré (OFF -> OPF -> OBF)
    for (final provider in providers) {
      try {
        final url = Uri.parse('${provider.productBaseUrl}/$cleanBarcode');
        final response = await _client.get(
          url,
          headers: {
            'User-Agent': 'PrixVif - Flutter Scan App - Version 1.0',
          },
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          final status = data['status'];

          // status = 1 signifie produit trouvé
          if (status == 1 && data['product'] != null) {
            final product = OFFProduct.fromJson(cleanBarcode, data, source: provider.name);

            // Mettre en cache le produit trouvé
            if (_repository != null) {
              await _repository!.cacheProduct(CachedProduct(
                ean: product.barcode,
                productName: product.name,
                brands: product.brand,
                nutriscoreGrade: product.nutriscore,
                imageUrl: product.imageUrl,
                categories: product.categories,
                cachedAt: DateTime.now(),
                ecoscoreGrade: product.ecoscore,
                novaGroup: product.novaGroup,
                ingredients: product.ingredients,
                allergens: product.allergens,
                nutrientLevels: product.nutrientLevels,
                nutriments: product.nutriments,
              ));
              print('Cache STORE pour EAN: $cleanBarcode (source: ${provider.name})');
            }

            return product;
          }
        }
      } catch (e) {
        // En cas d'erreur réseau ou timeout avec ce fournisseur, essayer le suivant
        print('Erreur ${provider.name} lookup API: $e');
      }
    }

    return null;
  }

  /// Recherche des produits par nom (avec fallback sur Open Products Facts et Open Beauty Facts)
  /// Vérifie d'abord le cache si un repository est disponible.
  /// Retourne une liste de [OFFProduct]
  Future<List<OFFProduct>> searchByName(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return [];

    // Étape 4c — Vérifier le cache avant l'appel réseau (clé = nom normalisé)
    if (_repository != null) {
      final cacheKey = 'name:${cleanName.toLowerCase()}';
      final cached = _repository!.getCachedProduct(cacheKey);
      if (cached != null) {
        print('Cache HIT (nom) pour: $cleanName');
        return [
          OFFProduct(
            barcode: cached.ean,
            name: cached.productName,
            brand: cached.brands ?? 'Marque inconnue',
            nutriscore: cached.nutriscoreGrade,
            categories: cached.categories ?? [],
            imageUrl: cached.imageUrl,
            ecoscore: cached.ecoscoreGrade,
            novaGroup: cached.novaGroup,
            ingredients: cached.ingredients,
            allergens: cached.allergens ?? [],
            nutrientLevels: cached.nutrientLevels ?? {},
            nutriments: cached.nutriments ?? {},
            source: 'Cache',
          )
        ];
      }
    }

    // Essayer successivement chaque fournisseur configuré (OFF -> OPF -> OBF)
    for (final provider in providers) {
      try {
        final url = Uri.parse(
          '${provider.searchBaseUrl}?search_terms=${Uri.encodeComponent(cleanName)}&json=1&page_size=10',
        );
        final response = await _client.get(
          url,
          headers: {
            'User-Agent': 'PrixVif - Flutter Scan App - Version 1.0',
          },
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          final List<dynamic>? productsJson = data['products'];
          if (productsJson != null && productsJson.isNotEmpty) {
            final List<OFFProduct> products = [];
            for (var p in productsJson) {
              final barcode = (p['code'] ?? p['_id'])?.toString() ?? '';
              if (barcode.isNotEmpty) {
                products.add(OFFProduct.fromJson(barcode, {'product': p}, source: provider.name));
              }
            }

            if (products.isNotEmpty) {
              // Étape 4c — Mettre en cache le premier résultat sous la clé 'name:...'
              if (_repository != null) {
                final best = products.first;
                final cacheKey = 'name:${cleanName.toLowerCase()}';
                await _repository!.cacheProduct(CachedProduct(
                  ean: cacheKey,
                  productName: best.name,
                  brands: best.brand,
                  nutriscoreGrade: best.nutriscore,
                  imageUrl: best.imageUrl,
                  categories: best.categories,
                  cachedAt: DateTime.now(),
                  ecoscoreGrade: best.ecoscore,
                  novaGroup: best.novaGroup,
                  ingredients: best.ingredients,
                  allergens: best.allergens,
                  nutrientLevels: best.nutrientLevels,
                  nutriments: best.nutriments,
                ));
                print('Cache STORE (nom) pour: $cleanName → ${best.name} (source: ${provider.name})');
              }

              return products;
            }
          }
        }
      } catch (e) {
        print('Erreur ${provider.name} search API: $e');
      }
    }

    return [];
  }

  /// Stratégie de recherche en deux passes :
  /// 1. Nom complet → premier résultat si pertinent
  /// 2. Si vide : nom nettoyé des mots génériques → réessayer
  /// Retourne la liste des candidats (peut être vide)
  Future<List<OFFProduct>> searchByNameWithTwoPasses(String rawName) async {
    // Première passe : nom complet
    List<OFFProduct> candidates = await searchByName(rawName);

    // Deuxième passe : nom nettoyé si pas de résultats
    if (candidates.isEmpty) {
      final cleaned = cleanProductName(rawName);
      if (cleaned.isNotEmpty && cleaned != rawName.toLowerCase().trim()) {
        print('OFF search — 2ème passe avec nom nettoyé: "$cleaned"');
        candidates = await searchByName(cleaned);
      }
    }

    return candidates;
  }

  /// Recherche libre : un code-barres (8 à 14 chiffres) est cherché tel quel,
  /// tout autre texte est cherché par nom (deux passes)
  Future<List<OFFProduct>> searchProducts(String query) async {
    final text = query.trim();
    if (text.isEmpty) return [];
    if (RegExp(r'^\d{8,14}$').hasMatch(text)) {
      final product = await lookupBarcode(text);
      return product == null ? [] : [product];
    }
    return searchByNameWithTwoPasses(text);
  }

  /// Nettoie un nom de produit en retirant les mots génériques courants sur les tickets
  String cleanProductName(String name) {
    var cleaned = name.toLowerCase();
    
    // Retirer les unités de poids/volume : g, kg, l, ml, cl, x2, %, etc.
    final weightRegExp = RegExp(r'\b\d+(?:\s*(?:g|kg|l|ml|cl|x|%|pcs|pieces))\b', caseSensitive: false);
    cleaned = cleaned.replaceAll(weightRegExp, '');
    
    // Retirer les termes génériques courants sur les tickets de caisse
    final genericTerms = [
      'bio', 'promo', 'art', 'lot', 'offert', 'remise', 'reduc', 'solde',
      'pack', 'bte', 'bt', 'x', 'le', 'la', 'les', 'de', 'du', 'en'
    ];
    for (var term in genericTerms) {
      cleaned = cleaned.replaceAll(RegExp('\\b$term\\b', caseSensitive: false), '');
    }
    
    // Nettoyer les espaces superflus et ponctuation
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\sàâäéèêëïîôöùûüç]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }
}
