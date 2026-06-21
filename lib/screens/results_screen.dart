import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets/price_card.dart';

// 📊 Écran des résultats de scan
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
  // État pour la sélection multiple
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
        title: Text(
          _isSelectionMode ? 'Sélection ($_selectedCount)' : 'RÉSULTATS',
          style: theme.appBarTheme.titleTextStyle?.copyWith(
            color: _isSelectionMode ? AppTheme.primary : Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
              tooltip: 'Supprimer la sélection',
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
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
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: () {
              widget.onSaveSession();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppTheme.accent,
                  content: Text(
                    'Session enregistrée dans l\'historique',
                    style: TextStyle(color: Colors.white),
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
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.glassmorphism(blur: 15, opacity: 0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatCard(
                    label: 'Articles',
                    value: widget.scannedItems.length.toString(),
                    icon: Icons.shopping_bag,
                    color: AppTheme.primary,
                  ),
                  _StatCard(
                    label: 'Total',
                    value: _totalAmount.toStringAsFixed(2),
                    icon: Icons.euro,
                    color: AppTheme.accent,
                    suffix: '€',
                  ),
                  _StatCard(
                    label: 'Moyenne',
                    value: (_totalAmount / widget.scannedItems.length)
                        .toStringAsFixed(2),
                    icon: Icons.trending_up,
                    color: AppTheme.secondary,
                    suffix: '€',
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
          
          // Barre de total en bas
          if (widget.scannedItems.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primary,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL :',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _totalAmount.toStringAsFixed(2),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                  const Text(
                    '€',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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

// 📋 Carte de statistiques
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? suffix;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// 📄 Carte sélectionnable
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
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.2),
                    AppTheme.primary.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            PriceCard(
              item: item,
              showQuantity: true,
              showDate: false,
            ),
            // Indicateur de sélection
            if (isSelected)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: AppTheme.backgroundDark,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 📭 État vide
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
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.qr_code_scanner,
              color: Colors.white,
              size: 50,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun article scanné',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Commencez par scanner un code-barres ou un QR code pour voir les résultats',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.qr_code_scanner, size: 24),
            label: const Text(
              'SCANNER MAINTENANT',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.backgroundDark,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              elevation: 8,
              shadowColor: AppTheme.primary.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ❓ Dialogue de confirmation
class _ConfirmClearDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const _ConfirmClearDialog({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text(
        'Tout supprimer ?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: const Text(
        'Cette action supprimera tous les articles scannés. Vous ne pourrez pas annuler.',
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
        ElevatedButton(
          onPressed: () {
            onConfirm();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.error,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Supprimer tout'),
        ),
      ],
    );
  }
}
