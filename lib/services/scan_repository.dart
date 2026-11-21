import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import '../models.dart';
import '../models/hive_models.dart';
import '../utils/unit_price.dart';

// ===================================================
// Étape 3c — Couche Repository
// ===================================================
// ScanRepository : interface unique pour toutes les
// opérations de persistance (CRUD scans, articles, cache OFF)
// ===================================================

class ScanRepository {
  static const String _scansBoxName = 'scans';
  static const String _articlesBoxName = 'articles';
  static const String _productsBoxName = 'products_cache';
  static const String _mistralExtractionsBoxName = 'mistral_extractions';
  static const String _pendingOfflineScansBoxName = 'pending_offline_scans';
  static const String _settingsBoxName = 'settings';

  late Box<Map> _scansBox;
  late Box<Map> _articlesBox;
  late Box<Map> _productsBox;
  late Box<Map> _mistralExtractionsBox;
  late Box<Map> _pendingOfflineScansBox;
  late Box<Map> _settingsBox;

  bool _isInitialized = false;
  final Completer<void> _ready = Completer<void>();

  /// Se termine quand [init] a ouvert toutes les boxes
  Future<void> get ready => _ready.future;

  /// Initialise Hive et ouvre les boxes
  Future<void> init() async {
    if (_isInitialized) return;

    _scansBox = await Hive.openBox<Map>(_scansBoxName);
    _articlesBox = await Hive.openBox<Map>(_articlesBoxName);
    _productsBox = await Hive.openBox<Map>(_productsBoxName);
    _mistralExtractionsBox = await Hive.openBox<Map>(_mistralExtractionsBoxName);
    _pendingOfflineScansBox = await Hive.openBox<Map>(_pendingOfflineScansBoxName);
    _settingsBox = await Hive.openBox<Map>(_settingsBoxName);

    _isInitialized = true;

    // Réparer les sessions vidées par l'ancien comportement de « Enregistrer »
    await _purgeEmptyScans();

    if (!_ready.isCompleted) _ready.complete();
  }

  // ==========================================
  // Données de démo
  // ==========================================

  static const String _demoSeededKey = 'demo_seeded';

  /// Indique si les sessions de démo ont déjà été proposées une fois
  bool get isDemoSeeded => _settingsBox.get(_demoSeededKey)?['value'] == true;

  /// Mémorise que les sessions de démo ont été proposées (ne plus jamais les réinjecter)
  Future<void> markDemoSeeded() async {
    await _settingsBox.put(_demoSeededKey, {'value': true});
  }

  /// Indique si des sessions de démo sont encore présentes
  bool get hasDemoData => ScanSession.demoSessionIds.any(_scansBox.containsKey);

  /// Supprime uniquement les sessions de démo (et leurs articles).
  /// Retourne le nombre de sessions supprimées.
  Future<int> removeDemoData() async {
    var removed = 0;
    for (final scanId in ScanSession.demoSessionIds) {
      if (_scansBox.containsKey(scanId)) {
        await deleteScan(scanId);
        removed += 1;
      }
    }
    return removed;
  }

  // ==========================================
  // Alertes de prix
  // ==========================================

  static const String _alertThresholdKey = 'price_alert_threshold';

  /// Seuil des alertes de hausse de prix, en %
  int getPriceAlertThreshold({int fallback = 10}) {
    if (!_isInitialized) return fallback;
    return _settingsBox.get(_alertThresholdKey)?['percent'] as int? ?? fallback;
  }

  Future<void> savePriceAlertThreshold(int percent) async {
    await _settingsBox.put(_alertThresholdKey, {'percent': percent});
  }

  // ==========================================
  // Magasins
  // ==========================================

  static const String _storesKey = 'stores';
  static const String _selectedStoreKey = 'selected_store';

  /// Magasins ajoutés par l'utilisateur (en plus de la liste par défaut)
  List<String> getCustomStores() {
    if (!_isInitialized) return [];
    return (_settingsBox.get(_storesKey)?['names'] as List?)?.cast<String>() ?? [];
  }

