import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models/hive_models.dart';
import '../models/product_analysis_models.dart';
import '../services/scan_repository.dart';
import '../services/open_food_facts_service.dart';

/// Écran de détails d'un produit avec analyse complète
/// Contient 3 onglets : Évolution des prix, Comparaison magasins, Produits similaires
class ProductDetailScreen extends StatefulWidget {
  final ScanRepository repository;
  final String productId;
  final String productName;
  final int initialTabIndex;

  const ProductDetailScreen({
    super.key,
    required this.repository,
    required this.productId,
    required this.productName,
    this.initialTabIndex = 0,
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
      // Récupérer toutes les données pour ce produit
      final historyByStore = widget.repository.getPriceHistoryByStore(widget.productId);
      final allArticles = widget.repository.getAllStoredArticles();
      
      // Trouver le produit de référence
      StoredArticle? referenceArticle;
      for (final article in allArticles) {
        if (article.id == widget.productId || 
            article.barcode == widget.productId ||
            article.name == widget.productName) {
          referenceArticle = article;
          break;
        }
      }
      
      // Construire l'historique par magasin
      final priceHistoryByStore = <String, ProductPriceHistory>{};
      
      for (final entry in historyByStore.entries) {
        final storeName = entry.key;
        final rawPoints = entry.value;
        
        final pricePoints = rawPoints.map((raw) => PricePoint(
          date: DateTime.parse(raw['date'] as String),
          price: (raw['price'] as num).toDouble(),
          quantity: (raw['quantity'] as num?)?.toDouble(),
          unit: raw['unit'] as String?,
          articleId: raw['id'] as String,
        )).toList();
        
        priceHistoryByStore[storeName] = ProductPriceHistory(
          productId: widget.productId,
          productName: widget.productName,
          barcode: referenceArticle?.barcode,
          brand: referenceArticle?.brand,
          storeName: storeName,
          pricePoints: pricePoints,
        );
      }
      
      // Construire la comparaison entre magasins
      final storePrices = <String, StorePriceInfo>{};
      
      for (final entry in historyByStore.entries) {
        final storeName = entry.key;
        final rawPoints = entry.value;
        
        if (rawPoints.isNotEmpty) {
          final prices = rawPoints.map((p) => p['price'] as double).toList();
          final avgPrice = prices.reduce((a, b) => a + b) / prices.length;
          final lastPrice = rawPoints.last['price'] as double;
          final lastScanDate = DateTime.parse(rawPoints.last['date'] as String);
          
          storePrices[storeName] = StorePriceInfo(
            storeName: storeName,
            averagePrice: avgPrice,
            lastPrice: lastPrice,
            lastScanDate: lastScanDate,
            scanCount: rawPoints.length,
            barcode: referenceArticle?.barcode,
          );
        }
      }
      
      final storeComparison = StorePriceComparison(
        productId: widget.productId,
        productName: widget.productName,
        barcode: referenceArticle?.barcode,
        brand: referenceArticle?.brand,
        storePrices: storePrices,
      );
      
      // Récupérer les produits similaires
      SimilarProductsComparison? similarProducts;
      if (referenceArticle != null) {
        final rawSimilar = widget.repository.getSimilarProducts(
          widget.productId,
          category: referenceArticle.categories?.isNotEmpty == true
              ? referenceArticle.categories!.first
              : null,
        );
        
        final similarList = rawSimilar.map((raw) => SimilarProductInfo(
          productId: raw['id'] as String,
          productName: raw['name'] as String,
          brand: raw['brand'] as String?,
          barcode: raw['barcode'] as String?,
          storeName: raw['storeName'] as String?,
          price: (raw['price'] as num).toDouble(),
          scanDate: raw['scanDate'] as DateTime,
          nutriscore: raw['nutriscore'] as String?,
          imageUrl: raw['imageUrl'] as String?,
          categories: (raw['categories'] as List<dynamic>?)?.cast<String>(),
        )).toList();
        
        if (similarList.isNotEmpty) {
          similarProducts = SimilarProductsComparison(
            category: referenceArticle.categories?.first ?? 'Produits similaires',
            referenceProductId: widget.productId,
            similarProducts: similarList,
          );
        }
      }

      // Récupérer les informations détaillées en ligne (ou cache) via OpenFoodFacts
      OFFProduct? offProduct;
      final barcode = referenceArticle?.barcode ?? (RegExp(r'^\d+$').hasMatch(widget.productId) ? widget.productId : null);
      if (barcode != null && barcode.isNotEmpty) {
        final offService = OpenFoodFactsService()..setRepository(widget.repository);
        offProduct = await offService.lookupBarcode(barcode);
      }

      if (offProduct == null && referenceArticle != null) {
        offProduct = OFFProduct(
          barcode: referenceArticle.barcode ?? '',
          name: referenceArticle.name,
          brand: referenceArticle.brand ?? 'Marque inconnue',
          nutriscore: referenceArticle.nutriscore,
          categories: referenceArticle.categories ?? [],
          imageUrl: referenceArticle.imageUrl,
          allergens: [],
          nutrientLevels: {},
          nutriments: {},
        );
      }
      
      setState(() {
        _offProduct = offProduct;
        _analysisResult = ProductAnalysisResult(
          productId: widget.productId,
          productName: widget.productName,
          barcode: referenceArticle?.barcode,
          brand: referenceArticle?.brand,
          imageUrl: referenceArticle?.imageUrl,
          nutriscore: referenceArticle?.nutriscore,
          categories: referenceArticle?.categories,
          priceHistoryByStore: priceHistoryByStore,
          storeComparison: storeComparison,
          similarProducts: similarProducts,
        );
        _isLoading = false;
      });
    } catch (e) {
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
            _ProductInfoTab(product: _offProduct, analysis: _analysisResult!),

            // Onglet 1 : Évolution des prix
            _PriceEvolutionTab(analysis: _analysisResult!),
            
            // Onglet 2 : Comparaison par magasin
            _StoreComparisonTab(
              analysis: _analysisResult!,
              onStoreDeleted: _handleStoreDeleted,
            ),
            
            // Onglet 3 : Produits similaires
            _SimilarProductsTab(
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
                color: Colors.red.withOpacity(0.1),
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
                color: AppTheme.primary.withOpacity(0.1),
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

// ==========================================
// ONGLET 1 : ÉVOLUTION DES PRIX
// ==========================================

class _PriceEvolutionTab extends StatelessWidget {
  final ProductAnalysisResult analysis;

  const _PriceEvolutionTab({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Si un seul magasin, afficher directement son historique
    if (analysis.priceHistoryByStore.length == 1) {
      final storeName = analysis.priceHistoryByStore.keys.first;
      final history = analysis.priceHistoryByStore[storeName]!;
      return _SingleStorePriceHistory(history: history);
    }
    
    // Sinon, proposer de sélectionner un magasin et montrer un graphique combiné
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tendance globale
          _GlobalTrendCard(analysis: analysis),
          const SizedBox(height: 24),
          
          // Graphique combiné de tous les magasins
          Text(
            'Comparatif de l\'évolution des prix',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _CombinedPriceEvolutionChart(analysis: analysis),
          const SizedBox(height: 24),
          
          // Sélecteur de magasin
          Text(
            'Historique détaillé par magasin',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          
          ...analysis.priceHistoryByStore.entries.map((entry) {
            final storeName = entry.key;
            final history = entry.value;
            return _StoreSelectionCard(
              storeName: storeName,
              history: history,
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppTheme.backgroundDark,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) => DraggableScrollableSheet(
                    initialChildSize: 0.75,
                    minChildSize: 0.5,
                    maxChildSize: 0.95,
                    expand: false,
                    builder: (context, scrollController) => SingleChildScrollView(
                      controller: scrollController,
                      child: _SingleStorePriceHistory(history: history),
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}

class _CombinedPriceEvolutionChart extends StatelessWidget {
  final ProductAnalysisResult analysis;

  const _CombinedPriceEvolutionChart({required this.analysis});

  @override
  Widget build(BuildContext context) {
    // Générer une série de courbes par magasin
    final List<CartesianSeries> seriesList = [];
    final List<Color> lineColors = [
      AppTheme.primary,
      AppTheme.secondary,
      AppTheme.accent,
      Colors.green,
      Colors.orange,
      Colors.pink,
    ];
    
    int colorIdx = 0;

    for (final entry in analysis.priceHistoryByStore.entries) {
      final storeName = entry.key;
      final history = entry.value.sortedByDate();
      final color = lineColors[colorIdx % lineColors.length];
      colorIdx++;

      seriesList.add(
        LineSeries<PricePoint, String>(
          name: storeName,
          dataSource: history.pricePoints,
          xValueMapper: (point, _) => '${point.date.day}/${point.date.month}',
          yValueMapper: (point, _) => point.price,
          color: color,
          width: 2,
          markerSettings: MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
            borderWidth: 1,
            borderColor: color,
          ),
          dataLabelSettings: const DataLabelSettings(
            isVisible: false,
          ),
        ),
      );
    }

    return Container(
      decoration: AppTheme.glassmorphism(),
      padding: const EdgeInsets.all(16),
      height: 250,
      child: SfCartesianChart(
        legend: Legend(
          isVisible: true,
          position: LegendPosition.bottom,
          textStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
        ),
        primaryXAxis: CategoryAxis(
          labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
          axisLine: const AxisLine(color: AppTheme.surfaceLight, width: 1),
          majorGridLines: const MajorGridLines(color: AppTheme.surfaceLight, width: 1),
        ),
        primaryYAxis: NumericAxis(
          labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
          axisLine: const AxisLine(color: AppTheme.surfaceLight, width: 1),
          majorGridLines: const MajorGridLines(color: AppTheme.surfaceLight, width: 1),
          numberFormat: NumberFormat.currency(symbol: '€', decimalDigits: 2),
        ),
        series: seriesList,
      ),
    );
  }
}

class _GlobalTrendCard extends StatelessWidget {
  final ProductAnalysisResult analysis;

  const _GlobalTrendCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trend = analysis.overallTrend;
    
    return Container(
      decoration: AppTheme.glassmorphism(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: trend.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(trend.icon, color: trend.color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tendance globale',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trend.label,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: trend.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.surfaceLight, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TrendStatCard(
                label: 'Magasins',
                value: analysis.priceHistoryByStore.length.toString(),
                icon: Icons.store,
              ),
              _TrendStatCard(
                label: 'Prix moyen',
                value: analysis.storeComparison.storePrices.isNotEmpty
                    ? '${analysis.storeComparison.storePrices.values.first.averagePrice.toStringAsFixed(2)} €'
                    : 'N/A',
                icon: Icons.euro,
              ),
              _TrendStatCard(
                label: 'Total scans',
                value: analysis.priceHistoryByStore.values
                    .fold(0, (sum, h) => sum + h.pricePoints.length)
                    .toString(),
                icon: Icons.analytics,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _TrendStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.textMuted, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _SingleStorePriceHistory extends StatelessWidget {
  final ProductPriceHistory history;

  const _SingleStorePriceHistory({required this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedHistory = history.sortedByDate();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec tendance
          Container(
            decoration: AppTheme.glassmorphism(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: history.trend.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(history.trend.icon, color: history.trend.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Magasin : ${history.storeName}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tendance : ${history.trend.label} (${history.priceEvolutionPercent.toStringAsFixed(1)}%)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: history.trend.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppTheme.surfaceLight),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PriceStat(
                      label: 'Premier prix',
                      value: history.firstPrice?.toStringAsFixed(2) ?? 'N/A',
                    ),
                    _PriceStat(
                      label: 'Dernier prix',
                      value: history.lastPrice?.toStringAsFixed(2) ?? 'N/A',
                    ),
                    _PriceStat(
                      label: 'Moyenne',
                      value: history.averagePrice.toStringAsFixed(2),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Graphique d'évolution
          if (sortedHistory.pricePoints.length >= 2) ...[
            Text(
              'Évolution du prix dans le temps',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: AppTheme.glassmorphism(),
              padding: const EdgeInsets.all(16),
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                  labelStyle: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                  axisLine: const AxisLine(
                    color: AppTheme.surfaceLight,
                    width: 1,
                  ),
                  majorGridLines: const MajorGridLines(
                    color: AppTheme.surfaceLight,
                    width: 1,
                  ),
                ),
                primaryYAxis: NumericAxis(
                  labelStyle: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                  axisLine: const AxisLine(
                    color: AppTheme.surfaceLight,
                    width: 1,
                  ),
                  majorGridLines: const MajorGridLines(
                    color: AppTheme.surfaceLight,
                    width: 1,
                  ),
                  numberFormat: NumberFormat.currency(
                    symbol: '€',
                    decimalDigits: 2,
                  ),
                ),
                series: <CartesianSeries>[
                  LineSeries<PricePoint, String>(
                    dataSource: sortedHistory.pricePoints,
                    xValueMapper: (point, _) => 
                        '${point.date.day}/${point.date.month}',
                    yValueMapper: (point, _) => point.price,
                    color: AppTheme.primary,
                    width: 2,
                    markerSettings: const MarkerSettings(
                      isVisible: true,
                      shape: DataMarkerType.circle,
                      borderWidth: 2,
                      borderColor: AppTheme.primary,
                    ),
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelAlignment: ChartDataLabelAlignment.top,
                      textStyle: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Tableau des prix
          Text(
            'Historique des prix',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: AppTheme.glassmorphism(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // En-tête du tableau
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Date',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Prix',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Qté',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: AppTheme.surfaceLight, height: 1),
                const SizedBox(height: 8),
                // Lignes du tableau
                ...sortedHistory.pricePoints.map((point) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${point.date.day}/${point.date.month}/${point.date.year}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${point.price.toStringAsFixed(2)} €',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          point.quantity != null ? '${point.quantity} ${point.unit ?? ''}' : '-',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceStat extends StatelessWidget {
  final String label;
  final String value;

  const _PriceStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _StoreSelectionCard extends StatelessWidget {
  final String storeName;
  final ProductPriceHistory history;
  final VoidCallback onTap;

  const _StoreSelectionCard({
    required this.storeName,
    required this.history,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppTheme.glassmorphism(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    storeName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${history.averagePrice.toStringAsFixed(2)} €',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${history.pricePoints.length} scans',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  history.trend.icon,
                  color: history.trend.color,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${history.trend.label} (${history.priceEvolutionPercent.toStringAsFixed(1)}%)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: history.trend.color,
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

// ==========================================
// ONGLET 2 : COMPARAISON PAR MAGASIN
// ==========================================

class _StoreComparisonTab extends StatelessWidget {
  final ProductAnalysisResult analysis;
  final Function(String) onStoreDeleted;

  const _StoreComparisonTab({
    required this.analysis,
    required this.onStoreDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cheapest = analysis.storeComparison.cheapestStore;
    final stores = analysis.storeComparison.storePrices;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Magasin le moins cher (mise en évidence) - seulement si magasins existants
          if (cheapest != null && stores.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.withOpacity(0.3),
                    Colors.green.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.4)),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      color: Colors.green,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Magasin le moins cher',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cheapest.storeName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${cheapest.lastPrice.toStringAsFixed(2)} €',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${cheapest.scanCount} scan${cheapest.scanCount > 1 ? 's' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Graphique comparatif
          if (stores.length > 1) ...[
            Text(
              'Comparatif des prix actuels',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _StorePriceBarChart(comparison: analysis.storeComparison),
            const SizedBox(height: 24),
          ],
          
          // Liste de tous les magasins
          Text(
            'Tous les magasins',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          
          // Afficher un message si pas de magasin
          if (stores.isEmpty) ...[
            Container(
              decoration: AppTheme.glassmorphism(),
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Aucun magasin défini pour ce produit',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          ] else ...[
            ...stores.entries.map((entry) {
              final storeInfo = entry.value;
              final isCheapest = storeInfo.storeName == cheapest?.storeName;
              return _StorePriceCard(
                key: ValueKey('store_${entry.key}'),
                storeInfo: storeInfo,
                isCheapest: isCheapest,
                onDelete: () => onStoreDeleted(storeInfo.storeName),
              );
            }),
          ],
          
          // Résumé - seulement si au moins 2 magasins
          if (stores.length > 1) ...[
            const SizedBox(height: 24),
            Container(
              decoration: AppTheme.glassmorphism(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Résumé',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.surfaceLight),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Écart de prix :',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        _calculatePriceRange(analysis.storeComparison),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _calculatePriceRange(StorePriceComparison comparison) {
    if (comparison.storePrices.isEmpty) return 'N/A';
    
    final prices = comparison.storePrices.values.map((s) => s.lastPrice).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final diff = maxPrice - minPrice;
    final diffPercent = (diff / minPrice) * 100;
    
    return '${minPrice.toStringAsFixed(2)} - ${maxPrice.toStringAsFixed(2)} € (${diffPercent.toStringAsFixed(1)}%)';
  }
}

class _StorePriceBarChart extends StatelessWidget {
  final StorePriceComparison comparison;

  const _StorePriceBarChart({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final stores = comparison.storesSortedByPrice;
    if (stores.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: AppTheme.glassmorphism(),
      padding: const EdgeInsets.all(16),
      height: 60.0 + (stores.length * 45.0), // Hauteur dynamique
      child: SfCartesianChart(
        primaryXAxis: CategoryAxis(
          labelStyle: const TextStyle(color: AppTheme.textPrimary, fontSize: 10, fontWeight: FontWeight.bold),
          axisLine: const AxisLine(width: 0),
          majorGridLines: const MajorGridLines(width: 0),
        ),
        primaryYAxis: NumericAxis(
          labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
          axisLine: const AxisLine(color: AppTheme.surfaceLight, width: 1),
          majorGridLines: const MajorGridLines(color: AppTheme.surfaceLight, width: 1),
          numberFormat: NumberFormat.currency(symbol: '€', decimalDigits: 2),
        ),
        series: <CartesianSeries>[
          BarSeries<StorePriceInfo, String>(
            dataSource: stores,
            xValueMapper: (info, _) => info.storeName,
            yValueMapper: (info, _) => info.lastPrice,
            pointColorMapper: (info, _) {
              // Mettre en vert le moins cher
              return info.storeName == comparison.cheapestStore?.storeName
                  ? Colors.green.withOpacity(0.8)
                  : AppTheme.primary.withOpacity(0.8);
            },
            dataLabelSettings: const DataLabelSettings(
              isVisible: true,
              textStyle: TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
              labelAlignment: ChartDataLabelAlignment.outer,
            ),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
          )
        ],
      ),
    );
  }
}

class _StorePriceCard extends StatelessWidget {
  final StorePriceInfo storeInfo;
  final bool isCheapest;
  final VoidCallback? onDelete;

  const _StorePriceCard({
    super.key,
    required this.storeInfo,
    this.isCheapest = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: isCheapest 
            ? Border.all(color: Colors.green, width: 2)
            : Border.all(color: AppTheme.surfaceLight, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeInfo.storeName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dernier scan : ${_formatDate(storeInfo.lastScanDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Prix
              Text(
                '${storeInfo.lastPrice.toStringAsFixed(2)} €',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isCheapest ? Colors.green : AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              // Prix moyen
              Text(
                'Moy. : ${storeInfo.averagePrice.toStringAsFixed(2)} €',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              // Nombre de scans
              Text(
                '${storeInfo.scanCount} scan${storeInfo.scanCount > 1 ? 's' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          // Bouton de suppression
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_forever, size: 18),
              color: Colors.red.withOpacity(0.7),
              tooltip: 'Supprimer ce magasin',
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) return 'Aujourd\'hui';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ==========================================
// ONGLET 3 : PRODUITS SIMILAIRES
// ==========================================

class _SimilarProductsTab extends StatelessWidget {
  final ProductAnalysisResult analysis;
  final ScanRepository repository;

  const _SimilarProductsTab({
    required this.analysis,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final similar = analysis.similarProducts;
    
    if (similar == null || similar.similarProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.compare,
                color: AppTheme.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun produit similaire trouvé',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Aucun autre produit de la même catégorie n\'a été scanné',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    final cheapest = similar.cheapestProduct;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Catégorie
          Container(
            decoration: AppTheme.glassmorphism(),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.category, color: AppTheme.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    similar.category,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Produit le moins cher
          if (cheapest != null) ...[
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailScreen(
                      repository: repository,
                      productId: cheapest.productId,
                      productName: cheapest.productName,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.withOpacity(0.3),
                      Colors.green.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Colors.green,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Le moins cher',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cheapest.productName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${cheapest.price.toStringAsFixed(2)} €',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (cheapest.storeName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            cheapest.storeName!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Liste de tous les produits similaires
          Text(
            'Tous les produits similaires',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          
          ...similar.productsSortedByPrice.map((product) {
            final isCheapest = cheapest != null && product.productId == cheapest.productId;
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailScreen(
                      repository: repository,
                      productId: product.productId,
                      productName: product.productName,
                    ),
                  ),
                );
              },
              child: _SimilarProductCard(
                product: product,
                isCheapest: isCheapest,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SimilarProductCard extends StatelessWidget {
  final SimilarProductInfo product;
  final bool isCheapest;

  const _SimilarProductCard({
    required this.product,
    this.isCheapest = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: isCheapest 
            ? Border.all(color: Colors.green, width: 2)
            : Border.all(color: AppTheme.surfaceLight, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Image
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(10),
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
                    size: 24,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          
          // Infos
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
                  const SizedBox(height: 2),
                  Text(
                    product.brand!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (product.storeName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    product.storeName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Prix
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${product.price.toStringAsFixed(2)} €',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isCheapest ? Colors.green : AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (product.nutriscore != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getNutriscoreColor(product.nutriscore!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    product.nutriscore!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _getNutriscoreColor(String score) {
    switch (score.toUpperCase()) {
      case 'A': return const Color(0xFF038141);
      case 'B': return const Color(0xFF85BB2F);
      case 'C': return const Color(0xFFFECB02);
      case 'D': return const Color(0xFFEE8100);
      case 'E': return const Color(0xFFE63E11);
      default: return AppTheme.textMuted;
    }
  }
}

class _ProductInfoTab extends StatelessWidget {
  final OFFProduct? product;
  final ProductAnalysisResult analysis;

  const _ProductInfoTab({required this.product, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (product == null) {
      return const Center(
        child: Text(
          'Aucune information Open Food Facts disponible',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    final p = product!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. En-tête Premium avec image, marque, quantité, EAN
          _buildPremiumHeader(context, p),
          const SizedBox(height: 16),

          // 2. Ligne des 3 indices : Nutri-Score, Nova, Eco-Score
          _buildScoresRow(context, p),
          const SizedBox(height: 20),

          // 3. Niveaux de nutriments (Faible / Modéré / Élevé)
          if (p.nutrientLevels.isNotEmpty) ...[
            Text(
              'Repères nutritionnels',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _buildNutrientLevelsGrid(context, p),
            const SizedBox(height: 20),
          ],

          // 4. Tableau nutritionnel complet
          if (p.nutriments.isNotEmpty) ...[
            Text(
              'Valeurs nutritionnelles (pour 100g)',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _buildNutritionTable(context, p),
            const SizedBox(height: 20),
          ],

          // 5. Ingrédients
          if (p.ingredients != null && p.ingredients!.isNotEmpty) ...[
            Text(
              'Ingrédients',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: AppTheme.glassmorphism(),
              padding: const EdgeInsets.all(16),
              child: Text(
                p.ingredients!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 6. Allergènes
          if (p.allergens.isNotEmpty) ...[
            Text(
              'Allergènes',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: p.allergens.map((allergen) => Chip(
                  label: Text(
                    allergen,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  backgroundColor: Colors.red.withOpacity(0.15),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],
          
          // 7. Catégories
          if (p.categories.isNotEmpty) ...[
            Text(
              'Catégories',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: p.categories.take(5).map((category) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.surfaceLight),
                ),
                child: Text(
                  category,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context, OFFProduct p) {
    final theme = Theme.of(context);
    final sizeLabel = (p.quantity != null) ? '${p.quantity} ${p.unit ?? ""}' : 'Quantité inconnue';

    return Container(
      decoration: AppTheme.glassmorphism(),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image du produit
          Hero(
            tag: 'product_image_${p.barcode}',
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                image: p.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(p.imageUrl!),
                        fit: BoxFit.contain,
                      )
                    : null,
                border: Border.all(color: AppTheme.surfaceLight, width: 1),
              ),
              child: p.imageUrl == null
                  ? const Icon(Icons.shopping_bag, size: 40, color: AppTheme.textMuted)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          // Informations textuelles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  p.brand,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'EAN : ${p.barcode}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.scale, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      sizeLabel,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoresRow(BuildContext context, OFFProduct p) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: _buildNutriscoreCard(context, p.nutriscore)),
        const SizedBox(width: 8),
        Expanded(child: _buildNovaCard(context, p.novaGroup)),
        const SizedBox(width: 8),
        Expanded(child: _buildEcoscoreCard(context, p.ecoscore)),
      ],
    );
  }

  Widget _buildNutriscoreCard(BuildContext context, String? score) {
    final theme = Theme.of(context);
    final scoreUpper = score?.toUpperCase();
    final Color color = _getNutriscoreColor(scoreUpper ?? '');
    
    return Container(
      height: 90,
      decoration: AppTheme.glassmorphism(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Nutri-Score',
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: scoreUpper != null ? color : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              scoreUpper ?? 'N/A',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNovaCard(BuildContext context, int? group) {
    final theme = Theme.of(context);
    final Color color = _getNovaColor(group);
    
    return Container(
      height: 90,
      decoration: AppTheme.glassmorphism(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Nova',
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: group != null ? color : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              group != null ? '$group' : 'N/A',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEcoscoreCard(BuildContext context, String? score) {
    final theme = Theme.of(context);
    final scoreUpper = score?.toUpperCase();
    final Color color = _getEcoscoreColor(scoreUpper ?? '');
    
    return Container(
      height: 90,
      decoration: AppTheme.glassmorphism(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Éco-Score',
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: scoreUpper != null ? color : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              scoreUpper ?? 'N/A',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientLevelsGrid(BuildContext context, OFFProduct p) {
    final levels = p.nutrientLevels;
    
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildNutrientLevelCard('Matières grasses', levels['fat'], p.nutriments['fat_100g'], 'g'),
        _buildNutrientLevelCard('Acides gras sat.', levels['saturated-fat'], p.nutriments['saturated-fat_100g'], 'g'),
        _buildNutrientLevelCard('Sucres', levels['sugars'], p.nutriments['sugars_100g'], 'g'),
        _buildNutrientLevelCard('Sel', levels['salt'], p.nutriments['salt_100g'], 'g'),
      ],
    );
  }

  Widget _buildNutrientLevelCard(String label, String? level, double? value, String unit) {
    final Color levelColor;
    final String levelText;
    
    switch (level?.toLowerCase()) {
      case 'low':
        levelColor = Colors.green;
        levelText = 'Faible';
        break;
      case 'moderate':
        levelColor = Colors.orange;
        levelText = 'Modéré';
        break;
      case 'high':
        levelColor = Colors.red;
        levelText = 'Élevé';
        break;
      default:
        levelColor = AppTheme.textMuted;
        levelText = 'N/A';
    }

    return Container(
      decoration: AppTheme.glassmorphism(),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: levelColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                levelText,
                style: TextStyle(color: levelColor, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (value != null)
                Text(
                  '${value.toStringAsFixed(1)}$unit',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionTable(BuildContext context, OFFProduct p) {
    final n = p.nutriments;
    
    final rows = [
      _buildNutritionRow('Énergie', n['energy-kcal_100g'] ?? (n['energy_100g'] != null ? n['energy_100g']! / 4.184 : null), 'kcal'),
      _buildNutritionRow('Matières grasses', n['fat_100g'], 'g'),
      _buildNutritionRow('  dont Acides gras saturés', n['saturated-fat_100g'], 'g'),
      _buildNutritionRow('Glucides', n['carbohydrates_100g'], 'g'),
      _buildNutritionRow('  dont Sucres', n['sugars_100g'], 'g'),
      _buildNutritionRow('Fibres alimentaires', n['fiber_100g'], 'g'),
      _buildNutritionRow('Protéines', n['proteins_100g'], 'g'),
      _buildNutritionRow('Sel', n['salt_100g'], 'g'),
    ].where((row) => row != null).cast<Widget>().toList();

    return Container(
      decoration: AppTheme.glassmorphism(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Nutriment', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
              Text('Pour 100g', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: AppTheme.surfaceLight, height: 1),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget? _buildNutritionRow(String label, double? value, String unit) {
    if (value == null) return null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: label.startsWith(' ') ? AppTheme.textSecondary : AppTheme.textPrimary,
              fontSize: 13,
              fontStyle: label.startsWith(' ') ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          Text(
            '${value.toStringAsFixed(value < 1 ? 3 : 1)} $unit',
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Color _getNutriscoreColor(String score) {
    switch (score.toUpperCase()) {
      case 'A': return const Color(0xFF038141);
      case 'B': return const Color(0xFF85BB2F);
      case 'C': return const Color(0xFFFECB02);
      case 'D': return const Color(0xFFEE8100);
      case 'E': return const Color(0xFFE63E11);
      default: return AppTheme.textMuted;
    }
  }

  Color _getNovaColor(int? group) {
    switch (group) {
      case 1: return const Color(0xFF00AA55);
      case 2: return const Color(0xFFEEAA00);
      case 3: return const Color(0xFFFF6600);
      case 4: return const Color(0xFFFF0000);
      default: return AppTheme.textMuted;
    }
  }

  Color _getEcoscoreColor(String score) {
    switch (score.toUpperCase()) {
      case 'A': return const Color(0xFF1E824C);
      case 'B': return const Color(0xFF2ECC71);
      case 'C': return const Color(0xFFF1C40F);
      case 'D': return const Color(0xFFE67E22);
      case 'E': return const Color(0xFFE74C3C);
      default: return AppTheme.textMuted;
    }
  }
}
