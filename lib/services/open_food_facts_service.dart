import 'dart:convert';
import 'package:http/http.dart' as http;

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
class OpenFoodFactsService {
  static const String _baseUrl = 'https://world.openfoodfacts.org/api/v2/product';

  /// Recherche un produit par son code-barres (EAN)
  /// Retourne un objet [OFFProduct] si trouvé, sinon `null`
  Future<OFFProduct?> lookupBarcode(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return null;

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
          return OFFProduct.fromJson(cleanBarcode, data);
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
  /// Retourne une liste de [OFFProduct]
  Future<List<OFFProduct>> searchByName(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return [];

    try {
      final url = Uri.parse('https://world.openfoodfacts.org/cgi/search.pl?search_terms=${Uri.encodeComponent(cleanName)}&json=1');
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'PrixVif - Flutter Scan App - Version 1.0',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic>? productsJson = data['products'];
        if (productsJson != null) {
          final List<OFFProduct> products = [];
          for (var p in productsJson) {
            final barcode = p['code']?.toString() ?? '';
            if (barcode.isNotEmpty) {
              products.add(OFFProduct.fromJson(barcode, {'product': p}));
            }
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