  /// Mémorise un magasin ajouté par l'utilisateur
  Future<void> addCustomStore(String storeName) async {
    final stores = getCustomStores();
    if (stores.any((s) => s.toLowerCase() == storeName.toLowerCase())) return;
    await _settingsBox.put(_storesKey, {'names': [...stores, storeName]});
  }

  /// Dernier magasin sélectionné dans le scanner
  String? getSelectedStore() {
    if (!_isInitialized) return null;
    return _settingsBox.get(_selectedStoreKey)?['name'] as String?;
  }

  Future<void> saveSelectedStore(String storeName) async {
    await _settingsBox.put(_selectedStoreKey, {'name': storeName});
  }

  // ==========================================
  // Paramètres (Settings)
  // ==========================================

  /// Sauvegarde la clé API Mistral
  Future<void> saveMistralApiKey(String key) async {
    await _settingsBox.put('mistral_api_key', {'key': key});
  }

  /// Récupère la clé API Mistral
  String? getMistralApiKey() {
    final data = _settingsBox.get('mistral_api_key');
    if (data == null) return null;
    return data['key'] as String?;
  }

  // ==========================================
  // CRUD — Scans (sessions)
  // ==========================================

  /// Sauvegarde une session complète (scan + articles)
  ///
  /// Si des articles étaient déjà rattachés à une autre session (cas du bouton
  /// « Enregistrer » qui regroupe des scans déjà sauvegardés automatiquement),
  /// ils sont déplacés dans cette session et les sessions d'origine devenues
  /// vides sont supprimées.
  Future<void> saveScan(ScanSession session) async {
    final previousScanIds = <String>{};
    for (final item in session.items) {
      final previousScanId = _articlesBox.get(item.id)?['scanId'] as String?;
      if (previousScanId != null && previousScanId != session.id) {
        previousScanIds.add(previousScanId);
      }
    }

    final storedScan = StoredScan(
      id: session.id,
      date: session.date,
      endDate: session.endDate,
      type: session.type,
      storeName: session.storeName,
      totalAmount: session.totalAmount,
    );

    // Persister le scan
    await _scansBox.put(session.id, storedScan.toMap());

    // Persister chaque article du scan
    for (final item in session.items) {
      await saveArticle(item, session.id);
    }

    // Supprimer les sessions d'origine qui n'ont plus aucun article
    for (final scanId in previousScanIds) {
      if (!_scanHasArticles(scanId)) {
        await _scansBox.delete(scanId);
      }
    }
  }

  bool _scanHasArticles(String scanId) =>
      _articlesBox.values.any((article) => article['scanId'] == scanId);

  /// Supprime les sessions qui n'ont plus aucun article
  Future<void> _purgeEmptyScans() async {
    final scanIdsWithArticles = _articlesBox.values
        .map((article) => article['scanId'])
        .toSet();
    final emptyScanKeys = _scansBox.keys
        .where((key) => !scanIdsWithArticles.contains(_scansBox.get(key)?['id']))
        .toList();
    if (emptyScanKeys.isNotEmpty) {
      await _scansBox.deleteAll(emptyScanKeys);
    }
  }

  /// Récupère toutes les sessions, triées par date décroissante
  Future<List<ScanSession>> getAllScans() async {
    final scans = <ScanSession>[];

    for (final key in _scansBox.keys) {
      final scanMap = _scansBox.get(key);
      if (scanMap == null) continue;

      final storedScan = StoredScan.fromMap(scanMap);

      // Récupérer les articles associés
      final articles = await getArticlesForScan(storedScan.id);

      scans.add(ScanSession(
        id: storedScan.id,
        items: articles,
        date: storedScan.date,
        endDate: storedScan.endDate,
        storeName: storedScan.storeName,
        type: storedScan.type,
      ));
    }

    // Tri par date décroissante
    scans.sort((a, b) => b.date.compareTo(a.date));
    return scans;
  }

