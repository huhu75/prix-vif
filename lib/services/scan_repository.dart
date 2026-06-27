import 'package:hive_flutter/hive_flutter.dart';
import '../models.dart';
import '../models/hive_models.dart';

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

  late Box<Map> _scansBox;
  late Box<Map> _articlesBox;
  late Box<Map> _productsBox;
  late Box<Map> _mistralExtractionsBox;
  late Box<Map> _pendingOfflineScansBox;

  bool _isInitialized = false;

  /// Initialise Hive et ouvre les boxes
  Future<void> init() async {
    if (_isInitialized) return;

    _scansBox = await Hive.openBox<Map>(_scansBoxName);
    _articlesBox = await Hive.openBox<Map>(_articlesBoxName);
    _productsBox = await Hive.openBox<Map>(_productsBoxName);
    _mistralExtractionsBox = await Hive.openBox<Map>(_mistralExtractionsBoxName);
    _pendingOfflineScansBox = await Hive.openBox<Map>(_pendingOfflineScansBoxName);

    _isInitialized = true;
  }

  // ==========================================
  // CRUD — Scans (sessions)
  // ==========================================

  /// Sauvegarde une session complète (scan + articles)
  Future<void> saveScan(ScanSession session) async {
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

  /// Vérifie si un produit est en cache
  bool hasProductInCache(String ean) {
    return _productsBox.containsKey(ean);
  }

  /// Nombre total de produits en cache
  int get cachedProductCount => _productsBox.length;

  /// Nombre total de scans persistés
  int get scanCount => _scansBox.length;

  /// Nombre total d'articles persistés
  int get articleCount => _articlesBox.length;

  // ==========================================
  // Extractions Mistral — Pour rejouer sans coût
  // ==========================================

  /// Sauvegarde une extraction Mistral brute
  Future<void> saveMistralExtraction(StoredMistralExtraction extraction) async {
    await _mistralExtractionsBox.put(extraction.id, extraction.toMap());
  }

  /// Récupère une extraction Mistral par ID
  StoredMistralExtraction? getMistralExtraction(String id) {
    final map = _mistralExtractionsBox.get(id);
    if (map == null) return null;
    return StoredMistralExtraction.fromMap(map);
  }

  /// Récupère toutes les extractions Mistral pour un scan donné
  List<StoredMistralExtraction> getMistralExtractionsForScan(String scanId) {
    final extractions = <StoredMistralExtraction>[];
    for (final key in _mistralExtractionsBox.keys) {
      final map = _mistralExtractionsBox.get(key);
      if (map == null) continue;
      final extraction = StoredMistralExtraction.fromMap(map);
      if (extraction.scanId == scanId) {
        extractions.add(extraction);
      }
    }
    return extractions;
  }

  /// Supprime une extraction Mistral
  Future<void> deleteMistralExtraction(String id) async {
    await _mistralExtractionsBox.delete(id);
  }

  /// Supprime toutes les extractions Mistral pour un scan
  Future<void> deleteMistralExtractionsForScan(String scanId) async {
    final extractions = getMistralExtractionsForScan(scanId);
    for (final extraction in extractions) {
      await deleteMistralExtraction(extraction.id);
    }
  }

  /// Nombre total d'extractions Mistral persistées
  int get mistralExtractionCount => _mistralExtractionsBox.length;

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

  /// Récupère un scan en attente par ID
  PendingOfflineScan? getPendingOfflineScan(String id) {
    final map = _pendingOfflineScansBox.get(id);
    if (map == null) return null;
    return PendingOfflineScan.fromMap(map);
  }

  /// Supprime un scan en attente
  Future<void> deletePendingOfflineScan(String id) async {
    await _pendingOfflineScansBox.delete(id);
  }

  /// Supprime tous les scans en attente
  Future<void> clearAllPendingOfflineScans() async {
    await _pendingOfflineScansBox.clear();
  }

  /// Vérifie s'il y a des scans en attente
  bool hasPendingOfflineScans() {
    return _pendingOfflineScansBox.isNotEmpty;
  }

  /// Nombre de scans en attente
  int get pendingOfflineScanCount => _pendingOfflineScansBox.length;
}
