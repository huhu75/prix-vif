import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../theme.dart';
import '../models.dart';
import '../widgets/scanner_overlay.dart';
import '../widgets/magic_button.dart';
import '../widgets/ai_scan_effect.dart';
import '../widgets/magic_title.dart';
import '../services/camera_service.dart';

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
      
      // Simuler l'extraction en local pour validation
      _simulateTicketArticles();
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la compression : ${e.toString()}';
        _isCompressing = false;
      });
    }
  }

  void _simulateTicketArticles() {
    final items = [
      ScannedItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_1',
        name: 'Lait Demi-Écrémé (Simulé)',
        brand: 'Lactel',
        price: 1.15,
        quantity: 2,
        unit: 'bouteille',
        scanDate: DateTime.now(),
        storeName: _selectedStore,
        imageUrl: 'https://world.openfoodfacts.org/images/products/328/122/011/5013/front_fr.3.400.jpg',
      ),
      ScannedItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_2',
        name: 'Pâtes Coquillettes (Simulé)',
        brand: 'Barilla',
        price: 1.89,
        quantity: 1,
        unit: 'paquet',
        scanDate: DateTime.now(),
        storeName: _selectedStore,
        imageUrl: 'https://world.openfoodfacts.org/images/products/807/680/951/3739/front_fr.114.400.jpg',
      ),
    ];

    for (var item in items) {
      widget.onItemScanned(item);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.secondary,
        content: const Text(
          'Ticket traité ! 2 articles simulés ajoutés.',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<double?> _showPriceInputDialog(String barcode) async {
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
                const SizedBox(height: 8),
                Text(
                  'Code-barres scanné : $barcode',
                  style: Theme.of(context).textTheme.bodyMedium,
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
      
      // Mettre en pause le scanner pendant la saisie
      await _stopScanner();
      
      // Demander le prix à l'utilisateur
      final double? price = await _showPriceInputDialog(barcodeValue);
      
      if (price != null) {
        // Traiter le code scanné
        final scannedItem = ScannedItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Produit scanné ($barcodeValue)',
          brand: 'Marque inconnue',
          price: price,
          quantity: 1,
          unit: 'unité',
          scanDate: DateTime.now(),
          barcode: barcodeValue,
          imageUrl: 'https://via.placeholder.com/150x150/CCCCCC/000000?text=📦',
          storeName: _selectedStore,
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
                        text: _compressedSize != null ? 'TRAITÉ' : 'OPTIMISER',
                        icon: _compressedSize != null ? Icons.done : Icons.bolt,
                        onPressed: _compressedSize != null ? null : _compressTicketImage,
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
