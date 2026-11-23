import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../theme.dart';
import '../models.dart';
import '../models/hive_models.dart';
import '../models/product_category.dart';
import '../analytics/analytics.dart';
import '../services/category_service.dart';
import '../utils/image_utils.dart';
import '../services/open_food_facts_service.dart';
import '../services/mistral_service.dart';
import '../services/scan_repository.dart';
import '../services/connectivity_service.dart';
import '../widgets/scanner_overlay.dart';
import '../widgets/magic_button.dart';
import '../widgets/ai_scan_effect.dart';
import '../widgets/magic_title.dart';
import '../widgets/nav_buttons.dart';
import '../services/camera_service.dart';
import '../widgets/scan/mistral_settings_dialog.dart';
import '../widgets/scan/price_input_sheet.dart';
import '../widgets/scan/scan_idle_panel.dart';
import '../widgets/scan/scan_mode_selector.dart';
import '../widgets/scan/store_selector.dart';
import '../widgets/scan/store_management_dialog.dart';
import '../widgets/scan/ticket_confirmation_sheet.dart';
import '../widgets/scan/ticket_scan_zone.dart';

class ScanScreen extends StatefulWidget {
  final List<ScannedItem> scannedItems;
  final Function(ScannedItem) onItemScanned;
  final VoidCallback onViewResults;
  final VoidCallback onViewHistory;
  final ScanRepository? repository;
  final Function(String) onScanTypeChanged;
  final Future<void> Function()? onScanSaved;

  /// Bouton Retour de la barre d'app (onglet précédent) ; absent si `null`
  final VoidCallback? onBack;

  /// L'écran est affiché (onglet Scanner sélectionné) : la caméra ne tourne
  /// que dans ce cas, en mode code-barres, après un tap sur SCANNER.
  final bool isActive;

  /// Mode demandé depuis l'accueil (`true` = code-barres, `false` = ticket),
  /// appliqué à chaque nouvelle valeur de [modeRequestId].
  final bool? requestedBarcodeMode;
  final int modeRequestId;

  /// Nouvelle séance de scan (arrivée depuis l'accueil) à chaque nouvelle
  /// valeur : le magasin est à choisir de nouveau avant de scanner.
  final int scanSessionId;

  const ScanScreen({
    super.key,
    required this.scannedItems,
    required this.onItemScanned,
    required this.onViewResults,
    required this.onViewHistory,
    this.repository,
    required this.onScanTypeChanged,
    this.onScanSaved,
    this.onBack,
    this.isActive = true,
    this.requestedBarcodeMode,
    this.modeRequestId = 0,
    this.scanSessionId = 0,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  String? _scannedBarcode;
  String? _errorMessage;
  final List<String> _stores = [
    'Carrefour',
    'Auchan',
    'Leclerc',
    'Monoprix',
    'Franprix',
    'Biocoop',
  ];
  // Magasin de la séance : `null` tant qu'il n'est pas choisi (rien ne se
  // scanne avant). Le dernier magasin choisi est proposé en raccourci.
  String? _selectedStore;
  String? _lastStore;

  // La caméra tournait avant que l'app passe en arrière-plan : la relancer au retour
  bool _resumeScanOnForeground = false;
  bool _isProcessingScan = false;
  bool _isBarcodeMode = true;
  XFile? _ticketImage;
  final ImagePicker _picker = ImagePicker();
  int? _originalSize;
  int? _compressedSize;
  Uint8List? _compressedImageBytes;
  bool _isCompressing = false;
  String? _compressionMessage;
  final OpenFoodFactsService _offService = OpenFoodFactsService();
  bool _isLoadingProduct = false;
  
  // Service de connectivité (Étape 5c)
  final ConnectivityService _connectivityService = ConnectivityService();
  
  // Service de caméra
  final CameraService _cameraService = CameraService();

  final TextEditingController _storeController = TextEditingController();
  final TextEditingController _newStoreController = TextEditingController();
  late AnimationController _buttonController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isBarcodeMode = widget.requestedBarcodeMode ?? true;
    _loadSavedStores();
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Étape 3c — Injecter le repository dans le service OFF pour le cache
    if (widget.repository != null) {
      _offService.setRepository(widget.repository!);
    }
    
    // Étape 5c — Initialiser le service de connectivité
    if (widget.repository != null) {
      _connectivityService.setRepository(widget.repository!);
    }
    _connectivityService.setOffService(_offService);
    _connectivityService.onConnectivityChanged = (isOnline) {
      if (isOnline) {
        // Au retour du réseau, vérifier s'il y a des scans en attente
        _showPendingScansNotification();
      }
    };
    _connectivityService.init();
    
    // Notifier le type initial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onScanTypeChanged(_isBarcodeMode ? 'barcode' : 'ticket');
    });
    
