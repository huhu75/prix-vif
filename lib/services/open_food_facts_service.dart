import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/hive_models.dart';
import 'scan_repository.dart';

/// Modèle interne pour un produit récupéré d'Open Food Facts
class OFFProduct {
  final String barcode;
  final String name;
  final String brand;
  final String? nutriscore;
  final List<String> categories;
  final String? imageUrl;
  final double? quantity;
  final String? unit;

  OFFProduct({
    required this.barcode,
    required this.name,
    required this.brand,
    this.nutriscore,
    required this.categories,
    this.imageUrl,
    this.quantity,
    this.unit,
  });

  factory OFFProduct.fromJson(String barcode, Map<String, dynamic> json) {
    final p = json['product'] as Map<String, dynamic>? ?? {};

    // Essayer de trouver le nom du produit (français d'abord, puis générique)
    String name = p['product_name_fr'] ?? p['product_name'] ?? 'Produit inconnu';
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

    return OFFProduct(
      barcode: barcode,
      name: name,
      brand: brand,
      nutriscore: nutriscore,
      categories: categories,
      imageUrl: imageUrl,
      quantity: qty,
      unit: unit,
    );
  }
}

/// Service d'interaction avec l'API Open Food Facts
/// Supporte le cache via ScanRepository (étape 3c)
class OpenFoodFactsService {
  static const String _baseUrl = 'https://world.openfoodfacts.org/api/v2/product';

  /// Repository optionnel pour le cache produits
  ScanRepository? _repository;

  /// Injecte le repository pour activer le cache OFF
  void setRepository(ScanRepository repository) {
    _repository = repository;
  }

  /// Recherche un produit par son code-barres (EAN)
  /// Vérifie le cache d'abord si un repository est disponible
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
        );
      }
    }

    try {
      final url = Uri.parse('$_baseUrl/$cleanBarcode');
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'PrixVif - Flutter Scan App - Version 1.0',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final status = data['status'];
        
        // status = 1 signifie produit trouvé dans l'API OFF
        if (status == 1) {
          final product = OFFProduct.fromJson(cleanBarcode, data);

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
            ));
            print('Cache STORE pour EAN: $cleanBarcode');
          }

          return product;
        }
      }
      return null;
    } catch (e) {
      // En cas d'erreur réseau, de timeout ou de décodage
      print('Erreur Open Food Facts API: $e');
      return null;
    }
  }

  /// Recherche des produits par nom sur Open Food Facts
  /// Vérifie d'abord le cache si un repository est disponible
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
          )
        ];
      }
    }

    try {
      final url = Uri.parse(
          'https://world.openfoodfacts.org/cgi/search.pl?search_terms=${Uri.encodeComponent(cleanName)}&json=1&page_size=10');
      final response = await http.get(
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
            final barcode = p['code']?.toString() ?? '';
            if (barcode.isNotEmpty) {
              products.add(OFFProduct.fromJson(barcode, {'product': p}));
            }
          }

          // Étape 4c — Mettre en cache le premier résultat sous la clé 'name:...'
          if (products.isNotEmpty && _repository != null) {
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
            ));
            print('Cache STORE (nom) pour: $cleanName → ${best.name}');
          }

          return products;
        }
      }
      return [];
    } catch (e) {
      print('Erreur Open Food Facts search API: $e');
      return [];
    }
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
