// Confirmation des articles extraits d'un ticket (rapprochement Open Food Facts)
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models.dart';
import '../../services/open_food_facts_service.dart';
import '../../utils/unit_price.dart';
import '../magic_button.dart';
import '../price_card.dart';

// Modèle pour confirmation du ticket
class ExtractedTicketItem {
  final String rawName;
  final double price;
  final double quantity;
  OFFProduct? matchedProduct;
  List<OFFProduct> candidates;
  bool isSelected;

  ExtractedTicketItem({
    required this.rawName,
    required this.price,
    required this.quantity,
    this.matchedProduct,
    required this.candidates,
    this.isSelected = true,
  });
}

// Bottom Sheet de confirmation pour les articles du ticket
class TicketConfirmationSheet extends StatefulWidget {
  final List<ExtractedTicketItem> items;
  final String storeName;
  final OpenFoodFactsService offService;

  const TicketConfirmationSheet({
    super.key,
    required this.items,
    required this.storeName,
    required this.offService,
  });

  @override
  State<TicketConfirmationSheet> createState() => _TicketConfirmationSheetState();
}

class _TicketConfirmationSheetState extends State<TicketConfirmationSheet> {
  late List<ExtractedTicketItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.items;
  }

  double get _totalAmount => _items
      .where((item) => item.isSelected)
      .fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  int get _selectedCount => _items.where((item) => item.isSelected).length;

  Color _getNutriScoreColor(String grade) {
    switch (grade.trim().toLowerCase()) {
      case 'a':
        return const Color(0xFF038141);
      case 'b':
        return const Color(0xFF85BB2F);
      case 'c':
        return const Color(0xFFFECB02);
      case 'd':
        return const Color(0xFFEE8100);
      case 'e':
        return const Color(0xFFE63E11);
      default:
        return AppTheme.textMuted;
    }
  }

  Future<void> _showAlternativeProductsDialog(ExtractedTicketItem item) async {
    final searchController = TextEditingController(text: item.rawName);
    List<OFFProduct> searchResults = List.from(item.candidates);
    bool isSearching = false;
    String? searchError;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Recherche tapée : réseau d'abord (tous les résultats, pas le seul
            // produit en cache), code-barres accepté
            Future<void> runSearch() async {
              setDialogState(() {
                isSearching = true;
                searchError = null;
              });
              try {
                final results = await widget.offService.searchProducts(searchController.text);
                setDialogState(() {
                  searchResults = results;
                  isSearching = false;
                });
              } catch (e) {
                setDialogState(() {
                  searchResults = [];
                  isSearching = false;
                  searchError = OFFSearchUnavailableException.userMessage;
                });
              }
            }

            return AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Associer un produit',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Rechercher sur Open Food Facts...',
                        suffixIcon: isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.search, color: AppTheme.primary),
                                onPressed: runSearch,
                              ),
                      ),
                      onSubmitted: (_) => runSearch(),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: searchResults.isEmpty
                          ? Center(
                              child: Text(
                                isSearching ? 'Recherche en cours...' : (searchError ?? 'Aucun produit trouvé.'),
                                style: TextStyle(color: searchError != null ? AppTheme.error : AppTheme.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: searchResults.length,
                              itemBuilder: (context, idx) {
                                final prod = searchResults[idx];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: prod.imageUrl != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Image.network(
                                              prod.imageUrl!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const Icon(Icons.shopping_bag_outlined, color: AppTheme.textSecondary),
                                  ),
                                  title: Text(
                                    prod.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    prod.brand,
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: prod.nutriscore != null
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getNutriScoreColor(prod.nutriscore!),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            prod.nutriscore!.toUpperCase(),
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        )
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      item.matchedProduct = prod;
                                    });
                                    Navigator.of(dialogContext).pop();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Fermer', style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Validation du Ticket',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Vérifiez la correspondance des produits pour ${widget.storeName}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // Liste des articles
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun article extrait.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: item.isSelected 
                              ? AppTheme.surfaceLight.withValues(alpha: 0.3)
                              : AppTheme.surfaceDark.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: item.isSelected 
                                ? AppTheme.primary.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Checkbox d'importation
                            Checkbox(
                              value: item.isSelected,
                              activeColor: AppTheme.primary,
                              onChanged: (val) {
                                setState(() {
                                  item.isSelected = val ?? false;
                                });
                              },
                            ),
                            const SizedBox(width: 4),
                            
                            // Infos du produit matché ou brut
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Nom brut du ticket
                                  Text(
                                    item.rawName,
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      decoration: item.isSelected ? null : TextDecoration.lineThrough,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  
                                  // Fiche Produit matchée
                                  if (item.matchedProduct != null)
                                    Row(
                                      children: [
                                        Container(
                                          width: 45,
                                          height: 45,
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceDark,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: item.matchedProduct!.imageUrl != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Image.network(
                                                    item.matchedProduct!.imageUrl!,
                                                    fit: BoxFit.cover,
                                                  ),
                                                )
                                              : const Icon(Icons.shopping_bag_outlined, color: AppTheme.textSecondary, size: 20),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.matchedProduct!.name,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                item.matchedProduct!.brand,
                                                style: const TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 11,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (item.matchedProduct!.nutriscore != null) ...[
                                                const SizedBox(height: 4),
                                                NutriScoreBadge(score: item.matchedProduct!.nutriscore!),
                                              ]
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Row(
                                      children: [
                                        Container(
                                          width: 45,
                                          height: 45,
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceDark,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 22),
                                        ),
                                        const SizedBox(width: 10),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Aucun produit associé',
                                                style: TextStyle(
                                                  color: AppTheme.warning,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                'Le produit sera importé sans fiche OFF',
                                                style: TextStyle(
                                                  color: AppTheme.textMuted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 8),
                                  
                                  // Lien de modification de correspondance
                                  GestureDetector(
                                    onTap: () => _showAlternativeProductsDialog(item),
                                    child: Text(
                                      item.matchedProduct != null ? 'Modifier la correspondance' : 'Associer un produit',
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Prix & Quantité
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${(item.price * item.quantity).toStringAsFixed(2)} €',
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${item.quantity.toInt()} x ${item.price.toStringAsFixed(2)} €',
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          
          const SizedBox(height: 16),
          
          // Bouton d'importation
          MagicButton(
            text: 'IMPORTER $_selectedCount ARTICLES (${_totalAmount.toStringAsFixed(2)} €)',
            onPressed: _selectedCount == 0
                ? null 
                : () {
                    final List<ScannedItem> importedItems = [];
                    final importTimestamp = DateTime.now().millisecondsSinceEpoch;
                    for (var item in _items) {
                      if (item.isSelected) {
                        final lineQuantity = ticketLineQuantity(
                          count: item.quantity,
                          packQuantity: item.matchedProduct?.quantity,
                          packUnit: item.matchedProduct?.unit,
                        );
                        importedItems.add(
                          ScannedItem(
                            // Index inclus : deux lignes identiques du ticket gardent des id distincts
                            id: '${importTimestamp}_${importedItems.length}',
                            name: item.matchedProduct?.name ?? item.rawName,
                            brand: item.matchedProduct?.brand ?? 'Marque inconnue',
                            price: item.price,
                            quantity: lineQuantity.quantity,
                            unit: lineQuantity.unit,
                            scanDate: DateTime.now(),
                            barcode: item.matchedProduct?.barcode,
                            imageUrl: item.matchedProduct?.imageUrl ?? 'https://via.placeholder.com/150x150/CCCCCC/000000?text=📦',
                            storeName: widget.storeName,
                            nutriscore: item.matchedProduct?.nutriscore,
                            categories: item.matchedProduct?.categories,
                          ),
                        );
                      }
                    }
                    Navigator.of(context).pop(importedItems);
                  },
            isPrimary: true,
          ),
        ],
      ),
    );
  }
}
