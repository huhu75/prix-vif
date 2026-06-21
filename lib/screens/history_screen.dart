import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets/price_card.dart';

// 🕒 Écran d'historique des sessions de scan
class HistoryScreen extends StatefulWidget {
  final List<ScanSession> sessions;
  final Function(ScanSession) onSessionSelected;
  final Function(ScanSession) onSessionDeleted;
  final VoidCallback onClearAll;

  const HistoryScreen({
    super.key,
    required this.sessions,
    required this.onSessionSelected,
    required this.onSessionDeleted,
    required this.onClearAll,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('HISTORIQUE'),
        actions: [
          if (widget.sessions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: AppTheme.error),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => _ConfirmClearDialog(
                    onConfirm: widget.onClearAll,
                  ),
                );
              },
              tooltip: 'Tout supprimer',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: widget.sessions.isEmpty
          ? _EmptyHistoryState()
          : Column(
              children: [
                // Tri et filtres
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _FilterChip(
                          label: 'Récents',
                          isSelected: true,
                          onSelected: (selected) {},
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FilterChip(
                          label: 'Montant ⬆️',
                          isSelected: false,
                          onSelected: (selected) {},
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FilterChip(
                          label: 'Articles ⬆️',
                          isSelected: false,
                          onSelected: (selected) {},
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Liste des sessions
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.sessions.length,
                    itemBuilder: (context, index) {
                      final session = widget.sessions[index];
                      return _SessionCard(
                        session: session,
                        onTap: () => widget.onSessionSelected(session),
                        onDelete: () => widget.onSessionDeleted(session),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// 🎫 Puce de filtre
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Function(bool) onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onSelected(!isSelected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primary.withOpacity(0.2)
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// 📦 Carte de session
class _SessionCard extends StatelessWidget {
  final ScanSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassmorphism(blur: 15, opacity: 0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session #${session.id.substring(0, 6)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(session.date),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                  color: AppTheme.surfaceDark,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Text(
                        'Voir les détails',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Supprimer',
                        style: TextStyle(color: AppTheme.error),
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'view') {
                      onTap();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Statistiques
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SessionStat(
                  icon: Icons.shopping_bag,
                  label: 'Articles',
                  value: session.items.length.toString(),
                  color: AppTheme.primary,
                ),
                _SessionStat(
                  icon: Icons.euro,
                  label: 'Total',
                  value: session.totalAmount.toStringAsFixed(2),
                  color: AppTheme.accent,
                  suffix: '€',
                ),
                _SessionStat(
                  icon: Icons.access_time,
                  label: 'Durée',
                  value: _formatDuration(session),
                  color: AppTheme.secondary,
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Aperçu des articles
            if (session.items.length <= 3)
              ...session.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PriceCardCompact(item: item),
              )).toList()
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...session.items.take(2).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PriceCardCompact(item: item),
                  )).toList(),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 8),
                    child: Text(
                      '+ ${session.items.length - 2} autres',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours < 1) {
        return 'À l\'instant';
      }
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatDuration(ScanSession session) {
    if (session.endDate == null) {
      return '-';
    }
    
    final duration = session.endDate!.difference(session.date);
    
    if (duration.inMinutes < 1) {
      return ' quelques sec';
    } else if (duration.inHours < 1) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inHours}h${duration.inMinutes % 60}m';
    }
  }
}

// 📈 Statistique de session
class _SessionStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? suffix;

  const _SessionStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

// 📭 État vide
class _EmptyHistoryState extends StatelessWidget {
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
              gradient: LinearGradient(
                colors: [AppTheme.secondary.withOpacity(0.8), AppTheme.primary.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.history,
              color: Colors.white,
              size: 50,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun historique',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Vos sessions de scan apparaissent ici. Sauvegardez une session pour la consulter ultérieurement.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
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
        'Cette action supprimera tout l\'historique. Vous ne pourrez pas annuler.',
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

