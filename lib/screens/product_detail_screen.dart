import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/product_analysis_models.dart';
import '../services/scan_repository.dart';
import '../services/open_food_facts_service.dart';
import '../services/product_analysis_service.dart';
import '../widgets/off_match_sheet.dart';
import '../widgets/product_detail/price_evolution_tab.dart';
import '../widgets/product_detail/product_info_tab.dart';
import '../widgets/product_detail/similar_products_tab.dart';
import '../widgets/product_detail/store_comparison_tab.dart';

/// Écran de détails d'un produit avec analyse complète
/// Contient 3 onglets : Évolution des prix, Comparaison magasins, Produits similaires
class ProductDetailScreen extends StatefulWidget {
  final ScanRepository repository;
  final String productId;
  final String productName;
  final int initialTabIndex;

  /// Service de chargement (remplaçable dans les tests pour éviter le réseau)
  final ProductAnalysisService? analysisService;

  /// Recherche Open Food Facts pour corriger la correspondance (remplaçable dans les tests)
  final Future<List<OFFProduct>> Function(String query)? offSearch;

  /// Appelé après une suppression ou une correction (pour recharger le Dashboard)
  final Future<void> Function()? onChanged;

  const ProductDetailScreen({
    super.key,
    required this.repository,
    required this.productId,
    required this.productName,
    this.initialTabIndex = 0,
    this.analysisService,
    this.offSearch,
    this.onChanged,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  ProductAnalysisResult? _analysisResult;
  OFFProduct? _offProduct;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = widget.analysisService ?? ProductAnalysisService(widget.repository);
      final data = await service.load(widget.productId, widget.productName);
      if (!mounted) return;
      setState(() {
        _offProduct = data.offProduct;
        _analysisResult = data.analysis;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Erreur lors du chargement de l\'analyse : $e';
      });
      debugPrint('Erreur analyse produit: $e');
    }
  }

  Future<void> _handleStoreDeleted(String storeName) async {
    // Supprimer le magasin du produit
    try {
      await widget.repository.removeStoreFromProduct(storeName, widget.productId);
      
      // Recharger l'analyse pour mettre à jour l'UI
      await _loadAnalysis();
      
      // Afficher un message de confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('Magasin "$storeName" supprimé avec succès'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur suppression magasin: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Erreur lors de la suppression du magasin: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Supprime le produit (tous ses scans) après confirmation
  Future<void> _deleteProduct() async {
    final count = widget.repository.countProductArticles(widget.productId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text('Supprimer « ${widget.productName} » ?'),
        content: Text(
          '$count scan${count > 1 ? 's' : ''} de ce produit ${count > 1 ? 'seront retirés' : 'sera retiré'} '
          'de l\'historique et du tableau de bord. Vous ne pourrez pas annuler.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          FilledButton(
            key: const ValueKey('confirm_delete_product'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final removed = await widget.repository.deleteProduct(widget.productId);
    await widget.onChanged?.call();
    navigator.pop(true);
    messenger.showSnackBar(SnackBar(
      content: Text('« ${widget.productName} » supprimé ($removed scan${removed > 1 ? 's' : ''})'),
      duration: const Duration(seconds: 3),
    ));
  }

  /// Rattache le produit à une autre fiche Open Food Facts
  Future<void> _rematchProduct() async {
    final search = widget.offSearch ??
        (OpenFoodFactsService()..setRepository(widget.repository)).searchProducts;
    final chosen = await showOffMatchSheet(context, initialQuery: widget.productName, search: search);
    if (chosen == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final updated = await widget.repository.rematchProduct(
      widget.productId,
      name: chosen.name,
      brand: chosen.brand.isEmpty ? null : chosen.brand,
      barcode: chosen.barcode.isEmpty ? null : chosen.barcode,
      imageUrl: chosen.imageUrl,
      nutriscore: chosen.nutriscore,
      categories: chosen.categories.isEmpty ? null : chosen.categories,
      packQuantity: chosen.quantity,
      packUnit: chosen.unit,
    );
    await widget.onChanged?.call();

    // L'identifiant du produit a changé (nouveau code-barres) : rouvrir sa fiche
    navigator.pushReplacement(MaterialPageRoute(
      builder: (_) => ProductDetailScreen(
        repository: widget.repository,
        productId: chosen.barcode.isNotEmpty ? chosen.barcode : chosen.name,
        productName: chosen.name,
        analysisService: widget.analysisService,
        offSearch: widget.offSearch,
        onChanged: widget.onChanged,
      ),
    ));
    messenger.showSnackBar(SnackBar(
      content: Text('$updated scan${updated > 1 ? 's' : ''} rattaché${updated > 1 ? 's' : ''} à « ${chosen.name} »'),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    if (_error != null) {
      return _buildErrorState(_error!);
    }
    
    if (_analysisResult == null) {
      return _buildEmptyState();
    }
    
    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          title: Text(
            _analysisResult!.productName.toUpperCase(),
            style: const TextStyle(fontSize: 18),
            overflow: TextOverflow.ellipsis,
          ),
          bottom: const TabBar(
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: [
              Tab(
                icon: Icon(Icons.info_outline),
                text: 'Fiche',
              ),
              Tab(
                icon: Icon(Icons.trending_up),
                text: 'Évolution',
              ),
              Tab(
                icon: Icon(Icons.store),
                text: 'Magasins',
              ),
              Tab(
                icon: Icon(Icons.compare),
                text: 'Similaires',
              ),
            ],
          ),
          actions: [
            // Bouton pour rafraîchir
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.textPrimary),
              onPressed: _loadAnalysis,
            ),
            PopupMenuButton<String>(
              key: const ValueKey('product_actions'),
              icon: const Icon(Icons.more_vert, color: AppTheme.textPrimary),
              onSelected: (action) => action == 'delete' ? _deleteProduct() : _rematchProduct(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'rematch',
                  child: ListTile(
                    leading: Icon(Icons.find_replace),
                    title: Text('Corriger le produit Open Food Facts'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: AppTheme.error),
                    title: Text('Supprimer ce produit', style: TextStyle(color: AppTheme.error)),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // Onglet 0 : Fiche détaillée Open Food Facts
            ProductInfoTab(
              product: _offProduct,
              analysis: _analysisResult!,
              onRematch: _rematchProduct,
              onDelete: _deleteProduct,
            ),

            // Onglet 1 : Évolution des prix
            PriceEvolutionTab(analysis: _analysisResult!),
            
            // Onglet 2 : Comparaison par magasin
            StoreComparisonTab(
              analysis: _analysisResult!,
              onStoreDeleted: _handleStoreDeleted,
            ),
            
            // Onglet 3 : Produits similaires
            SimilarProductsTab(
              analysis: _analysisResult!,
              repository: widget.repository,
              onChanged: widget.onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(widget.productName.toUpperCase()),
      ),
      body: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(widget.productName.toUpperCase()),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.error,
                color: Colors.red,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Erreur',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _loadAnalysis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(widget.productName.toUpperCase()),
      ),
      body: Center(
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
                Icons.analytics,
                color: AppTheme.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucune donnée disponible',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Aucun scan trouvé pour ce produit',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
