import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';
import '../models/product_analysis_models.dart';
import '../services/scan_repository.dart';
import '../services/open_food_facts_service.dart';
import '../services/product_analysis_service.dart';
import '../widgets/article_edit_dialog.dart';
import '../widgets/nav_buttons.dart';
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

  /// Modifie un scan précis (prix, date, magasin, quantité) via ArticleEditDialog
  Future<void> _handleEditPricePoint(PricePoint point) async {
    final item = widget.repository.getScannedItem(point.articleId);
    if (item == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de retrouver cet enregistrement')),
        );
      }
      return;
    }
    await _openEditDialogForItem(item);
  }

  /// Ouvre la boîte de dialogue d'édition pour un article donné
  Future<void> _openEditDialogForItem(ScannedItem item) async {
    final result = await showArticleEditDialog(
      context,
      item,
      knownStores: widget.repository.getAllKnownStores(),
    );
    if (result == null || !mounted) return;

    if (result is ArticleUpdated) {
      await widget.repository.updateArticle(result.item);
      await _loadAnalysis();
      await widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enregistrement mis à jour : ${result.item.price.toStringAsFixed(2)} € (${result.item.storeName ?? "Sans magasin"})',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (result is ArticleDeleted) {
      await widget.repository.deleteArticle(item.id);
      await _loadAnalysis();
      await widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan supprimé'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  /// Change le magasin de ce produit (pour un magasin cible ou tous ses magasins)
  Future<void> _handleChangeStore({String? targetOldStore}) async {
    final stores = _analysisResult?.storeComparison.storePrices.keys.toList() ?? [];
    String? selectedOldStore = targetOldStore ?? (stores.isNotEmpty ? stores.first : null);
    final storeController = TextEditingController(text: selectedOldStore ?? '');
    final knownStores = widget.repository.getAllKnownStores();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: const Text('Changer de magasin'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (targetOldStore == null && stores.length > 1) ...[
                    const Text(
                      'Magasin actuel à remplacer :',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedOldStore,
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Tous les magasins du produit'),
                        ),
                        ...stores.map((s) => DropdownMenuItem<String?>(
                              value: s,
                              child: Text(s),
                            )),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          selectedOldStore = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ] else if (selectedOldStore != null) ...[
                    Text(
                      'Remplacer le magasin « $selectedOldStore » par :',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                  ] else ...[
                    const Text(
                      'Définir le nouveau magasin :',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextFormField(
                    key: const ValueKey('change_store_input'),
                    controller: storeController,
                    decoration: const InputDecoration(
                      labelText: 'Nouveau magasin',
                      hintText: 'ex. Leclerc, Carrefour, Lidl...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Suggestions :',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final s in knownStores)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(s, style: const TextStyle(fontSize: 11)),
                              onPressed: () {
                                setDialogState(() {
                                  storeController.text = s;
                                });
                              },
                              backgroundColor: storeController.text.toLowerCase() == s.toLowerCase()
                                  ? AppTheme.accent.withValues(alpha: 0.25)
                                  : AppTheme.surfaceLight,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                key: const ValueKey('confirm_change_store'),
                onPressed: () {
                  if (storeController.text.trim().isNotEmpty) {
                    Navigator.of(dialogContext).pop(true);
                  }
                },
                child: const Text('Valider'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;
    final newStore = storeController.text.trim();
    if (newStore.isEmpty) return;

    final count = await widget.repository.changeStoreForProduct(
      widget.productId,
      selectedOldStore,
      newStore,
    );
    await _loadAnalysis();
    await widget.onChanged?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Magasin mis à jour pour $count scan${count > 1 ? "s" : ""} ($newStore)'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Ouvre une feuille listant tous les scans du produit pour en corriger un
  Future<void> _handleEditScansList() async {
    final articles = widget.repository.getArticlesForProduct(widget.productId);
    if (!mounted) return;
    if (articles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun scan trouvé pour ce produit')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Scans de ce produit (${articles.length})',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Text(
                  'Touchez un scan pour corriger son prix, sa quantité ou son magasin.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                const Divider(color: AppTheme.surfaceLight, height: 1),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: articles.length,
                    separatorBuilder: (_, _) => const Divider(color: AppTheme.surfaceLight, height: 1),
                    itemBuilder: (context, index) {
                      final item = articles[index];
                      final dateStr = '${item.scanDate.day}/${item.scanDate.month}/${item.scanDate.year}';
                      final storeStr = item.storeName ?? 'Magasin inconnu';
                      return ListTile(
                        key: ValueKey('product_scan_item_$index'),
                        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_outlined, color: AppTheme.accent, size: 20),
                        ),
                        title: Text(
                          '${item.price.toStringAsFixed(2)} €',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          '$storeStr · $dateStr${item.formattedQuantity.isNotEmpty ? " · ${item.formattedQuantity}" : ""}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.edit_outlined, color: AppTheme.accent, size: 18),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await _openEditDialogForItem(item);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Action depuis la carte d'un magasin dans StoreComparisonTab
  Future<void> _handleStoreCardEdit(String storeName) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text('Magasin « $storeName »'),
        children: [
          SimpleDialogOption(
            key: const ValueKey('store_choice_change_store'),
            onPressed: () => Navigator.of(dialogContext).pop('change_store'),
            child: const Row(
              children: [
                Icon(Icons.store, color: AppTheme.accent),
                SizedBox(width: 12),
                Text('Changer le magasin pour ce produit'),
              ],
            ),
          ),
          SimpleDialogOption(
            key: const ValueKey('store_choice_edit_price'),
            onPressed: () => Navigator.of(dialogContext).pop('edit_price'),
            child: const Row(
              children: [
                Icon(Icons.edit, color: AppTheme.primary),
                SizedBox(width: 12),
                Text('Modifier le dernier prix dans ce magasin'),
              ],
            ),
          ),
        ],
      ),
    );

    if (choice == 'change_store') {
      await _handleChangeStore(targetOldStore: storeName);
    } else if (choice == 'edit_price') {
      final articles = widget.repository
          .getArticlesForProduct(widget.productId)
          .where((a) => a.storeName == storeName)
          .toList();
      if (articles.isNotEmpty) {
        await _openEditDialogForItem(articles.first);
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
          leading: const AppBackButton(),
          title: Text(
            _analysisResult!.productName.toUpperCase(),
            // Couleur explicite : le style de titre du thème n'en a pas (texte noir)
            style: const TextStyle(fontSize: 18, color: AppTheme.textPrimary),
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
            const AppHomeButton(),
            // Bouton pour rafraîchir
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.textPrimary),
              onPressed: _loadAnalysis,
            ),
            PopupMenuButton<String>(
              key: const ValueKey('product_actions'),
              icon: const Icon(Icons.more_vert, color: AppTheme.textPrimary),
              onSelected: (action) {
                switch (action) {
                  case 'edit_scans':
                    _handleEditScansList();
                    break;
                  case 'change_store':
                    _handleChangeStore();
                    break;
                  case 'rematch':
                    _rematchProduct();
                    break;
                  case 'delete':
                    _deleteProduct();
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  key: ValueKey('action_edit_scans'),
                  value: 'edit_scans',
                  child: ListTile(
                    leading: Icon(Icons.edit_note, color: AppTheme.accent),
                    title: Text('Corriger un prix / scan'),
                  ),
                ),
                PopupMenuItem(
                  key: ValueKey('action_change_store'),
                  value: 'change_store',
                  child: ListTile(
                    leading: Icon(Icons.store, color: AppTheme.primary),
                    title: Text('Changer de magasin'),
                  ),
                ),
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
            PriceEvolutionTab(
              analysis: _analysisResult!,
              onEditPricePoint: _handleEditPricePoint,
            ),
            
            // Onglet 2 : Comparaison par magasin
            StoreComparisonTab(
              analysis: _analysisResult!,
              onStoreDeleted: _handleStoreDeleted,
              onStoreEdit: _handleStoreCardEdit,
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

  /// Barre d'app des états chargement / erreur / vide : Retour et Accueil
  PreferredSizeWidget _simpleAppBar() {
    return AppBar(
      leading: const AppBackButton(),
      title: Text(
        widget.productName.toUpperCase(),
        style: const TextStyle(fontSize: 18, color: AppTheme.textPrimary),
        overflow: TextOverflow.ellipsis,
      ),
      actions: const [AppHomeButton(), SizedBox(width: 8)],
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: _simpleAppBar(),
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
      appBar: _simpleAppBar(),
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
      appBar: _simpleAppBar(),
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
