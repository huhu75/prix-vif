import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../models.dart';
import '../models/hive_models.dart';
import 'open_food_facts_service.dart';
import 'scan_repository.dart';
import 'dart:convert';

/// Service de gestion de la connectivité réseau et du mode hors-ligne
/// Étape 5c — Permet de stocker les scans hors-ligne et de les traiter au retour du réseau
class ConnectivityService with WidgetsBindingObserver {
  static final ConnectivityService _instance = ConnectivityService._internal();
  
  factory ConnectivityService() => _instance;
  
  ConnectivityService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;
  bool _isInitialized = false;
  ScanRepository? _repository;
  OpenFoodFactsService? _offService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  // Callbacks pour notifier les changements de connectivité
  Function(bool)? onConnectivityChanged;

  /// Initialise le service avec le repository et le service OFF
  Future<void> init({ScanRepository? repository, OpenFoodFactsService? offService}) async {
    if (_isInitialized) return;
    
    _repository = repository;
    _offService = offService;
    
    // Vérifier la connectivité initiale
    await _checkConnectivity();
    
    // Écouter les changements de connectivité
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _handleConnectivityChange(results);
    });
    
    _isInitialized = true;
  }

  /// Définit le repository (pour injection de dépendances)
  void setRepository(ScanRepository repository) {
    _repository = repository;
  }

  /// Définit le service OFF (pour injection de dépendances)
  void setOffService(OpenFoodFactsService offService) {
    _offService = offService;
  }

  /// Vérifie la connectivité actuelle
  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _handleConnectivityChange(results);
    } catch (e) {
      debugPrint('⚠️ [ConnectivityService] Erreur vérification connectivité: $e');
      _isOnline = false;
      onConnectivityChanged?.call(false);
    }
  }

  /// Gère les changements de connectivité
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (results.isEmpty) {
      _isOnline = false;
    } else {
      // On est en ligne si au moins une connexion est disponible (sauf none)
      _isOnline = results.any((result) => result != ConnectivityResult.none);
    }
    
    debugPrint('🌐 [ConnectivityService] Connectivité: ${_isOnline ? 'EN LIGNE' : 'HORS-LIGNE'}');
    
    // Notifier les écouteurs
    onConnectivityChanged?.call(_isOnline);
    
    // Si on revient en ligne, traiter les scans en attente
    if (_isOnline) {
      _processPendingScans();
    }
  }

  /// Vérifie si l'appareil est actuellement en ligne
  bool get isOnline => _isOnline;

  /// Traite tous les scans en attente quand le réseau revient
  Future<void> _processPendingScans() async {
    if (_repository == null || _offService == null) {
      debugPrint('⚠️ [ConnectivityService] Repository ou OFF service non initialisé');
      return;
    }
    
    final pendingScans = _repository!.getAllPendingOfflineScans();
    if (pendingScans.isEmpty) {
      debugPrint('✅ [ConnectivityService] Aucun scan en attente');
      return;
    }
    
    debugPrint('🔄 [ConnectivityService] Traitement de ${pendingScans.length} scan(s) en attente...');
    
    for (final pendingScan in pendingScans) {
      try {
        await _processSinglePendingScan(pendingScan);
        
        // Supprimer le scan en attente après traitement réussi
        await _repository!.deletePendingOfflineScan(pendingScan.id);
        debugPrint('✅ [ConnectivityService] Scan ${pendingScan.id} traité avec succès');
      } catch (e) {
        debugPrint('❌ [ConnectivityService] Erreur traitement scan ${pendingScan.id}: $e');
        // On ne supprime pas le scan en cas d'erreur, il sera retenté plus tard
      }
    }
  }

  /// Traite un seul scan en attente
  Future<void> _processSinglePendingScan(PendingOfflineScan pendingScan) async {
    if (_repository == null || _offService == null) {
      throw Exception('Repository ou OFF service non initialisé');
    }
    
    // Cas 1: Si l'extraction Mistral a déjà été faite (on a le JSON brut)
    if (pendingScan.isMistralExtracted && pendingScan.rawMistralJson != null) {
      // Parser le JSON de Mistral
      final jsonData = jsonDecode(pendingScan.rawMistralJson!) as Map<String, dynamic>;
      final articlesJson = jsonData['articles'] as List<dynamic>? ?? [];
      
      final List<ScannedItem> items = [];
      
      for (final articleJson in articlesJson) {
        final article = articleJson as Map<String, dynamic>;
        final name = article['nom'] as String? ?? 'Produit inconnu';
        final price = (article['prix'] as num? ?? 0).toDouble();
        final quantity = article['quantite'] as num?;
        
        // Rechercher sur OFF
        final products = await _offService!.searchByNameWithTwoPasses(name);
        
        final product = products.isNotEmpty ? products.first : null;
        
        final item = ScannedItem(
          id: 'offline_${DateTime.now().millisecondsSinceEpoch}_${items.length}',
          name: product?.name ?? name,
          brand: product?.brand,
          price: price,
          quantity: quantity?.toDouble(),
          unit: null,
          scanDate: DateTime.now(),
          barcode: product?.barcode,
          imageUrl: product?.imageUrl,
          storeName: null,
          nutriscore: product?.nutriscore,
          categories: product?.categories,
        );
        
        items.add(item);
      }
      
      // Sauvegarder les articles en base
      if (items.isNotEmpty) {
        // Créer une session et la sauvegarder
        final session = ScanSession(
          id: pendingScan.scanId ?? 'recovered_${DateTime.now().millisecondsSinceEpoch}',
          items: items,
          date: pendingScan.createdAt,
          endDate: DateTime.now(),
          storeName: null,
          type: 'ticket',
        );
        
        await _repository!.saveScan(session);
        debugPrint('✅ [ConnectivityService] ${items.length} articles récupérés pour scan ${pendingScan.id}');
      }
    } 
    // Cas 2: Si on a l'image mais pas encore l'extraction Mistral
    // (Cela nécessiterait d'appeler Mistral, mais on évite de consommer des crédits)
    // On va juste signaler que le scan est prêt à être retraité manuellement
    else if (pendingScan.imageBase64 != null) {
      debugPrint('ℹ️ [ConnectivityService] Scan ${pendingScan.id} a une image mais pas d\'extraction Mistral');
      // Dans ce cas, on pourrait relancer l'extraction Mistral, mais c'est coûteux
      // Pour l'instant, on va juste marquer que le scan est prêt
    }
  }

  /// Stocke un scan pour traitement hors-ligne
  /// Appelé quand une extraction Mistral a réussi mais que le matching OFF a échoué à cause du réseau
  Future<void> storeForOfflineProcessing({
    String? scanId,
    String? imageBase64,
    String? rawMistralJson,
    bool isMistralExtracted = false,
  }) async {
    if (_repository == null) {
      debugPrint('⚠️ [ConnectivityService] Repository non initialisé');
      return;
    }
    
    final pendingScan = PendingOfflineScan(
      id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
      scanId: scanId,
      imageBase64: imageBase64,
      rawMistralJson: rawMistralJson,
      createdAt: DateTime.now(),
      isMistralExtracted: isMistralExtracted,
    );
    
    await _repository!.savePendingOfflineScan(pendingScan);
    debugPrint('💾 [ConnectivityService] Scan stocké pour traitement hors-ligne: ${pendingScan.id}');
  }

  /// Vérifie s'il y a des scans en attente
  bool hasPendingScans() {
    if (_repository == null) return false;
    return _repository!.hasPendingOfflineScans();
  }

  /// Obtient le nombre de scans en attente
  int get pendingScanCount {
    if (_repository == null) return 0;
    return _repository!.pendingOfflineScanCount;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quand l'app revient au premier plan, vérifier la connectivité
    if (state == AppLifecycleState.resumed) {
      _checkConnectivity();
    }
  }
}