  /// Supprime une session et ses articles associés
  Future<void> deleteScan(String scanId) async {
    await _scansBox.delete(scanId);

    // Supprimer les articles associés
    final keysToDelete = <dynamic>[];
    for (final key in _articlesBox.keys) {
      final articleMap = _articlesBox.get(key);
      if (articleMap != null && articleMap['scanId'] == scanId) {
        keysToDelete.add(key);
      }
    }
    for (final key in keysToDelete) {
      await _articlesBox.delete(key);
    }
  }

  /// Supprime toutes les sessions et tous les articles
  Future<void> clearAllScans() async {
    await _scansBox.clear();
    await _articlesBox.clear();
  }

  // ==========================================
  // CRUD — Articles
  // ==========================================

  /// Sauvegarde un article lié à un scan
  Future<void> saveArticle(ScannedItem item, String scanId) async {
    final storedArticle = StoredArticle(
      id: item.id,
      name: item.name,
      brand: item.brand,
      price: item.price,
      currency: item.currency,
      quantity: item.quantity,
      unit: item.unit,
      scanDate: item.scanDate,
      imageUrl: item.imageUrl,
      barcode: item.barcode,
      storeName: item.storeName,
      nutriscore: item.nutriscore,
      categories: item.categories,
      scanId: scanId,
    );

    await _articlesBox.put(item.id, storedArticle.toMap());
  }

  /// Met à jour un article déjà enregistré (prix, nom, contenance, magasin…)
  /// sans changer sa session
  Future<void> updateArticle(ScannedItem item) async {
    final scanId = _articlesBox.get(item.id)?['scanId'] as String?;
    if (scanId == null) return;
    await saveArticle(item, scanId);

    // Mettre à jour le montant total et le magasin de la session si applicable
    final scanMap = _scansBox.get(scanId);
    if (scanMap != null) {
      final sessionArticles = await getArticlesForScan(scanId);
      final newTotal = sessionArticles.fold(0.0, (sum, a) => sum + a.price);
      final updatedScanMap = Map<String, dynamic>.from(scanMap);
      updatedScanMap['totalAmount'] = newTotal;
      if (sessionArticles.length == 1 || scanMap['type'] == 'barcode') {
        updatedScanMap['storeName'] = item.storeName;
      }
      await _scansBox.put(scanId, updatedScanMap);
    }
  }

  /// Récupère un article scanné par son identifiant
  ScannedItem? getScannedItem(String articleId) {
    final articleMap = _articlesBox.get(articleId);
    if (articleMap == null) return null;
    final stored = StoredArticle.fromMap(articleMap);
    return ScannedItem(
      id: stored.id,
      name: stored.name,
      brand: stored.brand,
      price: stored.price,
      currency: stored.currency,
      quantity: stored.quantity,
      unit: stored.unit,
      scanDate: stored.scanDate,
      imageUrl: stored.imageUrl,
      barcode: stored.barcode,
      storeName: stored.storeName,
      nutriscore: stored.nutriscore,
      categories: stored.categories,
    );
  }

  /// Récupère tous les articles scannés appartenant à un produit donné
  List<ScannedItem> getArticlesForProduct(String productId) {
    final items = <ScannedItem>[];
    for (final key in _articlesBox.keys) {
      final articleMap = _articlesBox.get(key);
      if (articleMap == null) continue;
      if (_matchesProduct(articleMap, productId)) {
        final stored = StoredArticle.fromMap(articleMap);
        items.add(ScannedItem(
          id: stored.id,
          name: stored.name,
          brand: stored.brand,
          price: stored.price,
          currency: stored.currency,
          quantity: stored.quantity,
          unit: stored.unit,
          scanDate: stored.scanDate,
          imageUrl: stored.imageUrl,
          barcode: stored.barcode,
          storeName: stored.storeName,
          nutriscore: stored.nutriscore,
          categories: stored.categories,
        ));
      }
    }
    // Trier par date décroissante
    items.sort((a, b) => b.scanDate.compareTo(a.scanDate));
    return items;
  }

