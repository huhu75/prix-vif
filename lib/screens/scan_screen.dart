import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets/scanner_overlay.dart';
import '../widgets/magic_button.dart';
import '../widgets/ai_scan_effect.dart';

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

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  bool _isFlashOn = false;
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

  final TextEditingController _storeController = TextEditingController();
  final TextEditingController _newStoreController = TextEditingController();
  late AnimationController _buttonController;
  late Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();
    _selectedStore = _stores.first;
    _storeController.text = _selectedStore;
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _buttonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
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
          FilledButton(
            onPressed: () {
              final name = _newStoreController.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(dialogContext).pop(name);
              }
            },
            child: const Text('Ajouter'),
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

  Future<void> _simulateScan() async {
    if (_isScanning) return;
    
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });
    
    _buttonController.forward().then((_) => _buttonController.reverse());
    
    await Future.delayed(const Duration(seconds: 2));
    
    final fakeBarcode = _generateFakeBarcode();
    
    setState(() {
      _scannedBarcode = fakeBarcode;
      _isScanning = false;
    });
    
    await Future.delayed(const Duration(milliseconds: 1000));
    
    final fakeItem = _generateFakeItem(fakeBarcode);
    widget.onItemScanned(fakeItem);
    
    setState(() {
      _scannedBarcode = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.primary,
        content: Text(
          'Produit scanné : ${fakeItem.name}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  String _generateFakeBarcode() {
    final prefixes = ['300', '301', '302', '303', '304', '305', '306', '307', '308', '309'];
    final random = DateTime.now().millisecondsSinceEpoch;
    final prefix = prefixes[random % prefixes.length];
    final suffix = (100000000 + random % 900000000).toString();
    return '$prefix$suffix';
  }

  ScannedItem _generateFakeItem(String barcode) {
    final products = [
      ScannedItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Lait Demi-Écrémé UHT',
        brand: 'Candia',
        price: 1.49 + (DateTime.now().second % 50) / 100.0,
        quantity: 1,
        unit: 'L',
        scanDate: DateTime.now(),
        barcode: barcode,
        imageUrl: 'https://via.placeholder.com/150x150/E6F3FF/000000?text=🥛',
        storeName: _selectedStore,
      ),
      ScannedItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Pain de Mie Brioché',
        brand: 'Brioché Doré',
        price: 2.99 + (DateTime.now().second % 50) / 100.0,
        quantity: 500,
        unit: 'g',
        scanDate: DateTime.now(),
        barcode: barcode,
        imageUrl: 'https://via.placeholder.com/150x150/FFF8E1/000000?text=🍞',
        storeName: _selectedStore,
      ),
      ScannedItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Eau Minérale Naturelle',
        brand: 'Evian',
        price: 0.89 + (DateTime.now().second % 30) / 100.0,
        quantity: 1.5,
        unit: 'L',
        scanDate: DateTime.now(),
        barcode: barcode,
        imageUrl: 'https://via.placeholder.com/150x150/E0F7FA/000000?text=💧',
        storeName: _selectedStore,
      ),
      ScannedItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Café Moulu Arabica',
        brand: 'Nescafé',
        price: 4.50 + (DateTime.now().second % 80) / 100.0,
        quantity: 250,
        unit: 'g',
        scanDate: DateTime.now(),
        barcode: barcode,
        imageUrl: 'https://via.placeholder.com/150x150/FFF3E0/000000?text=☕',
        storeName: _selectedStore,
      ),
      ScannedItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Pâtes Spaghetti',
        brand: 'Barilla',
        price: 1.89 + (DateTime.now().second % 40) / 100.0,
        quantity: 500,
        unit: 'g',
        scanDate: DateTime.now(),
        barcode: barcode,
        imageUrl: 'https://via.placeholder.com/150x150/FFF8E1/000000?text=🍝',
        storeName: _selectedStore,
      ),
      ScannedItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Chocolat Noir 70%',
        brand: 'Lindt',
        price: 2.49 + (DateTime.now().second % 60) / 100.0,
        quantity: 100,
        unit: 'g',
        scanDate: DateTime.now(),
        barcode: barcode,
        imageUrl: 'https://via.placeholder.com/150x150/D2B48C/000000?text=🍫',
        storeName: _selectedStore,
      ),
      ScannedItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Jus d\'Orange Pressé',
        brand: 'Tropicana',
        price: 2.29 + (DateTime.now().second % 45) / 100.0,
        quantity: 1,
        unit: 'L',
        scanDate: DateTime.now(),
        barcode: barcode,
        imageUrl: 'https://via.placeholder.com/150x150/FFE0B2/000000?text=🍊',
        storeName: _selectedStore,
      ),
      ScannedItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Yaourt Nature',
        brand: 'Danone',
        price: 0.59 + (DateTime.now().second % 20) / 100.0,
        quantity: 4,
        unit: 'x 125g',
        scanDate: DateTime.now(),
        barcode: barcode,
        imageUrl: 'https://via.placeholder.com/150x150/FFFFFF/000000?text=🥛',
        storeName: _selectedStore,
      ),
    ];
    
    return products[DateTime.now().second % products.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('SCANNER'),
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
                // Effet de scan IA
                if (_isScanning)
                  AIScanEffect(
                    isActive: true,
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.width * 0.8 * 0.6,
                  ),
                // Overlay du scanner
                ScannerOverlay(
                  isScanning: _isScanning,
                  scannedBarcode: _scannedBarcode,
                  errorMessage: _errorMessage,
                  isFlashOn: _isFlashOn,
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
                  onFlashToggle: () {
                    setState(() {
                      _isFlashOn = !_isFlashOn;
                    });
                  },
                ),
              ],
            ),
          ),
          
          // Bouton scanner magique
          Padding(
            padding: const EdgeInsets.all(20),
            child: MagicButton(
              text: _isScanning ? 'SCANNING...' : 'SCANNER UN CODE',
              icon: Icons.qr_code_scanner,
              onPressed: _simulateScan,
              isLoading: _isScanning,
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
