import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../theme.dart';
import '../models.dart';
import '../services/open_food_facts_service.dart';
import '../services/mistral_service.dart';
import '../widgets/scanner_overlay.dart';
import '../widgets/magic_button.dart';
import '../widgets/ai_scan_effect.dart';
import '../widgets/magic_title.dart';
import '../services/camera_service.dart';
import '../widgets/price_card.dart';

class ScanScreen extends StatefulWidget {
  final List<ScannedItem> scannedItems;
  final Function(ScannedItem) onItemScanned;
  final VoidCallback onViewResults;
  final VoidCallback onViewHistory;

  const ScanScreen({
    super.key,
    required this.scannedItems,
    required this.onItemScanned,
    required this.onViewResults,
    required this.onViewHistory,
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
  late String _selectedStore;
  bool _isProcessingScan = false;
  bool _isBarcodeMode = true;
  XFile? _ticketImage;
  final ImagePicker _picker = ImagePicker();
  int? _originalSize;
  int? _compressedSize;
  Uint8List? _compressedImageBytes;
  bool _isCompressing = false;
  final OpenFoodFactsService _offService = OpenFoodFactsService();
  bool _isLoadingProduct = false;
  
  // Service de caméra
  final CameraService _cameraService = CameraService();

  final TextEditingController _storeController = TextEditingController();
  final TextEditingController _newStoreController = TextEditingController();
  late AnimationController _buttonController;
  late Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedStore = _stores.first;
    _storeController.text = _selectedStore;
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _buttonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );
    
    // Démarrer la caméra automatiquement
    _startScanner();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Gérer le cycle de vie pour libérer/relancer la caméra
    if (state == AppLifecycleState.paused) {
      _stopScanner();
    } else if (state == AppLifecycleState.resumed) {
      // Redémarrer la caméra quand l'app revient au premier plan
      _startScanner();
    }
  }

