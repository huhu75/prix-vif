import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';
import '../models/product_analysis_models.dart';
import '../services/category_service.dart';
import '../services/scan_repository.dart';
import '../services/open_food_facts_service.dart';
import '../services/product_analysis_service.dart';
import '../widgets/article_edit_dialog.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/nav_buttons.dart';
import '../widgets/off_match_sheet.dart';
import '../widgets/product_detail/category_tab.dart';
import '../widgets/product_detail/price_evolution_tab.dart';
import '../widgets/product_detail/product_info_tab.dart';
import '../widgets/product_detail/store_comparison_tab.dart';
import '../widgets/product_detail/store_edit_sheet.dart';

/// Écran de détails d'un produit avec analyse complète
/// Contient 4 onglets : Fiche, Évolution des prix, Magasins (avec conseil
/// d'achat) et Catégorie (les autres marques, au kg / L)
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

  /// Catégorie, produits de la catégorie et conseils d'achat
  ProductAnalysisData? _data;
  bool _isLoading = true;
  String? _error;

  /// Choisit (ou change) la catégorie du produit
  Future<void> _chooseCategory() async {
    final data = _data;
    if (data == null) return;
    final chosen = await showCategoryPickerSheet(
      context,
      known: widget.repository.getKnownCategories(),
      current: data.category,
    );
    if (chosen == null || !mounted) return;
    await widget.repository.setProductCategory(data.productKey, chosen);
    await widget.onChanged?.call();
    await _loadAnalysis();
  }

  /// Ouvre la fiche d'un autre produit (depuis l'onglet Catégorie)
  void _openProduct(String productId, String productName) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductDetailScreen(
        repository: widget.repository,
        productId: productId,
        productName: productName,
        initialTabIndex: 2,
        analysisService: widget.analysisService,
        offSearch: widget.offSearch,
        onChanged: widget.onChanged,
      ),
    ));
  }

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
        _data = data;
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
      await widget.onChanged?.call();
      
      // Afficher un message de confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('« $storeName » retiré de ce produit'),
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
    // Catégorie Open Food Facts de la nouvelle fiche
    if (chosen.barcode.isNotEmpty && chosen.categoryId != null) {
      try {
        await CategoryService(widget.repository)
            .applyFromProduct(chosen.barcode, chosen)
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        // Taxonomie indisponible : la catégorie sera complétée plus tard
      }
    }
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

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
    );
  }

  /// Menu ⋮ « Modifier un magasin » : la feuille du magasin, après avoir
  /// choisi lequel si le produit en a plusieurs
  Future<void> _pickStoreToEdit() async {
    final stores = _analysisResult?.storeComparison.storesSortedByPrice.map((s) => s.storeName).toList() ?? [];
    if (stores.isEmpty) {
      _showMessage('Aucun magasin pour ce produit : ajoute un prix d\'abord');
      return;
    }
    final store = stores.length == 1
        ? stores.single
        : await showDialog<String>(
            context: context,
            builder: (dialogContext) => SimpleDialog(
              backgroundColor: AppTheme.surfaceDark,
              title: const Text('Quel magasin ?'),
              children: [
                for (final store in stores)
                  SimpleDialogOption(
                    key: ValueKey('pick_store_$store'),
                    onPressed: () => Navigator.of(dialogContext).pop(store),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_outlined, color: AppTheme.primary),
                        const SizedBox(width: 12),
                        Expanded(child: Text(store)),
                        Text(
                          '${_analysisResult!.storeComparison.storePrices[store]!.lastPrice.toStringAsFixed(2)} €',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
    if (store != null && mounted) await _handleStoreCardEdit(store);
  }

  /// Ajoute un prix vu dans un magasin, sans scanner le produit
  Future<void> _addStorePrice() async {
    final productStores = _analysisResult?.storeComparison.storePrices.keys.toList() ?? const <String>[];
    final result = await showAddStorePriceSheet(
      context,
      productName: _analysisResult?.productName ?? widget.productName,
      knownStores: widget.repository.getAllKnownStores(),
      productStores: productStores,
    );
    if (result == null || !mounted) return;
    final added = await widget.repository.addPriceForProduct(
      widget.productId,
      storeName: result.store,
      price: result.price,
    );
    await _loadAnalysis();
    await widget.onChanged?.call();
    _showMessage(added == null
        ? 'Impossible d\'ajouter ce prix'
        : 'Prix ajouté : ${result.price.toStringAsFixed(2)} € chez ${result.store}');
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

  /// Feuille d'un magasin (carte de l'onglet Magasins ou menu ⋮) : changer
  /// de magasin pour ce produit, renommer le magasin partout, corriger le
  /// dernier prix ou retirer le magasin
  Future<void> _handleStoreCardEdit(String storeName) async {
    final info = _analysisResult?.storeComparison.storePrices[storeName];
    if (info == null) return;
    final isUnknown = storeName == ScanRepository.unknownStoreLabel;
    final action = await showStoreEditSheet(
      context,
      storeName: storeName,
      lastPrice: info.lastPrice,
      productScanCount: info.scanCount,
      storeScanCount: widget.repository.countStoreArticles(storeName),
      knownStores: widget.repository.getAllKnownStores(),
      canRename: !isUnknown,
      canRemove: !isUnknown,
    );
    if (action == null || !mounted) return;

    switch (action) {
      case StoreMoved(:final newStore):
        final count = await widget.repository.changeStoreForProduct(widget.productId, storeName, newStore);
        await _loadAnalysis();
        await widget.onChanged?.call();
        _showMessage('$count scan${count > 1 ? 's' : ''} déplacé${count > 1 ? 's' : ''} vers $newStore');
      case StoreRenamed(:final newName):
        final count = await widget.repository.renameStore(storeName, newName);
        await _loadAnalysis();
        await widget.onChanged?.call();
        _showMessage('« $storeName » renommé en « $newName » ($count scan${count > 1 ? 's' : ''})');
      case StoreLastPriceEdit():
        final articles = widget.repository
            .getArticlesForProduct(widget.productId)
            .where((a) => isUnknown ? (a.storeName?.trim().isEmpty ?? true) : a.storeName == storeName)
            .toList();
        if (articles.isNotEmpty) await _openEditDialogForItem(articles.first);
      case StoreRemoved():
        await _handleStoreDeleted(storeName);
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
                icon: Icon(Icons.category_outlined),
                text: 'Catégorie',
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
              onSelected: (action) {
                switch (action) {
                  case 'edit_scans':
                    _handleEditScansList();
                    break;
                  case 'change_store':
                    _pickStoreToEdit();
                    break;
                  case 'add_price':
                    _addStorePrice();
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
                    title: Text('Modifier un magasin'),
                  ),
                ),
                PopupMenuItem(
                  key: ValueKey('action_add_price'),
                  value: 'add_price',
                  child: ListTile(
                    leading: Icon(Icons.add_business_outlined, color: AppTheme.primary),
                    title: Text('Ajouter un prix dans un magasin'),
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
              category: _data?.category,
              onChooseCategory: _chooseCategory,
            ),

            // Onglet 1 : Évolution des prix
            PriceEvolutionTab(
              analysis: _analysisResult!,
              onEditPricePoint: _handleEditPricePoint,
            ),
            
            // Onglet 2 : Comparaison par magasin
            StoreComparisonTab(
              analysis: _analysisResult!,
              onStoreEdit: _handleStoreCardEdit,
              onAddPrice: _addStorePrice,
              adviceByStore: _data?.adviceByStore ?? const {},
            ),

            // Onglet 3 : les autres produits de sa catégorie, au kg / L
            CategoryTab(
              category: _data?.category,
              group: _data?.categoryGroup,
              productKey: _data?.productKey ?? '',
              onChooseCategory: _chooseCategory,
              onOpenProduct: _openProduct,
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