  /// Change le magasin de tous les scans d'un produit (ou ceux associés à un magasin particulier)
  Future<int> changeStoreForProduct(String productId, String? oldStore, String newStore) async {
    final cleanNewStore = newStore.trim();
    if (cleanNewStore.isEmpty) return 0;

    final allArticles = getAllStoredArticles();
    int count = 0;

    for (final article in allArticles) {
      if (_matchesProduct(article.toMap(), productId)) {
        if (oldStore != null && oldStore.isNotEmpty && article.storeName != oldStore) {
          continue;
        }

        final updatedArticle = StoredArticle(
          id: article.id,
          name: article.name,
          brand: article.brand,
          price: article.price,
          currency: article.currency,
          quantity: article.quantity,
          unit: article.unit,
          scanDate: article.scanDate,
          imageUrl: article.imageUrl,
          barcode: article.barcode,
          storeName: cleanNewStore,
          nutriscore: article.nutriscore,
          categories: article.categories,
          scanId: article.scanId,
        );

        await _articlesBox.put(article.id, updatedArticle.toMap());

        // Synchroniser le magasin de la session parente si session barcode ou à magasin unique
        final scanMap = _scansBox.get(article.scanId);
        if (scanMap != null &&
            (scanMap['type'] == 'barcode' || scanMap['storeName'] == oldStore || scanMap['storeName'] == null)) {
          final updatedScanMap = Map<String, dynamic>.from(scanMap);
          updatedScanMap['storeName'] = cleanNewStore;
          await _scansBox.put(article.scanId, updatedScanMap);
        }
        count++;
      }
    }
    return count;
  }

