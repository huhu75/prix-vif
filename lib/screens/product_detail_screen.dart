import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/product_analysis_models.dart';
import '../services/scan_repository.dart';
import '../services/open_food_facts_service.dart';
import '../services/product_analysis_service.dart';
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

  const ProductDetailScreen({
    super.key,
    required this.repository,
    required this.productId,
    required this.productName,
    this.initialTabIndex = 0,
    this.analysisService,
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
          ],
        ),
        body: TabBarView(
          children: [
            // Onglet 0 : Fiche détaillée Open Food Facts
            ProductInfoTab(product: _offProduct, analysis: _analysisResult!),

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
