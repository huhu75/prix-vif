import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/product_category.dart';
import 'open_food_facts_service.dart';
import 'scan_repository.dart';

/// Attribue une catégorie aux produits scannés à partir d'Open Food Facts
/// (`compared_to_category`) et traduit son identifiant en français.
class CategoryService {
  final ScanRepository repository;
  final http.Client _client;
  final List<OFFProviderConfig> providers;
  bool _filling = false;

  CategoryService(this.repository, {http.Client? httpClient, List<OFFProviderConfig>? providers})
      : _client = httpClient ?? http.Client(),
        providers = providers ?? OpenFoodFactsService.defaultProviders;

  static const Map<String, String> _headers = {'User-Agent': 'PrixVif - Flutter Scan App - Version 1.0'};
  static const String _offHost = 'world.openfoodfacts.org';

  /// Nom français d'une catégorie (« en:apple-juices » → « Jus de pomme »),
  /// demandé à la taxonomie du fournisseur [host] puis d'Open Food Facts et
  /// mémorisé. Sans réponse, un libellé tiré de l'identifiant (non mémorisé,
  /// pour réessayer plus tard).
  Future<String> labelFor(String categoryId, {String? host}) async {
    final cached = repository.getCategoryLabel(categoryId);
    if (cached != null) return cached;
    if (categoryId.startsWith('perso:')) return humanizeCategoryId(categoryId);

    for (final h in {host ?? _offHost, _offHost}) {
      try {
        final url = Uri.https(h, '/api/v2/taxonomy', {
          'tagtype': 'categories',
          'tags': categoryId,
          'lc': 'fr',
          'fields': 'name',
        });
        final response = await _client.get(url, headers: _headers).timeout(const Duration(seconds: 6));
        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body);
        final entry = data is Map ? data[categoryId] : null;
        final names = entry is Map ? entry['name'] : null;
        final label = names is Map ? (names['fr'] ?? names['en']) : null;
        if (label is String && label.trim().isNotEmpty) {
          await repository.saveCategoryLabel(categoryId, label.trim());
          return label.trim();
        }
      } catch (_) {
        // Réseau indisponible ou réponse illisible : essayer l'hôte suivant
      }
    }
    return humanizeCategoryId(categoryId);
  }

  /// Enregistre la catégorie d'un produit trouvé au scan, si Open Food Facts en
  /// donne une (une catégorie choisie à la main est conservée).
  Future<ProductCategory?> applyFromProduct(String barcode, OFFProduct product) async {
    final key = 'bc_${barcode.trim()}';
    final existing = repository.getProductCategory(key);
    final id = product.categoryId;
    if (id == null || (existing != null && (existing.manual || existing.id == id))) return existing;
    final category = ProductCategory(id: id, label: await labelFor(id, host: _hostForSource(product.source)));
    await repository.setProductCategory(key, category);
    return category;
  }

  /// Cherche la catégorie des produits scannés qui n'en ont pas encore (au
  /// plus [max] produits par appel). Retourne le nombre de catégories trouvées.
  Future<int> fillMissing({int max = 40}) async {
    if (_filling) return 0;
    _filling = true;
    var found = 0;
    try {
      await repository.ready;
      for (final barcode in repository.barcodesMissingCategory().take(max)) {
        final result = await _fetchCategoryId(barcode);
        if (result == null) break; // aucun fournisseur ne répond : réessayer plus tard
        final key = 'bc_$barcode';
        final id = result.id;
        if (id == null) {
          await repository.markCategoryUnavailable(key);
          continue;
        }
        await repository.setProductCategory(key, ProductCategory(id: id, label: await labelFor(id, host: result.host)));
        found += 1;
      }
    } finally {
      _filling = false;
    }
    return found;
  }

  String? _hostForSource(String source) {
    for (final provider in providers) {
      if (provider.name == source) return Uri.parse(provider.productBaseUrl).host;
    }
    return null;
  }

  /// Catégorie d'un code-barres et hôte du fournisseur qui la donne. `id` vaut
  /// `null` si aucun fournisseur ne la connaît ; le résultat vaut `null` si
  /// aucun fournisseur n'a répondu (hors-ligne).
  Future<({String? id, String? host})?> _fetchCategoryId(String barcode) async {
    var answered = false;
    for (final provider in providers) {
      try {
        final url = Uri.parse('${provider.productBaseUrl}/$barcode?fields=compared_to_category,categories_tags');
        final response = await _client.get(url, headers: _headers).timeout(const Duration(seconds: 8));
        // 404 : produit inconnu de ce fournisseur, essayer le suivant
        if (response.statusCode == 404) {
          answered = true;
          continue;
        }
        if (response.statusCode != 200) continue;
        answered = true;
        final data = jsonDecode(response.body);
        if (data is Map && data['status'] == 1 && data['product'] is Map) {
          final id = OFFProduct.comparedCategoryOf(Map<String, dynamic>.from(data['product'] as Map));
          // Produit trouvé : sa catégorie (ou son absence) fait foi
          return (id: id, host: id == null ? null : Uri.parse(provider.productBaseUrl).host);
        }
      } catch (_) {
        // Erreur réseau avec ce fournisseur : essayer le suivant
      }
    }
    return answered ? (id: null, host: null) : null;
  }
}