  /// Récupère la liste de tous les magasins connus (historique + personnalisés + courants)
  List<String> getAllKnownStores() {
    final stores = <String>{};
    // Magasins courants
    stores.addAll(['Leclerc', 'Carrefour', 'Intermarché', 'Auchan', 'Lidl', 'Monoprix', 'Aldi', 'Super U']);
    // Magasins personnalisés
    stores.addAll(getCustomStores());
    // Magasins trouvés dans les articles enregistrés
    for (final article in getAllStoredArticles()) {
      if (article.storeName != null && article.storeName!.trim().isNotEmpty) {
        stores.add(article.storeName!.trim());
      }
    }
    final list = stores.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /// Supprime un article ; sa session est supprimée si elle devient vide
  Future<void> deleteArticle(String articleId) async {
    final scanId = _articlesBox.get(articleId)?['scanId'] as String?;
    await _articlesBox.delete(articleId);
    if (scanId != null && !_scanHasArticles(scanId)) {
      await _scansBox.delete(scanId);
    }
  }

  /// Récupère les articles d'un scan donné
  Future<List<ScannedItem>> getArticlesForScan(String scanId) async {
    final items = <ScannedItem>[];

    for (final key in _articlesBox.keys) {
      final articleMap = _articlesBox.get(key);
      if (articleMap == null) continue;
      if (articleMap['scanId'] != scanId) continue;

      final stored = StoredArticle.fromMap(articleMap);
      items.add(ScannedItem(
        id: stored.id,
        name: stored.name,
        brand: stored.brand,
        price: stored.price,
        currency: stored.currency,
        quantity: stored.quantity,
        unit: stored.unit,
        scanDate: stored.scanDate,
        imageUrl: stored.imageUrl,
        barcode: stored.barcode,
        storeName: stored.storeName,
        nutriscore: stored.nutriscore,
        categories: stored.categories,
      ));
    }

    return items;
  }

  // ==========================================
  // Cache — Produits OFF
  // ==========================================

  /// Récupère un produit du cache par EAN
  CachedProduct? getCachedProduct(String ean) {
    final map = _productsBox.get(ean);
    if (map == null) return null;
    return CachedProduct.fromMap(map);
  }

  /// Met en cache un produit OFF (clé = EAN)
  Future<void> cacheProduct(CachedProduct product) async {
    await _productsBox.put(product.ean, product.toMap());
  }

  /// Nombre total de scans persistés
  int get scanCount => _scansBox.length;

  // ==========================================
  // Extractions Mistral — Pour rejouer sans coût
  // ==========================================

  /// Sauvegarde une extraction Mistral brute
  Future<void> saveMistralExtraction(StoredMistralExtraction extraction) async {
    await _mistralExtractionsBox.put(extraction.id, extraction.toMap());
  }

  // ==========================================
  // Scans en attente — Mode hors-ligne (Étape 5c)
  // ==========================================

  /// Sauvegarde un scan en attente de traitement (hors-ligne)
  Future<void> savePendingOfflineScan(PendingOfflineScan scan) async {
    await _pendingOfflineScansBox.put(scan.id, scan.toMap());
  }

  /// Récupère tous les scans en attente
  List<PendingOfflineScan> getAllPendingOfflineScans() {
    final pending = <PendingOfflineScan>[];
    for (final key in _pendingOfflineScansBox.keys) {
      final map = _pendingOfflineScansBox.get(key);
      if (map != null) {
        pending.add(PendingOfflineScan.fromMap(map));
      }
    }
    // Tri par date croissante (FIFO)
    pending.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return pending;
  }

  /// Supprime un scan en attente
  Future<void> deletePendingOfflineScan(String id) async {
    await _pendingOfflineScansBox.delete(id);
  }

  /// Vérifie s'il y a des scans en attente
  bool hasPendingOfflineScans() {
    return _pendingOfflineScansBox.isNotEmpty;
  }

  /// Nombre de scans en attente
  int get pendingOfflineScanCount => _pendingOfflineScansBox.length;

  // ==========================================
  // Analyse par produit — Étape 6
  // ==========================================

  /// Récupère tous les articles avec leurs informations complètes
  List<StoredArticle> getAllStoredArticles() {
    final allArticles = <StoredArticle>[];
    for (final key in _articlesBox.keys) {
      final articleMap = _articlesBox.get(key);
      if (articleMap != null) {
        allArticles.add(StoredArticle.fromMap(articleMap));
      }
    }
    return allArticles;
  }

  /// Récupère l'historique des prix d'un produit dans tous les magasins
  /// Retourne une map : storeName to List of PricePoint
  Map<String, List<Map<String, dynamic>>> getPriceHistoryByStore(String productId) {
    final historyByStore = <String, List<Map<String, dynamic>>>{};
    
    for (final key in _articlesBox.keys) {
      final articleMap = _articlesBox.get(key);
      if (articleMap == null) continue;
      
      final articleStore = articleMap['storeName'] as String? ?? 'Inconnu';
      
      if (_matchesProduct(articleMap, productId)) {
        if (!historyByStore.containsKey(articleStore)) {
          historyByStore[articleStore] = [];
        }
        historyByStore[articleStore]!.add({
          'id': key,
          'date': articleMap['scanDate'],
          'price': articleMap['price'],
          'quantity': articleMap['quantity'],
          'unit': articleMap['unit'],
        });
      }
    }
    
    // Tri chaque liste par date
    for (final store in historyByStore.keys) {
      historyByStore[store]!.sort((a, b) => 
          DateTime.parse(a['date'] as String).compareTo(
              DateTime.parse(b['date'] as String)));
    }
    
    return historyByStore;
  }

  /// Récupère tous les produits uniques scannés
  /// Un produit est identifié par son nom + marque + barcode
  List<Map<String, dynamic>> getUniqueProducts() {
    final allArticles = getAllStoredArticles();
    final uniqueProducts = <String, Map<String, dynamic>>{};
    
    for (final article in allArticles) {
      // Clé unique : nom + marque + barcode (ou juste barcode si présent)
      final key = article.barcode ?? '${article.name}_${article.brand}';
      
      if (!uniqueProducts.containsKey(key)) {
        uniqueProducts[key] = {
          'id': article.id,
          'name': article.name,
          'brand': article.brand,
          'barcode': article.barcode,
          'imageUrl': article.imageUrl,
          'nutriscore': article.nutriscore,
          'categories': article.categories,
          'prices': <double>[article.price],
          'scanDates': <DateTime>[article.scanDate],
          'stores': <String>{?article.storeName},
          'scanCount': 1,
          'totalPrice': article.price,
        };
      } else {
        final product = uniqueProducts[key]!;
        product['prices']!.add(article.price);
        product['scanDates']!.add(article.scanDate);
        if (article.storeName != null) {
          (product['stores'] as Set<String>).add(article.storeName!);
        }
        product['scanCount'] = (product['scanCount'] as int) + 1;
        product['totalPrice'] = (product['totalPrice'] as double) + article.price;
      }
    }
    
    // Convertir en liste et ajouter les moyennes
    final result = <Map<String, dynamic>>[];
    for (final product in uniqueProducts.values) {
      final prices = product['prices'] as List<double>;
      final avgPrice = prices.isNotEmpty ? prices.reduce((a, b) => a + b) / prices.length : 0.0;
      final scanDates = product['scanDates'] as List<DateTime>;
      final lastScanDate = scanDates.isNotEmpty 
          ? scanDates.reduce((a, b) => a.isAfter(b) ? a : b)
          : DateTime.now();
      
      result.add({
        'id': product['id'],
        'name': product['name'],
        'brand': product['brand'],
        'barcode': product['barcode'],
        'imageUrl': product['imageUrl'],
        'nutriscore': product['nutriscore'],
        'categories': product['categories'],
        'scanCount': product['scanCount'],
        'averagePrice': avgPrice,
        'lastScanDate': lastScanDate,
        'stores': (product['stores'] as Set<String>).toList(),
      });
    }
    
    // Tri par nom de produit
    result.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    
    return result;
  }

  /// Récupère les produits similaires à un produit donné (même catégorie)
  List<Map<String, dynamic>> getSimilarProducts(String productId, {String? category}) {
    final allArticles = getAllStoredArticles();
    
    // Trouver le produit de référence
    StoredArticle? referenceArticle;
    for (final article in allArticles) {
      if (article.id == productId || article.barcode == productId) {
        referenceArticle = article;
        break;
      }
    }
    
    // Si on a pas trouvé par ID, chercher par nom
    if (referenceArticle == null) {
      for (final article in allArticles) {
        if (article.name == productId) {
          referenceArticle = article;
          break;
        }
      }
    }
    
    if (referenceArticle == null) return [];
    
    // Utiliser la catégorie du produit de référence ou celle fournie
    final targetCategory = category ?? 
        (referenceArticle.categories?.isNotEmpty == true 
            ? referenceArticle.categories!.first
            : null);
    
    // Récupérer tous les articles de la même catégorie ou avec un nom similaire
    final similarProducts = <Map<String, dynamic>>[];
    
    for (final article in allArticles) {
      // Éviter d'inclure le produit de référence lui-même
      if (article.id == referenceArticle.id) continue;
      
      // Vérifier la catégorie
      final hasSameCategory = targetCategory != null && 
          article.categories?.contains(targetCategory) == true;
      
      // Vérifier la similarité du nom (si pas de catégorie)
      final hasSimilarName = targetCategory == null && 
          article.name.toLowerCase().contains(
              referenceArticle.name.toLowerCase().split(' ').first) == true;
      
      if (hasSameCategory || hasSimilarName) {
        similarProducts.add({
          'id': article.id,
          'name': article.name,
          'brand': article.brand,
          'barcode': article.barcode,
          'storeName': article.storeName,
          'price': article.price,
          'quantity': article.quantity,
          'unit': article.unit,
          'scanDate': article.scanDate,
          'nutriscore': article.nutriscore,
          'imageUrl': article.imageUrl,
          'categories': article.categories,
        });
      }
    }
    
    // Tri par prix croissant
    similarProducts.sort((a, b) => 
        (a['price'] as double).compareTo(b['price'] as double));
    
    return similarProducts;
  }

  /// Supprime un magasin de tous les articles d'un produit
  /// Met à jour le storeName à null pour tous les articles correspondants
  Future<void> removeStoreFromProduct(String storeName, String productId) async {
    final allArticles = getAllStoredArticles();
    
    for (final article in allArticles) {
      if (_matchesProduct(article.toMap(), productId) && article.storeName == storeName) {
        // Créer une copie modifiée de l'article
        final updatedArticle = StoredArticle(
          id: article.id,
          name: article.name,
          brand: article.brand,
          price: article.price,
          currency: article.currency,
          quantity: article.quantity,
          unit: article.unit,
          scanDate: article.scanDate,
          imageUrl: article.imageUrl,
          barcode: article.barcode,
          storeName: null, // Supprimer le magasin
          nutriscore: article.nutriscore,
          categories: article.categories,
          scanId: article.scanId,
        );
        
        // Sauvegarder l'article modifié
        await _articlesBox.put(article.id, updatedArticle.toMap());
      }
    }
  }

  // ==========================================
  // Corrections au niveau d'un produit
  // ==========================================

  /// Un article appartient au produit [productId] s'il a cet id, ce code-barres
  /// ou ce nom (même règle que l'historique affiché par la fiche produit)
  static bool _matchesProduct(Map article, String productId) =>
      article['id'] == productId || article['barcode'] == productId || article['name'] == productId;

  /// Nombre d'articles (scans) enregistrés pour un produit
  int countProductArticles(String productId) =>
      _articlesBox.values.where((a) => _matchesProduct(a, productId)).length;

  /// Supprime tous les articles d'un produit ; les sessions devenues vides sont supprimées.
  /// Retourne le nombre d'articles supprimés.
  Future<int> deleteProduct(String productId) async {
    final ids = _articlesBox.values
        .where((a) => _matchesProduct(a, productId))
        .map((a) => a['id'] as String)
        .toList();
    for (final id in ids) {
      await deleteArticle(id);
    }
    return ids.length;
  }

  /// Associe tous les articles d'un produit à une autre fiche Open Food Facts
  /// (correspondance erronée). Le prix, la date et le magasin de chaque scan
  /// sont conservés ; une ligne de ticket de N articles reste un pack de N.
  /// Retourne le nombre d'articles modifiés.
  Future<int> rematchProduct(
    String productId, {
    required String name,
    String? brand,
    String? barcode,
    String? imageUrl,
    String? nutriscore,
    List<String>? categories,
    double? packQuantity,
    String? packUnit,
  }) async {
    final articles = _articlesBox.values
        .where((a) => _matchesProduct(a, productId))
        .map(StoredArticle.fromMap)
        .toList();
    for (final article in articles) {
      // Nombre d'articles achetés sur cette ligne (pack « x … » ou unités d'un ticket)
      final unit = article.unit?.trim();
      final isPack = unit != null && unit.toLowerCase().startsWith('x ');
      final isCount = unit == null || unit == 'unité';
      final count = (isPack || isCount) ? (article.quantity ?? 1) : 1.0;
      final lineQuantity = ticketLineQuantity(count: count, packQuantity: packQuantity, packUnit: packUnit);

      await _articlesBox.put(
        article.id,
        StoredArticle(
          id: article.id,
          name: name,
          brand: brand,
          price: article.price,
          currency: article.currency,
          quantity: lineQuantity.quantity,
          unit: lineQuantity.unit,
          scanDate: article.scanDate,
          imageUrl: imageUrl,
          barcode: barcode,
          storeName: article.storeName,
          nutriscore: nutriscore,
          categories: categories,
          scanId: article.scanId,
        ).toMap(),
      );
    }
    return articles.length;
  }
}
