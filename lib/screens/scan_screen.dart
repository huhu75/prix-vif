import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets/scanner_overlay.dart';

// 📷 Écran principal - Scanner
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
  
  // Animation pour le bouton scanner
  late AnimationController _buttonController;
  late Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  // Simulation du scan (fake data)
  Future<void> _simulateScan() async {
    if (_isScanning) return;
    
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });
    
    _buttonController.forward().then((_) => _buttonController.reverse());
    
    // Attendre 2 secondes pour simuler le scan
    await Future.delayed(const Duration(seconds: 2));
    
    // Générer un code fake
    final fakeBarcode = _generateFakeBarcode();
    
    setState(() {
      _scannedBarcode = fakeBarcode;
      _isScanning = false;
    });
    
    // Simuler la récupération des données du produit
    await Future.delayed(const Duration(milliseconds: 1000));
    
    final fakeItem = _generateFakeItem(fakeBarcode);
    widget.onItemScanned(fakeItem);
    
    setState(() {
      _scannedBarcode = null;
    });
    
    // Afficher un message de succès
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.primary,
        content: Text(
          'Produit scanné : ${fakeItem.name}',
          style: const TextStyle(color: AppTheme.backgroundDark),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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
      ),
    ];
    
    return products[DateTime.now().second % products.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('SCANNER'),
        actions: [
          // Bouton pour voir les résultats
          IconButton(
            icon: Badge(
              label: Text(
                widget.scannedItems.length.toString(),
                style: const TextStyle(color: AppTheme.backgroundDark, fontSize: 12),
              ),
              backgroundColor: AppTheme.primary,
              textColor: AppTheme.backgroundDark,
              child: const Icon(Icons.receipt_long, color: AppTheme.primary),
            ),
            onPressed: widget.onViewResults,
            tooltip: 'Voir les résultats',
          ),
          const SizedBox(width: 8),
          // Bouton historique
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: widget.onViewHistory,
            tooltip: 'Historique',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Fond - image floutée (simulation de caméra)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.backgroundDark,
                    AppTheme.surfaceDark,
                    AppTheme.backgroundDark,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Opacity(
                opacity: 0.1,
                child: Image.asset(
                  'assets/background.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey.shade900,
                          Colors.grey.shade800,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Contenu principal
          Column(
            children: [
              // Espacement pour l'AppBar
              SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),
              
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
                        backgroundColor: AppTheme.secondary,
                        content: Text(
                          'Sélection depuis la galerie (simulé)',
                          style: TextStyle(color: Colors.white),
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
              
              // Bouton principal de scan
              Padding(
                padding: const EdgeInsets.only(bottom: 32, left: 20, right: 20),
                child: AnimatedBuilder(
                  animation: _buttonScale,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _buttonScale.value,
                      child: ElevatedButton.icon(
                        onPressed: _simulateScan,
                        icon: _isScanning
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: AppTheme.backgroundDark,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.qr_code_scanner, size: 28),
                        label: Text(
                          _isScanning ? 'SCANNING...' : 'SCANNER UN CODE',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: AppTheme.backgroundDark,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          elevation: 8,
                          shadowColor: AppTheme.primary.withOpacity(0.4),
                          minimumSize: const Size(double.infinity, 60),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          
          // Aperçu des derniers articles scannés
          if (widget.scannedItems.isNotEmpty)
            Positioned(
              bottom: 120,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      'Derniers scans',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.scannedItems.length,
                      itemBuilder: (context, index) {
                        final item = widget.scannedItems[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            right: index == widget.scannedItems.length - 1 ? 0 : 12,
                          ),
                          child: _MiniPriceCard(item: item),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// 📋 Mini carte pour l'aperçu
class _MiniPriceCard extends StatelessWidget {
  final ScannedItem item;

  const _MiniPriceCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: item.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.formattedPrice,
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
