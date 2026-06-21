import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets/scanner_overlay.dart';

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
  String _selectedStore = 'Carrefour';
  
  final TextEditingController _storeController = TextEditingController();
  late AnimationController _buttonController;
  late Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
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
      backgroundColor: AppTheme.backgroundLight,
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
                DropdownMenu<String>(
                  initialSelection: _selectedStore,
                  onSelected: (String? value) {
                    if (value != null) {
                      setState(() {
                        _selectedStore = value;
                        _storeController.text = value;
                      });
                    }
                  },
                  dropdownMenuEntries: [
                    'Carrefour',
                    'Auchan',
                    'Leclerc',
                    'Monoprix',
                    'Franprix',
                    'Biocoop',
                  ].map<DropdownMenuEntry<String>>((String value) {
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
              ],
            ),
          ),
          
          // Zone de scan
          Expanded(
            child: ScannerOverlay(
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
          ),
          
          // Bouton scanner
          Padding(
            padding: const EdgeInsets.all(20),
            child: AnimatedBuilder(
              animation: _buttonScale,
              builder: (context, child) {
                return Transform.scale(
                  scale: _buttonScale.value,
                  child: ElevatedButton.icon(
                    onPressed: _simulateScan,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.qr_code_scanner, size: 22),
                    label: Text(
                      _isScanning ? 'SCANNING...' : 'SCANNER',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
