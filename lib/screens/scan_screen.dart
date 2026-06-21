import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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

  void _onBarcodeScanned(List<Barcode> barcodes) {
    if (_cameraService.isScanning && barcodes.isNotEmpty) {
      final barcode = barcodes.first;
      final barcodeValue = barcode.rawValue ?? '';
      
      setState(() {
        _scannedBarcode = barcodeValue;
      });
      
      // Vibrer pour confirmer le scan (simulé)
      // Sur mobile réel, on pourrait utiliser Vibrate.vibrate
      
      // Traiter le code scanné
      final scannedItem = ScannedItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Produit scanné',
        brand: 'Marque inconnue',
        price: 0.0,
        quantity: 1,
        unit: 'unité',
        scanDate: DateTime.now(),
        barcode: barcodeValue,
        imageUrl: 'https://via.placeholder.com/150x150/CCCCCC/000000?text=📦',
        storeName: _selectedStore,
      );
      
      widget.onItemScanned(scannedItem);
      
      // Afficher notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primary,
          content: Text(
            'Code scanné : $barcodeValue',
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
      
      // Réinitialiser après un court délai
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _scannedBarcode = null;
          });
        }
      });
    }
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
          
          // Zone de scan avec effet IA
          Expanded(
            child: Stack(
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
            ),
          ),
          
          // Bouton scanner magique
          Padding(
            padding: const EdgeInsets.all(20),
            child: MagicButton(
              text: _cameraService.isInitialized ? 'ARRÊTER' : 'SCANNER',
              icon: _cameraService.isInitialized ? Icons.stop : Icons.qr_code_scanner,
              onPressed: () async {
                _buttonController.forward().then((_) => _buttonController.reverse());
                if (_cameraService.isInitialized) {
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