    // La caméra ne démarre pas ici : seulement au tap sur SCANNER, une fois
    // le magasin choisi
  }

  @override
  void didUpdateWidget(covariant ScanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    var cameraNeedsSync = widget.isActive != oldWidget.isActive;

    // Nouvelle séance (arrivée depuis l'accueil) : magasin et ticket à refaire
    if (widget.scanSessionId != oldWidget.scanSessionId) {
      _selectedStore = null;
      _storeController.clear();
      _ticketImage = null;
      _originalSize = null;
      _compressedSize = null;
      _compressedImageBytes = null;
      _compressionMessage = null;
      cameraNeedsSync = true;
      // Magasins renommés ou ajoutés depuis une fiche produit
      _loadSavedStores();
    }

    // Mode demandé depuis l'accueil. Le parent connaît déjà le type de scan :
    // pas d'appel à onScanTypeChanged ici (il est en train de se reconstruire).
    final requested = widget.requestedBarcodeMode;
    if (widget.modeRequestId != oldWidget.modeRequestId && requested != null && requested != _isBarcodeMode) {
      _isBarcodeMode = requested;
      if (requested) _ticketImage = null;
      cameraNeedsSync = true;
    }

    if (cameraNeedsSync) _syncCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Gérer le cycle de vie pour libérer/relancer la caméra
    if (state == AppLifecycleState.paused) {
      _resumeScanOnForeground = _cameraService.isScanning;
      _stopScanner();
    } else if (state == AppLifecycleState.resumed) {
      // Relancer la caméra au retour au premier plan seulement si elle tournait
      if (_resumeScanOnForeground && widget.isActive && _isBarcodeMode && _selectedStore != null) {
        _startScanner();
      }
      _resumeScanOnForeground = false;
    }
  }

  /// Arrête la caméra si l'écran est caché, en mode ticket ou sans magasin.
  /// Elle ne démarre jamais toute seule : seulement au tap sur SCANNER.
  void _syncCamera() {
    if (!widget.isActive || !_isBarcodeMode || _selectedStore == null) _stopScanner();
  }

  Future<void> _startScanner() async {
    // Étape 1 obligatoire : pas de scan sans magasin
    if (_selectedStore == null) return;
    try {
      await _cameraService.start();
      setState(() {
        _errorMessage = null;
      });
    } catch (e) {
      // Vérifier si c'est une erreur de permission
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('permission') || errorString.contains('denied')) {
        setState(() {
          _errorMessage = 'Permission caméra refusée. Allez dans les paramètres pour autoriser.';
        });
      } else {
        setState(() {
          _errorMessage = 'Erreur caméra: ${e.toString()}';
        });
      }
    }
  }

  /// Passe en mode code-barres (`true`) ou ticket (`false`)
  void _setBarcodeMode(bool barcode) {
    if (barcode == _isBarcodeMode) return;
    setState(() {
      _isBarcodeMode = barcode;
      if (barcode) _ticketImage = null;
    });
    widget.onScanTypeChanged(barcode ? 'barcode' : 'ticket');
    _syncCamera();
  }

  /// Oublie la photo de ticket en cours
  void _resetTicket() {
    setState(() {
      _ticketImage = null;
      _originalSize = null;
      _compressedSize = null;
      _compressedImageBytes = null;
      _compressionMessage = null;
    });
  }

  // ==================== ÉTAPE 5C — MODE HORS-LIGNE ====================

  /// Stocke un scan pour traitement hors-ligne
  /// L'extraction Mistral a déjà été persistée par [_processTicketImage] sous [scanId].
  Future<void> _storeForOfflineProcessing(String scanId, String rawMistralJson) async {
    if (widget.repository == null || _compressedImageBytes == null) return;

    // Stocker dans les scans en attente (même scanId que l'extraction Mistral)
    await _connectivityService.storeForOfflineProcessing(
      scanId: scanId,
      imageBase64: base64Encode(_compressedImageBytes!),
      rawMistralJson: rawMistralJson,
      isMistralExtracted: true,
      storeName: _selectedStore,
    );
    
    debugPrint('💾 [5c] Scan ticket stocké pour traitement hors-ligne');
    
    // Notifier l'utilisateur
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.textMuted,
          content: const Text(
            'Pas de connexion Internet. Le scan sera traité dès que le réseau sera de retour.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  /// Affiche une notification quand des scans en attente sont traités au retour du réseau
  void _showPendingScansNotification() {
    if (_connectivityService.pendingScanCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.secondary,
              content: Text(
                '${_connectivityService.pendingScanCount} scan(s) en attente sont en cours de traitement...',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      });
    }
  }

  Future<void> _stopScanner() async {
    try {
      await _cameraService.stop();
      setState(() {});
    } catch (e) {
      // Ignorer les erreurs lors de l'arrêt
    }
  }

  Future<void> _toggleFlash() async {
    try {
      await _cameraService.toggleTorch();
      setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = 'Impossible d\'activer le flash';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.dispose();
    _stopScanner();
    _buttonController.dispose();
    _storeController.dispose();
    _newStoreController.dispose();
    super.dispose();
  }

  /// Restaure les magasins ajoutés et le dernier magasin choisi (persistés dans
  /// Hive), hors magasins supprimés. Le dernier magasin n'est que proposé :
  /// la séance démarre sans magasin.
  Future<void> _loadSavedStores() async {
    final repository = widget.repository;
    if (repository == null) return;
    await repository.ready;
    if (!mounted) return;
    final saved = repository.getSelectedStore();
    final hidden = repository.getHiddenStores().map((s) => s.toLowerCase()).toList();
    setState(() {
      repository.getCustomStores().forEach(_insertStore);
      _stores.removeWhere((s) => hidden.contains(s.toLowerCase()));
      if (saved != null && _stores.contains(saved)) _lastStore = saved;
    });
  }

  /// Insère un magasin dans la liste triée (sans doublon, casse ignorée)
  void _insertStore(String store) {
    if (_stores.any((s) => s.toLowerCase() == store.toLowerCase())) return;
    final insertIndex = _stores.indexWhere((s) => s.toLowerCase().compareTo(store.toLowerCase()) > 0);
    if (insertIndex == -1) {
      _stores.add(store);
    } else {
      _stores.insert(insertIndex, store);
    }
  }

  void _selectStore(String store) {
    setState(() {
      _selectedStore = store;
      _lastStore = store;
      _storeController.text = store;
      _errorMessage = null;
    });
    // Mémorisé une fois la base ouverte : un choix fait juste au lancement
    // (Hive pas encore prêt) n'échoue pas
    final repository = widget.repository;
    repository?.ready.then((_) => repository.saveSelectedStore(store));
  }

  Future<void> _addStore() async {
    _newStoreController.clear();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ajouter un magasin'),
        content: TextField(
          controller: _newStoreController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Nom du magasin',
            filled: true,
            fillColor: AppTheme.surfaceLight,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          MagicButton(
            text: 'Ajouter',
            onPressed: () {
              final name = _newStoreController.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(dialogContext).pop(name);
              }
            },
            width: 120,
            height: 44,
          ),
        ],
      ),
    );

    if (result == null) return;

    final trimmed = result.trim();
    final existing = _stores.where((s) => s.toLowerCase() == trimmed.toLowerCase());
    if (existing.isNotEmpty) {
      _selectStore(existing.first);
      return;
    }

    setState(() => _insertStore(trimmed));
    _selectStore(trimmed);
    final repository = widget.repository;
    if (repository != null) {
      await repository.ready;
      await repository.addCustomStore(trimmed);
    }
  }

  /// Ouvre la liste des magasins proposés pour en supprimer
  Future<void> _manageStores() async {
    await showStoreManagementDialog(
      context,
      stores: List.of(_stores),
      onRemove: _removeStore,
    );
  }

  /// Supprime un magasin de la liste proposée (persisté) : s'il était choisi
  /// pour la séance, le choix est annulé. Les prix relevés dans ce magasin
  /// restent dans l'historique.
  Future<void> _removeStore(String store) async {
    final lower = store.toLowerCase();
    final repository = widget.repository;
    if (repository != null) {
      await repository.ready;
      await repository.removeStore(store);
    }
    if (!mounted) return;
    setState(() {
      _stores.removeWhere((s) => s.toLowerCase() == lower);
      if (_selectedStore?.toLowerCase() == lower) {
        _selectedStore = null;
        _storeController.clear();
      }
      if (_lastStore?.toLowerCase() == lower) {
        _lastStore = null;
      }
    });
  }

  Future<void> _captureTicket(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100,
      );
      if (image != null) {
        setState(() {
          _ticketImage = image;
          _originalSize = null;
          _compressedSize = null;
          _compressedImageBytes = null;
          _errorMessage = null;
          _compressionMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la capture : ${e.toString()}';
      });
    }
  }

  Future<void> _compressTicketImage() async {
    if (_ticketImage == null || _isCompressing) return;
    setState(() {
      _isCompressing = true;
      _errorMessage = null;
      _compressionMessage = null;
    });

    try {
      // Utiliser l'utilitaire centralisé pour la 4a
      final result = await prepareImageForMistral(_ticketImage!);

      if (!result.success) {
        throw Exception(result.error ?? 'Erreur inconnue lors de la préparation de l\'image');
      }

      // Extraire les données du résultat
      final base64 = result.base64!;
      final compressedBytes = base64Decode(base64);

      setState(() {
        _originalSize = result.originalSize;
        _compressedSize = result.compressedSize;
        _compressedImageBytes = Uint8List.fromList(compressedBytes);
        _compressionMessage = getCompressionMessage(result);
        _isCompressing = false;
      });

      // Vérifier le critère de réduction (≥ 60%)
      if (result.reductionPercent != null && result.reductionPercent! < 60) {
        debugPrint(
          "⚠️ [ScanScreen] Réduction insuffisante : ${result.reductionPercent!.toStringAsFixed(1)}% "
          "(objectif : ≥ 60%)"
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la compression : ${e.toString()}';
        _isCompressing = false;
        _compressionMessage = null;
      });
    }
  }

  Future<void> _processTicketImage() async {
    // Magasin figé au début de l'analyse (le ticket est enregistré pour lui)
    final store = _selectedStore;
    if (_compressedImageBytes == null || _isLoadingProduct || store == null) return;
    setState(() {
      _isLoadingProduct = true;
      _errorMessage = null;
    });

    try {
      final mistralService = MistralService();
      // 1. Extraire les articles avec Mistral (ou mock)
      final extractionResult = await mistralService.extractArticles(_compressedImageBytes!);

      // 4b — Persister immédiatement le JSON brut avant le matching OFF
      // Cela permet de rejouer sans re-consommer de crédits Mistral
      // Utiliser le même ID pour l'extraction Mistral et la ScanSession
      String? scanId;
      if (widget.repository != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extractionId = 'mistral_$timestamp';
        scanId = 'ticket_$timestamp';
        
        final mistralExtraction = StoredMistralExtraction(
          id: extractionId,
          scanId: scanId,
          rawJson: extractionResult.rawJson,
          extractedAt: DateTime.now(),
          imageBase64: _compressionMessage != null ? base64Encode(_compressedImageBytes!) : null,
        );
        
        await widget.repository!.saveMistralExtraction(mistralExtraction);
      }

      // Étape 5c — Vérifier la connectivité avant le matching OFF
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasNetwork = connectivityResult.any((result) => result != ConnectivityResult.none);

      if (!hasNetwork) {
        // Pas de réseau : mettre le ticket en attente UNE seule fois. Il sera rejoué
        // automatiquement (matching OFF + sauvegarde) au retour de la connexion,
        // donc pas de feuille de confirmation ici (elle créerait un doublon).
        debugPrint('⚠️ [ScanScreen] Pas de réseau - stockage pour traitement hors-ligne');
        await _storeForOfflineProcessing(
          scanId ?? 'ticket_${DateTime.now().millisecondsSinceEpoch}',
          extractionResult.rawJson,
        );
        if (mounted) {
          // Vider la zone ticket pour éviter un second envoi du même ticket
          setState(() {
            _isLoadingProduct = false;
            _ticketImage = null;
            _originalSize = null;
            _compressedSize = null;
            _compressedImageBytes = null;
            _compressionMessage = null;
          });
        }
        return;
      }

      // 2. Pour chaque article, rechercher sur Open Food Facts et récupérer le meilleur candidat + les autres candidats
      final List<ExtractedTicketItem> confirmationItems = [];

      for (var article in extractionResult.articles) {
        // Étape 4c — Stratégie deux passes : nom complet → nom nettoyé
        // Logique centralisée dans OpenFoodFactsService.searchByNameWithTwoPasses()
        List<OFFProduct> candidates = [];

        try {
          candidates = await _offService.searchByNameWithTwoPasses(article.name);
        } catch (e) {
          debugPrint('⚠️ [ScanScreen] Erreur matching OFF pour ${article.name}: $e');
          // En cas d'erreur, on continue sans candidat
        }

        confirmationItems.add(
          ExtractedTicketItem(
            rawName: article.name,
            price: article.price,
            quantity: article.quantity,
            matchedProduct: candidates.isNotEmpty ? candidates.first : null,
            candidates: candidates,
            isSelected: true,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _isLoadingProduct = false;
        });

        // 3. Afficher la boîte de dialogue de confirmation des articles
        final List<ScannedItem>? imported = await showModalBottomSheet<List<ScannedItem>>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return TicketConfirmationSheet(
              items: confirmationItems,
              storeName: store,
              offService: _offService,
            );
          },
        );

        if (imported != null && imported.isNotEmpty) {
          for (var item in imported) {
            widget.onItemScanned(item);
          }

          // Étape 4c — Persister immédiatement les articles matchés via ScanRepository
          // Crée une session 'ticket' et la sauvegarde en base sans action manuelle
          // Utiliser le même scanId que celui de l'extraction Mistral
          if (widget.repository != null) {
            final ticketSession = ScanSession(
              id: scanId ?? 'ticket_${DateTime.now().millisecondsSinceEpoch}',
              items: List<ScannedItem>.from(imported),
              date: DateTime.now(),
              endDate: DateTime.now(),
              storeName: store,
              type: 'ticket',
            );
            try {
              await widget.repository!.saveScan(ticketSession);
              debugPrint('✅ [4c] Session ticket persistée : ${imported.length} articles via saveArticle()');
              // Notifier le parent pour recharger les sessions
              await widget.onScanSaved?.call();
            } catch (e) {
              debugPrint('⚠️ [4c] Erreur persistance session ticket: $e');
            }
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.secondary,
              content: Text(
                'Importation réussie : ${imported.length} articles ajoutés !',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );

          // Réinitialiser la zone de ticket après l'importation
          setState(() {
            _ticketImage = null;
            _originalSize = null;
            _compressedSize = null;
            _compressedImageBytes = null;
            _compressionMessage = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProduct = false;
          _errorMessage = 'Erreur lors du traitement du ticket : $e';
        });
      }
    }
  }

  CategoryService? _categoryServiceInstance;
  CategoryService get _categoryService => _categoryServiceInstance ??= CategoryService(widget.repository!);

  /// Prépare le conseil d'achat de la feuille de prix : enregistre la catégorie
  /// Open Food Facts du produit, puis compare avec les prix déjà relevés.
  /// `null` sans dépôt ou sans magasin.
  Future<PriceAdvice Function(double? price)?> _buildAdvisor(String barcode, OFFProduct? product) async {
    final repository = widget.repository;
    final store = _selectedStore;
    if (repository == null || store == null) return null;
    try {
      ProductCategory? category;
      if (product != null) {
        try {
          category = await _categoryService.applyFromProduct(barcode, product).timeout(const Duration(seconds: 3));
        } catch (_) {
          // Taxonomie lente ou hors-ligne : catégorie déjà connue, sinon aucune
        }
      }
      category ??= repository.getProductCategory('bc_${barcode.trim()}');
      final sessions = await repository.getAllScans();
      final categories = repository.getAllProductCategories();
      final key = productKeyFor(barcode: barcode, name: product?.name ?? barcode, brand: product?.brand);
      return (price) => PriceAdvice.calculate(
            sessions: sessions,
            categories: categories,
            productKey: key,
            store: store,
            price: price,
            quantity: product?.quantity,
            unit: product?.unit,
            category: category,
          );
    } catch (e) {
      debugPrint('Conseil d\'achat indisponible : $e');
      return null;
    }
  }

  /// Derniers prix du produit [barcode] dans chaque magasin, `null` s'il n'a
  /// jamais été scanné dans un magasin
  Future<ProductStorePrices?> _knownPrices(String barcode) async {
    final repository = widget.repository;
    if (repository == null || barcode.trim().isEmpty) return null;
    try {
      final sessions = await repository.getAllScans();
      return ProductStorePrices.forProduct(sessions, 'bc_${barcode.trim()}');
    } catch (e) {
      debugPrint('Prix connus indisponibles : $e');
      return null;
    }
  }

  void _onBarcodeScanned(List<Barcode> barcodes) async {
    if (_isProcessingScan) return;
    if (_cameraService.isScanning && barcodes.isNotEmpty) {
      _isProcessingScan = true;
      final barcode = barcodes.first;
      final barcodeValue = barcode.rawValue ?? '';
      
      setState(() {
        _scannedBarcode = barcodeValue;
      });
      
      // Vibrer pour confirmer le scan (simulé)
      
      // Mettre en pause le scanner pendant la saisie et recherche
      await _stopScanner();

      // Activer l'overlay loader
      setState(() {
        _isLoadingProduct = true;
      });

      // Appeler le service OpenFoodFactsService avec l'EAN scanné
      OFFProduct? product;
      try {
        product = await _offService.lookupBarcode(barcodeValue);
      } catch (e) {
        print('Erreur lookup EAN Open Food Facts: $e');
      }

      // Désactiver l'overlay loader
      if (mounted) {
        setState(() {
          _isLoadingProduct = false;
        });
      }
      
      // Écran fermé pendant la recherche : plus rien à demander
      if (!mounted) return;

      // Conseil d'achat (prix relevés de ce produit et de sa catégorie)
      final advise = await _buildAdvisor(barcodeValue, product);
      if (!mounted) return;

      // Produit déjà vu : comparatif des magasins affiché dès le scan
      final knownPrices = await _knownPrices(barcodeValue);
      if (!mounted) return;

      // Demander le prix à l'utilisateur en passant le produit récupéré (ou null)
      final double? price = await showPriceInputSheet(
        context,
        barcodeValue,
        product,
        advise: advise,
        knownPrices: knownPrices,
        currentStore: _selectedStore,
      );
      
      if (price != null) {
        // Traiter le code scanné
        final scannedItem = ScannedItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: product?.name ?? 'Produit scanné ($barcodeValue)',
          brand: product?.brand ?? 'Marque inconnue',
          price: price,
          quantity: product?.quantity,
          unit: product?.unit,
          scanDate: DateTime.now(),
          barcode: barcodeValue,
          imageUrl: product?.imageUrl ?? 'https://via.placeholder.com/150x150/CCCCCC/000000?text=📦',
          storeName: _selectedStore,
          nutriscore: product?.nutriscore,
          categories: product?.categories,
        );
        
        widget.onItemScanned(scannedItem);
        
        // 💾 SAUVEGARDE AUTOMATIQUE (Solution robuste - Étape 5c)
        // Créer une session avec cet article unique et la persister immédiatement
        // Cela résout le problème où les articles ne sont pas visibles sans appuyer sur "Enregistrer"
        if (widget.repository != null) {
          final singleItemSession = ScanSession(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            items: [scannedItem],
            date: DateTime.now(),
            endDate: DateTime.now(),
            storeName: _selectedStore,
            type: 'barcode',
          );
          await widget.repository!.saveScan(singleItemSession);
          debugPrint('✅ [5c] Article sauvegardé automatiquement : ${scannedItem.name}');
          // Notifier le parent pour recharger les sessions
          await widget.onScanSaved?.call();
        }
        
        // Afficher notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.primary,
              content: Text(
                'Produit ajouté : ${price.toStringAsFixed(2)} €',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
      
      // Relancer le scanner
      await _startScanner();
      
      // Réinitialiser l'état
      if (mounted) {
        setState(() {
          _scannedBarcode = null;
          _isProcessingScan = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        leading: widget.onBack != null ? AppBackButton(onPressed: widget.onBack) : null,
        title: const NeonTitle(text: 'SCANNER', fontSize: 22),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppTheme.primary),
            onPressed: () => showMistralSettingsDialog(context, repository: widget.repository),
            tooltip: 'Paramètres API',
          ),
          IconButton(
            icon: Badge(
              label: Text(
                widget.scannedItems.length.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              backgroundColor: AppTheme.primary,
              textColor: Colors.white,
              child: const Icon(Icons.receipt_long, color: AppTheme.primary),
            ),
            onPressed: widget.onViewResults,
            tooltip: 'Résultats',
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.history, color: AppTheme.primary),
            onPressed: widget.onViewHistory,
            tooltip: 'Historique',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Étape 1 : le magasin (obligatoire avant de scanner)
          StoreSelector(
            stores: _stores,
            selectedStore: _selectedStore,
            lastStore: _lastStore,
            controller: _storeController,
            onSelected: _selectStore,
            onAdd: _addStore,
            onManage: _manageStores,
          ),

          // Sélecteur de mode de scan
          ScanModeSelector(isBarcodeMode: _isBarcodeMode, onChanged: _setBarcodeMode),

          // Zone de scan (Code-barres ou Ticket). Tant que la caméra ne tourne
          // pas (et hors traitement d'un code), rappel de l'étape en cours.
          Expanded(
            child: _isBarcodeMode && !_cameraService.isScanning && !_isProcessingScan
                ? ScanIdlePanel(store: _selectedStore, errorMessage: _errorMessage)
                : _isBarcodeMode
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      // Camera preview avec scanner
                      _cameraService.buildCameraPreview(
                        onDetect: (List<Barcode> barcodes) => _onBarcodeScanned(barcodes),
                        context: context,
                      ),
                      
                      // Effet de scan IA
                      if (_cameraService.isScanning)
                        AIScanEffect(
                          isActive: true,
                          width: MediaQuery.of(context).size.width * 0.8,
                          height: MediaQuery.of(context).size.width * 0.8 * 0.6,
                        ),
                      
                      // Overlay du scanner avec cadre
                      ScannerOverlay(
                        isScanning: _cameraService.isScanning,
                        scannedBarcode: _scannedBarcode,
                        errorMessage: _errorMessage ?? _cameraService.errorMessage,
                        isFlashOn: _cameraService.isTorchEnabled,
                        onGalleryTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppTheme.primary,
                              content: Text(
                                'Sélection depuis la galerie',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        onFlashToggle: _cameraService.isInitialized ? _toggleFlash : null,
                      ),
                      
                      // Loader de chargement API ("Recherche du produit...")
                      if (_isLoadingProduct)
                        Container(
                          color: Colors.black.withValues(alpha: 0.75),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(
                                  color: AppTheme.primary,
                                  strokeWidth: 3.5,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Recherche du produit...',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Connexion à Open Food Facts',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  )
                : TicketScanZone(
                    ticketImage: _ticketImage,
                    originalSize: _originalSize,
                    compressedSize: _compressedSize,
                    compressedImageBytes: _compressedImageBytes,
                    compressionMessage: _compressionMessage,
                    isCompressing: _isCompressing,
                    isProcessing: _isLoadingProduct,
                    errorMessage: _errorMessage,
                    onCapture: _captureTicket,
                    onCompress: _compressTicketImage,
                    onAnalyse: _processTicketImage,
                    onReset: _resetTicket,
                    canCapture: _selectedStore != null,
                  ),
          ),

          // Étape 2 : bouton SCANNER (mode code-barres), grisé sans magasin
          if (_isBarcodeMode)
            Padding(
              padding: const EdgeInsets.all(20),
              child: MagicButton(
                key: const ValueKey('scan_start_button'),
                text: _cameraService.isScanning ? 'ARRÊTER' : 'SCANNER',
                icon: _cameraService.isScanning ? Icons.stop : Icons.qr_code_scanner,
                onPressed: _cameraService.isScanning || _selectedStore != null
                    ? () async {
                        _buttonController.forward().then((_) => _buttonController.reverse());
                        if (_cameraService.isScanning) {
                          await _stopScanner();
                        } else {
                          await _startScanner();
                        }
                      }
                    : null,
                isLoading: false,
                isPrimary: true,
              ),
            ),
        ],
      ),
    );
  }
}