  Future<void> _startScanner() async {
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
              borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
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
    final exists = _stores.any((s) => s.toLowerCase() == trimmed.toLowerCase());
    if (exists) {
      setState(() => _selectedStore = _stores.firstWhere(
        (s) => s.toLowerCase() == trimmed.toLowerCase(),
      ));
      return;
    }

    setState(() {
      final insertIndex = _stores.indexWhere((s) => s.toLowerCase().compareTo(trimmed.toLowerCase()) > 0);
      if (insertIndex == -1) {
        _stores.add(trimmed);
      } else {
        _stores.insert(insertIndex, trimmed);
      }
      _selectedStore = trimmed;
      _storeController.text = trimmed;
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
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la capture : ${e.toString()}';
      });
    }
  }

  Future<void> _compressTicketImage() async {
    if (_ticketImage == null) return;
    setState(() {
      _isCompressing = true;
    });

    try {
      final File imageFile = File(_ticketImage!.path);
      final originalBytes = await imageFile.readAsBytes();
      final int origSize = originalBytes.length;

      // Décoder l'image avec le package 'image'
      final img.Image? decodedImage = img.decodeImage(originalBytes);
      if (decodedImage == null) throw Exception('Impossible de décoder l\'image');

      // Redimensionner à max 1024px de large (si plus large)
      img.Image resizedImage = decodedImage;
      if (decodedImage.width > 1024) {
        resizedImage = img.copyResize(decodedImage, width: 1024);
      }

      // Compresser en JPEG 80%
      final compressedBytes = Uint8List.fromList(
        img.encodeJpg(resizedImage, quality: 80),
      );

      setState(() {
        _originalSize = origSize;
        _compressedSize = compressedBytes.length;
        _compressedImageBytes = compressedBytes;
        _isCompressing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la compression : ${e.toString()}';
        _isCompressing = false;
      });
    }
  }

  Future<void> _processTicketImage() async {
    if (_compressedImageBytes == null) return;
    setState(() {
      _isLoadingProduct = true;
      _errorMessage = null;
    });

    try {
      final mistralService = MistralService();
      // 1. Extraire les articles avec Mistral (ou mock)
      final extractedArticles = await mistralService.extractArticles(_compressedImageBytes!);

      // 2. Pour chaque article, rechercher sur Open Food Facts et récupérer le meilleur candidat + les autres candidats
      final List<ExtractedTicketItem> confirmationItems = [];

      for (var article in extractedArticles) {
        // Appeler Open Food Facts
        // Première passe: nom complet
        List<OFFProduct> candidates = await _offService.searchByName(article.name);
        
        // Deuxième passe si vide: nom nettoyé
        if (candidates.isEmpty) {
          final cleanedName = _offService.cleanProductName(article.name);
          if (cleanedName.isNotEmpty && cleanedName != article.name.toLowerCase()) {
            candidates = await _offService.searchByName(cleanedName);
          }
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
              storeName: _selectedStore,
              offService: _offService,
            );
          },
        );

        if (imported != null && imported.isNotEmpty) {
          for (var item in imported) {
            widget.onItemScanned(item);
          }

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

  Future<double?> _showPriceInputDialog(String barcode, OFFProduct? product) async {
    final TextEditingController priceController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Saisir le prix',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Card for product details if available, else fallback generic product layout
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Product Image
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: product?.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  product!.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.shopping_bag_outlined,
                                    color: AppTheme.textSecondary,
                                    size: 24,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.shopping_bag_outlined,
                                color: AppTheme.textSecondary,
                                size: 24,
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product?.name ?? 'Produit inconnu',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product?.brand ?? 'Marque inconnue',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (product?.nutriscore != null) ...[
                              const SizedBox(height: 6),
                              NutriScoreBadge(score: product!.nutriscore!),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                Text(
                  'Code-barres scanné : $barcode',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: priceController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accent,
                  ),
                  decoration: InputDecoration(
                    suffixText: '€',
                    suffixStyle: const TextStyle(fontSize: 24, color: AppTheme.accent),
                    hintText: '0.00',
                    hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.5)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez saisir un prix';
                    }
                    final doubleValue = double.tryParse(value.replaceAll(',', '.'));
                    if (doubleValue == null || doubleValue <= 0) {
                      return 'Veuillez saisir un prix valide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                MagicButton(
                  text: 'VALIDER',
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final price = double.parse(priceController.text.replaceAll(',', '.'));
                      Navigator.of(context).pop(price);
                    }
                  },
                  isPrimary: true,
                ),
              ],
            ),
          ),
        );
      },
    );
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
      
      // Demander le prix à l'utilisateur en passant le produit récupéré (ou null)
      final double? price = await _showPriceInputDialog(barcodeValue, product);
      
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



  Widget _buildModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: AppTheme.primary.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!_isBarcodeMode) {
                    setState(() {
                      _isBarcodeMode = true;
                      _ticketImage = null;
                    });
                    _startScanner();
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: _isBarcodeMode ? AppTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'CODE-BARRES',
                    style: TextStyle(
                      color: _isBarcodeMode ? AppTheme.backgroundDark : AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_isBarcodeMode) {
                    setState(() {
                      _isBarcodeMode = false;
                    });
                    _stopScanner();
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: !_isBarcodeMode ? AppTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'TICKET',
                    style: TextStyle(
                      color: !_isBarcodeMode ? AppTheme.backgroundDark : AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketScanZone() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.1), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: _ticketImage == null
          ? _buildTicketPlaceholder()
          : _buildTicketPreview(),
    );
  }

  Widget _buildTicketPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: AppTheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Photographier un ticket',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Prenez une photo de votre ticket pour extraire les prix des articles.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCameraButton(
                  icon: Icons.camera_alt,
                  label: 'Appareil photo',
                  onTap: () => _captureTicket(ImageSource.camera),
                ),
                const SizedBox(width: 12),
                _buildCameraButton(
                  icon: Icons.photo_library,
                  label: 'Galerie',
                  onTap: () => _captureTicket(ImageSource.gallery),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: AppTheme.surfaceLight,
        foregroundColor: AppTheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
        ),
      ),
    );
  }

  Widget _buildTicketPreview() {
    final double? ratio = (_originalSize != null && _compressedSize != null)
        ? (1.0 - (_compressedSize! / _originalSize!)) * 100
        : null;

    return Stack(
      children: [
        Positioned.fill(
          child: _compressedImageBytes != null
              ? Image.memory(
                  _compressedImageBytes!,
                  fit: BoxFit.cover,
                )
              : Image.file(
                  File(_ticketImage!.path),
                  fit: BoxFit.cover,
                ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.85),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isCompressing)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppTheme.primary),
                      SizedBox(height: 12),
                      Text(
                        'Compression en cours...',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              else ...[
                if (_compressedSize != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.compress, color: AppTheme.accent, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Optimisation Image (1024px, 80% JPEG)',
                              style: TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Taille originale : ${(_originalSize! / 1024).toStringAsFixed(1)} Ko',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        Text(
                          'Taille compressée : ${(_compressedSize! / 1024).toStringAsFixed(1)} Ko',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        Text(
                          'Gain : -${ratio!.toStringAsFixed(1)}% de bande passante',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _ticketImage = null;
                            _originalSize = null;
                            _compressedSize = null;
                            _compressedImageBytes = null;
                          });
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Reprendre'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MagicButton(
                        text: _compressedSize != null ? 'ANALYSER (IA)' : 'OPTIMISER',
                        icon: _compressedSize != null ? Icons.auto_awesome : Icons.bolt,
                        onPressed: _compressedSize != null ? _processTicketImage : _compressTicketImage,
                        isPrimary: true,
                        height: 48,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const NeonTitle(text: 'SCANNER', fontSize: 22),
        actions: [
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
          // Sélecteur de magasin
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Magasin',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownMenu<String>(
                        initialSelection: _selectedStore,
                        onSelected: (String? value) {
                          if (value != null) {
                            setState(() {
                              _selectedStore = value;
                              _storeController.text = value;
                            });
                          }
                        },
                        dropdownMenuEntries: _stores
                            .map<DropdownMenuEntry<String>>((String value) {
                          return DropdownMenuEntry<String>(
                            value: value,
                            label: value,
                          );
                        }).toList(),
                        width: double.infinity,
                        inputDecorationTheme: InputDecorationTheme(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          constraints: const BoxConstraints(minHeight: 48),
                          isDense: true,
                          filled: true,
                          fillColor: AppTheme.surfaceLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                          ),
                        ),
                        textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _AddStoreButton(
                      onAdd: _addStore,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Sélecteur de mode de scan
          _buildModeSelector(),
          
          // Zone de scan (Code-barres ou Ticket)
          Expanded(
            child: _isBarcodeMode
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
                          color: Colors.black.withOpacity(0.75),
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
                : _buildTicketScanZone(),
          ),
          
          // Bouton scanner magique (Uniquement en mode code-barres)
          if (_isBarcodeMode)
            Padding(
              padding: const EdgeInsets.all(20),
              child: MagicButton(
                text: _cameraService.isScanning ? 'ARRÊTER' : 'SCANNER',
                icon: _cameraService.isScanning ? Icons.stop : Icons.qr_code_scanner,
                onPressed: () async {
                  _buttonController.forward().then((_) => _buttonController.reverse());
                  if (_cameraService.isScanning) {
                    await _stopScanner();
                  } else {
                    await _startScanner();
                  }
                },
                isLoading: false,
                isPrimary: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _AddStoreButton extends StatefulWidget {
  final VoidCallback onAdd;
  const _AddStoreButton({required this.onAdd});

  @override
  State<_AddStoreButton> createState() => _AddStoreButtonState();
}

class _AddStoreButtonState extends State<_AddStoreButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onAdd();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Icon(Icons.add, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

// Modèle pour confirmation du ticket
class ExtractedTicketItem {
  final String rawName;
  final double price;
  final double quantity;
  OFFProduct? matchedProduct;
  List<OFFProduct> candidates;
  bool isSelected;

  ExtractedTicketItem({
    required this.rawName,
    required this.price,
    required this.quantity,
    this.matchedProduct,
    required this.candidates,
    this.isSelected = true,
  });
}

// Bottom Sheet de confirmation pour les articles du ticket
class TicketConfirmationSheet extends StatefulWidget {
  final List<ExtractedTicketItem> items;
  final String storeName;
  final OpenFoodFactsService offService;

  const TicketConfirmationSheet({
    super.key,
    required this.items,
    required this.storeName,
    required this.offService,
  });

  @override
  State<TicketConfirmationSheet> createState() => _TicketConfirmationSheetState();
}

class _TicketConfirmationSheetState extends State<TicketConfirmationSheet> {
  late List<ExtractedTicketItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.items;
  }

  double get _totalAmount => _items
      .where((item) => item.isSelected)
      .fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  int get _selectedCount => _items.where((item) => item.isSelected).length;

  Color _getNutriScoreColor(String grade) {
    switch (grade.trim().toLowerCase()) {
      case 'a':
        return const Color(0xFF038141);
      case 'b':
        return const Color(0xFF85BB2F);
      case 'c':
        return const Color(0xFFFECB02);
      case 'd':
        return const Color(0xFFEE8100);
      case 'e':
        return const Color(0xFFE63E11);
      default:
        return AppTheme.textMuted;
    }
  }

  Future<void> _showAlternativeProductsDialog(ExtractedTicketItem item) async {
    final searchController = TextEditingController(text: item.rawName);
    List<OFFProduct> searchResults = List.from(item.candidates);
    bool isSearching = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Associer un produit',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Rechercher sur Open Food Facts...',
                        suffixIcon: isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.search, color: AppTheme.primary),
                                onPressed: () async {
                                  setDialogState(() {
                                    isSearching = true;
                                  });
                                  try {
                                    final results = await widget.offService.searchByName(searchController.text);
                                    setDialogState(() {
                                      searchResults = results;
                                      isSearching = false;
                                    });
                                  } catch (e) {
                                    setDialogState(() {
                                      isSearching = false;
                                    });
                                  }
                                },
                              ),
                      ),
                      onSubmitted: (_) async {
                        setDialogState(() {
                          isSearching = true;
                        });
                        try {
                          final results = await widget.offService.searchByName(searchController.text);
                          setDialogState(() {
                            searchResults = results;
                            isSearching = false;
                          });
                        } catch (e) {
                          setDialogState(() {
                            isSearching = false;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: searchResults.isEmpty
                          ? Center(
                              child: Text(
                                isSearching ? 'Recherche en cours...' : 'Aucun produit trouvé.',
                                style: const TextStyle(color: AppTheme.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: searchResults.length,
                              itemBuilder: (context, idx) {
                                final prod = searchResults[idx];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: prod.imageUrl != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Image.network(
                                              prod.imageUrl!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const Icon(Icons.shopping_bag_outlined, color: AppTheme.textSecondary),
                                  ),
                                  title: Text(
                                    prod.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    prod.brand,
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: prod.nutriscore != null
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getNutriScoreColor(prod.nutriscore!),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            prod.nutriscore!.toUpperCase(),
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        )
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      item.matchedProduct = prod;
                                    });
                                    Navigator.of(dialogContext).pop();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Fermer', style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Validation du Ticket',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Vérifiez la correspondance des produits pour ${widget.storeName}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // Liste des articles
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun article extrait.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: item.isSelected 
                              ? AppTheme.surfaceLight.withOpacity(0.3)
                              : AppTheme.surfaceDark.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: item.isSelected 
                                ? AppTheme.primary.withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Checkbox d'importation
                            Checkbox(
                              value: item.isSelected,
                              activeColor: AppTheme.primary,
                              onChanged: (val) {
                                setState(() {
                                  item.isSelected = val ?? false;
                                });
                              },
                            ),
                            const SizedBox(width: 4),
                            
                            // Infos du produit matché ou brut
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Nom brut du ticket
                                  Text(
                                    item.rawName,
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      decoration: item.isSelected ? null : TextDecoration.lineThrough,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  
                                  // Fiche Produit matchée
                                  if (item.matchedProduct != null)
                                    Row(
                                      children: [
                                        Container(
                                          width: 45,
                                          height: 45,
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceDark,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: item.matchedProduct!.imageUrl != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Image.network(
                                                    item.matchedProduct!.imageUrl!,
                                                    fit: BoxFit.cover,
                                                  ),
                                                )
                                              : const Icon(Icons.shopping_bag_outlined, color: AppTheme.textSecondary, size: 20),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.matchedProduct!.name,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                item.matchedProduct!.brand,
                                                style: const TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 11,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (item.matchedProduct!.nutriscore != null) ...[
                                                const SizedBox(height: 4),
                                                NutriScoreBadge(score: item.matchedProduct!.nutriscore!),
                                              ]
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Row(
                                      children: [
                                        Container(
                                          width: 45,
                                          height: 45,
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceDark,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 22),
                                        ),
                                        const SizedBox(width: 10),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Aucun produit associé',
                                                style: TextStyle(
                                                  color: AppTheme.warning,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                'Le produit sera importé sans fiche OFF',
                                                style: TextStyle(
                                                  color: AppTheme.textMuted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 8),
                                  
                                  // Lien de modification de correspondance
                                  GestureDetector(
                                    onTap: () => _showAlternativeProductsDialog(item),
                                    child: Text(
                                      item.matchedProduct != null ? 'Modifier la correspondance' : 'Associer un produit',
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Prix & Quantité
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${(item.price * item.quantity).toStringAsFixed(2)} €',
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${item.quantity.toInt()} x ${item.price.toStringAsFixed(2)} €',
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          
          const SizedBox(height: 16),
          
          // Bouton d'importation
          MagicButton(
            text: 'IMPORTER $_selectedCount ARTICLES (${_totalAmount.toStringAsFixed(2)} €)',
            onPressed: _selectedCount == 0
                ? null 
                : () {
                    final List<ScannedItem> importedItems = [];
                    for (var item in _items) {
                      if (item.isSelected) {
                        importedItems.add(
                          ScannedItem(
                            id: '${DateTime.now().millisecondsSinceEpoch}_${item.rawName.hashCode}',
                            name: item.matchedProduct?.name ?? item.rawName,
                            brand: item.matchedProduct?.brand ?? 'Marque inconnue',
                            price: item.price,
                            quantity: item.matchedProduct?.quantity ?? item.quantity,
                            unit: item.matchedProduct?.unit ?? 'unité',
                            scanDate: DateTime.now(),
                            barcode: item.matchedProduct?.barcode,
                            imageUrl: item.matchedProduct?.imageUrl ?? 'https://via.placeholder.com/150x150/CCCCCC/000000?text=📦',
                            storeName: widget.storeName,
                            nutriscore: item.matchedProduct?.nutriscore,
                            categories: item.matchedProduct?.categories,
                          ),
                        );
                      }
                    }
                    Navigator.of(context).pop(importedItems);
                  },
            isPrimary: true,
          ),
        ],
      ),
    );
  }
}
