import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/product_analysis_models.dart';
import '../services/scan_repository.dart';
import '../utils/product_type_utils.dart';
import '../widgets/magic_title.dart';
import 'product_detail_screen.dart';

/// Écran de sélection de produit pour l'analyse
/// Permet à l'utilisateur de choisir un produit parmi ceux scannés
class ProductSelectionScreen extends StatefulWidget {
  final ScanRepository repository;

  const ProductSelectionScreen({
    super.key,
    required this.repository,
  });

  @override
  State<ProductSelectionScreen> createState() => _ProductSelectionScreenState();
}

class _ProductSelectionScreenState extends State<ProductSelectionScreen> {
  List<UniqueProductInfo> _products = [];
  List<UniqueProductInfo> _filteredProducts = [];
  String _searchQuery = '';
  String? _selectedType; // null = tous les types
  bool _isLoading = true;
  
  // Options de tri
  SortOption _sortOption = SortOption.name;
  
  /// Types de produit disponibles (catégorie OFF la plus spécifique), triés
  List<String> get _availableTypes {
    final types = <String>{};
    for (final product in _products) {
      final type = productTypeLabel(product.categories);
      if (type != uncategorizedTypeLabel) types.add(type);
    }
    final sorted = types.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }
  
  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    
    try {
      // Récupérer les produits uniques depuis le repository
      final rawProducts = widget.repository.getUniqueProducts();
      
      // Convertir en UniqueProductInfo
      final products = rawProducts.map((raw) => UniqueProductInfo(
        productId: raw['id'] as String,
        productName: raw['name'] as String,
        brand: raw['brand'] as String?,
        barcode: raw['barcode'] as String?,
        imageUrl: raw['imageUrl'] as String?,
        nutriscore: raw['nutriscore'] as String?,
        scanCount: raw['scanCount'] as int,
        averagePrice: (raw['averagePrice'] as num).toDouble(),
        lastScanDate: raw['lastScanDate'] as DateTime,
        storeNames: (raw['stores'] as List<dynamic>).cast<String>(),
        categories: (raw['categories'] as List<dynamic>?)?.cast<String>(),
      )).toList();
      
      setState(() {
        _products = products;
        _filteredProducts = products;
        _applySort();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Erreur chargement produits: $e');
    }
  }

  void _applySort() {
    switch (_sortOption) {
      case SortOption.name:
        _filteredProducts.sort((a, b) => a.productName.compareTo(b.productName));
        break;
      case SortOption.priceAsc:
        _filteredProducts.sort((a, b) => a.averagePrice.compareTo(b.averagePrice));
        break;
      case SortOption.priceDesc:
        _filteredProducts.sort((a, b) => b.averagePrice.compareTo(a.averagePrice));
        break;
      case SortOption.scanCount:
        _filteredProducts.sort((a, b) => b.scanCount.compareTo(a.scanCount));
        break;
      case SortOption.lastScan:
        _filteredProducts.sort((a, b) => b.lastScanDate.compareTo(a.lastScanDate));
        break;
    }
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _filterAndSortProducts();
  }

  void _onTypeSelected(String? type) {
    setState(() => _selectedType = type);
    _filterAndSortProducts();
  }

  void _onSortChanged(SortOption option) {
    setState(() {
      _sortOption = option;
      _filterAndSortProducts();
    });
  }

  void _filterAndSortProducts() {
    final query = _searchQuery.trim().toLowerCase();
    _filteredProducts = _products.where((product) {
      // Filtre par type de produit (catégorie OFF)
      if (_selectedType != null &&
          productTypeLabel(product.categories) != _selectedType) {
        return false;
      }
      // Sans recherche textuelle, le filtre par type suffit
      if (query.isEmpty) return true;
      // Recherche dans le nom, la marque, le code-barres ET les catégories
      // (permet de trouver un produit en tapant son type, ex: "lait")
      final nameMatch = product.productName.toLowerCase().contains(query);
      final brandMatch =
          product.brand?.toLowerCase().contains(query) ?? false;
      final barcodeMatch = product.barcode?.contains(_searchQuery) ?? false;
      final categoryMatch =
          product.categories?.any((c) => c.toLowerCase().contains(query)) ??
              false;
      return nameMatch || brandMatch || barcodeMatch || categoryMatch;
    }).toList();
    _applySort();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const NeonTitle(text: 'SÉLECTION PRODUIT', fontSize: 18),
        actions: [
          // Bouton de tri
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort, color: AppTheme.textPrimary),
            onSelected: _onSortChanged,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: SortOption.name,
                child: Text('Nom (A-Z)'),
              ),
              const PopupMenuItem(
                value: SortOption.priceAsc,
                child: Text('Prix (↑)'),
              ),
              const PopupMenuItem(
                value: SortOption.priceDesc,
                child: Text('Prix (↓)'),
              ),
              const PopupMenuItem(
                value: SortOption.scanCount,
                child: Text('Scans (↓)'),
              ),
              const PopupMenuItem(
                value: SortOption.lastScan,
                child: Text('Dernier scan (↓)'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            )
          : Column(
              children: [
                // Barre de recherche
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher un produit...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                
                // Filtre par type de produit (catégories Open Food Facts)
                if (_availableTypes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _TypeChip(
                            label: 'Tous',
                            selected: _selectedType == null,
                            onSelected: () => _onTypeSelected(null),
                          ),
                          ..._availableTypes.map((type) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _TypeChip(
                                  label: type,
                                  selected: _selectedType == type,
                                  onSelected: () => _onTypeSelected(type),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
                
                // En-tête de tri
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '(${_filteredProducts.length} produits${_selectedType != null ? ' · $_selectedType' : ''})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Tri : ${_sortOption.label}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                
                // Liste des produits
                Expanded(
                  child: _filteredProducts.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            return _ProductCard(
                              product: product,
                              onTap: () => _navigateToProductDetail(product),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.search_off,
              color: AppTheme.primary,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun produit trouvé',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _searchQuery.isEmpty && _selectedType == null
                  ? 'Aucun produit n\'a encore été scanné'
                  : 'Essayez une autre recherche ou un autre type',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToProductDetail(UniqueProductInfo product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          repository: widget.repository,
          productId: product.productId,
          productName: product.productName,
        ),
      ),
    );
  }
}

/// Options de tri
enum SortOption {
  name('Nom'),
  priceAsc('Prix croissant'),
  priceDesc('Prix décroissant'),
  scanCount('Nombre de scans'),
  lastScan('Dernier scan');

  final String label;
  
  const SortOption(this.label);
}

/// Chip de filtre par type de produit
class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.surfaceDark,
      labelStyle: TextStyle(
        color: selected ? AppTheme.backgroundDark : AppTheme.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(
        color: selected ? AppTheme.primary : AppTheme.surfaceLight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
    );
  }
}

/// Carte d'un produit dans la liste de sélection
class _ProductCard extends StatelessWidget {
  final UniqueProductInfo product;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storesText = product.storeNames.isEmpty
        ? 'Aucun magasin'
        : product.storeNames.length == 1
            ? product.storeNames.first
            : '${product.storeNames.length} magasins';
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppTheme.glassmorphism(),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Image du produit
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                image: product.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(product.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: product.imageUrl == null
                  ? Icon(
                      Icons.shopping_bag,
                      color: AppTheme.textMuted,
                      size: 28,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            
            // Infos produit
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.productName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.brand != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.brand!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Barcode
                  if (product.barcode != null) ...[
                    Text(
                      'EAN: ${product.barcode!}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  // Magasins
                  Text(
                    storesText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Type de produit (catégorie Open Food Facts)
                  if (isCategorized(product.categories)) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 12,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            productTypeLabel(product.categories),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Prix et stats
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${product.averagePrice.toStringAsFixed(2)} €',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.scanCount} scan${product.scanCount > 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
