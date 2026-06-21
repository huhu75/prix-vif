import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets/price_card.dart';
import '../widgets/magic_button.dart';
import '../widgets/magic_title.dart';

class ResultsScreen extends StatefulWidget {
  final List<ScannedItem> scannedItems;
  final VoidCallback onBack;
  final Function(ScannedItem) onItemRemoved;
  final VoidCallback onClearAll;
  final VoidCallback onSaveSession;

  const ResultsScreen({
    super.key,
    required this.scannedItems,
    required this.onBack,
    required this.onItemRemoved,
    required this.onClearAll,
    required this.onSaveSession,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final Set<String> _selectedItems = {};
  
  bool get _isSelectionMode => _selectedItems.isNotEmpty;
  int get _selectedCount => _selectedItems.length;
  
  double get _totalAmount => widget.scannedItems
      .where((item) => _selectedItems.isEmpty || _selectedItems.contains(item.id))
      .fold(0, (sum, item) => sum + item.price);

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedItems.contains(id)) {
        _selectedItems.remove(id);
      } else {
        _selectedItems.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedItems.clear();
    });
  }

  void _removeSelected() {
    for (final id in _selectedItems) {
      final item = widget.scannedItems.firstWhere(
        (item) => item.id == id,
        orElse: () => widget.scannedItems.first,
      );
      widget.onItemRemoved(item);
    }
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: NeonTitle(
          text: _isSelectionMode ? 'Sélection ($_selectedCount)' : 'RÉSULTATS',
          fontSize: 22,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () {
            _clearSelection();
            widget.onBack();
          },
        ),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              onPressed: _removeSelected,
              tooltip: 'Supprimer',
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary),
              onPressed: () {
                if (widget.scannedItems.isNotEmpty) {
                  showDialog(
                    context: context,
                    builder: (context) => _ConfirmClearDialog(
                      onConfirm: widget.onClearAll,
                    ),
                  );
                }
              },
              tooltip: 'Tout supprimer',
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.save, color: AppTheme.primary),
            onPressed: () {
              widget.onSaveSession();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppTheme.primary,
                  content: Text(
                    'Session enregistrée',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Enregistrer',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Statistiques
          if (widget.scannedItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _StatItem(
                    label: 'Articles',
                    value: widget.scannedItems.length.toString(),
                    icon: Icons.shopping_bag,
                  ),
                  const SizedBox(width: 12),
                  _StatItem(
                    label: 'Total',
                    value: _totalAmount.toStringAsFixed(2),
                    suffix: '€',
                    icon: Icons.euro,
                  ),
                  const SizedBox(width: 12),
                  _StatItem(
                    label: 'Moyenne',
                    value: (_totalAmount / widget.scannedItems.length).toStringAsFixed(2),
                    suffix: '€',
                    icon: Icons.trending_up,
                  ),
                ],
              ),
            ),
          
          // Liste des articles
          Expanded(
            child: widget.scannedItems.isEmpty
                ? _EmptyState(
                    onScan: () {
                      _clearSelection();
                      widget.onBack();
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: widget.scannedItems.length,
                    itemBuilder: (context, index) {
                      final item = widget.scannedItems[index];
                      final isSelected = _selectedItems.contains(item.id);
                      
                      return _SelectablePriceCard(
                        item: item,
                        isSelected: isSelected,
                        onTap: () => _toggleSelection(item.id),
                        onLongPress: () => _toggleSelection(item.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Élément de stat
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Expanded(
      child: Container(
        decoration: AppTheme.glassmorphism(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: 2),
                  Text(
                    suffix!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Carte de produit sélectionnable
class _SelectablePriceCard extends StatelessWidget {
  final ScannedItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SelectablePriceCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.08) : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
              ? AppTheme.primary.withOpacity(0.4)
              : Colors.black.withOpacity(0.05),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.1),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
        ),
        child: Stack(
          children: [
            PriceCard(item: item, showQuantity: true, showDate: false),
            if (isSelected)
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// État vide
class _EmptyState extends StatelessWidget {
  final VoidCallback onScan;

  const _EmptyState({required this.onScan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
            child: Icon(
              Icons.shopping_bag,
              size: 40,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun article',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Scannez vos premiers produits',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          MagicButton(
            text: 'SCANNER MAINTENANT',
            icon: Icons.qr_code_scanner,
            onPressed: onScan,
            width: 200,
          ),
        ],
      ),
    );
  }
}

// Dialogue de confirmation
class _ConfirmClearDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const _ConfirmClearDialog({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: const Text(
        'Tout supprimer ?',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: const Text(
        'Cette action supprimera tous les articles. Vous ne pourrez pas annuler.',
        style: TextStyle(
          color: AppTheme.textSecondary,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Annuler',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        MagicButton(
          text: 'Supprimer',
          onPressed: () {
            onConfirm();
            Navigator.of(context).pop();
          },
          color: AppTheme.error,
          width: 120,
          height: 44,
        ),
      ],
    );
  }
}
