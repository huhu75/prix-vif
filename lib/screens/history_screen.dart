import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets/price_card.dart';
import '../widgets/magic_button.dart';

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
  String? _selectedStoreFilter;

  List<ScanSession> get _filteredSessions {
    if (_selectedStoreFilter == null) {
      return widget.sessions;
    }
    return widget.sessions
        .where((session) => 
            session.items.any((item) => item.storeName == _selectedStoreFilter))
        .toList();
  }

  Set<String> get _availableStores {
    final stores = <String>{};
    for (final session in widget.sessions) {
      for (final item in session.items) {
        if (item.storeName != null) {
          stores.add(item.storeName!);
        }
      }
    }
    return stores;
  }

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
                // Filtres par magasin
                if (_availableStores.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: const Text('Tous'),
                              selected: _selectedStoreFilter == null,
                              onSelected: (_) {
                                setState(() {
                                  _selectedStoreFilter = null;
                                });
                              },
                              backgroundColor: AppTheme.surfaceDark,
                              selectedColor: AppTheme.primary.withOpacity(0.15),
                              labelStyle: TextStyle(
                                color: _selectedStoreFilter == null 
                                    ? AppTheme.primary 
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              side: BorderSide(
                                color: _selectedStoreFilter == null
                                    ? AppTheme.primary
                                    : Colors.black.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                          ),
                          ..._availableStores.map((store) {
                            final isSelected = _selectedStoreFilter == store;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(store),
                                selected: isSelected,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedStoreFilter = isSelected ? null : store;
                                  });
                                },
                                backgroundColor: AppTheme.surfaceDark,
                                selectedColor: AppTheme.primary.withOpacity(0.15),
                                labelStyle: TextStyle(
                                  color: isSelected 
                                      ? AppTheme.primary 
                                      : AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppTheme.primary
                                      : Colors.black.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                
                // Liste des sessions
                Expanded(
                  child: _filteredSessions.isEmpty
                      ? Center(
                          child: Text(
                            'Aucune session pour ce magasin',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          itemCount: _filteredSessions.length,
                          itemBuilder: (context, index) {
                            final session = _filteredSessions[index];
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

// Carte de session
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
    final stores = session.items.map((i) => i.storeName).toSet();
    final storeLabel = stores.isEmpty ? '-' : stores.join(', ');
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppTheme.glassmorphism(),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                          '${_formatDate(session.date)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          storeLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 18),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Statistiques
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SessionStat(
                    icon: Icons.shopping_bag,
                    label: 'Articles',
                    value: session.items.length.toString(),
                  ),
                  _SessionStat(
                    icon: Icons.euro,
                    label: 'Total',
                    value: session.totalAmount.toStringAsFixed(2),
                    suffix: '€',
                  ),
                  _SessionStat(
                    icon: Icons.access_time,
                    label: 'Durée',
                    value: _formatDuration(session),
                  ),
                ],
              ),
              
              // Aperçu des articles
              if (session.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 10),
                ...session.items.take(2).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: PriceCardCompact(item: item),
                )).toList(),
                if (session.items.length > 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '+ ${session.items.length - 2} autre${session.items.length - 2 > 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Aujourd\'hui';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} j';
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
      return '< 1m';
    } else if (duration.inHours < 1) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inHours}h${(duration.inMinutes % 60).toString().padLeft(2, '0')}m';
    }
  }
}

// Statistique de session
class _SessionStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? suffix;

  const _SessionStat({
    required this.icon,
    required this.label,
    required this.value,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        if (suffix != null)
          Text(
            suffix!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
              fontSize: 10,
            ),
          ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// État vide
class _EmptyHistoryState extends StatelessWidget {
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
              Icons.history,
              color: AppTheme.primary,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun historique',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Vos sessions de scan apparaîtront ici',
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
        'L\'historique sera perdu. Vous ne pourrez pas annuler.',
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
