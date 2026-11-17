// Derniers scans
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models.dart';

class RecentScansSection extends StatelessWidget {
  final List<ScanSession> sessions;
  final Function(ScanSession) onSessionSelected;

  const RecentScansSection({
    super.key,
    required this.sessions,
    required this.onSessionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recentSessions = sessions.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Derniers scans',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...recentSessions.map((session) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _RecentSessionCard(
            session: session,
            onTap: () => onSessionSelected(session),
          ),
        )),
        
        if (sessions.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '+ ${sessions.length - 3} autres scans',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

/// Carte de scan récent
class _RecentSessionCard extends StatelessWidget {
  final ScanSession session;
  final VoidCallback onTap;

  const _RecentSessionCard({
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stores = session.items.map((i) => i.storeName).toSet();
    final storeLabel = stores.isEmpty ? '-' : stores.join(', ');
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppTheme.glassmorphism(),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                session.type == 'ticket' ? Icons.receipt_long : Icons.qr_code_scanner,
                color: session.type == 'ticket' ? AppTheme.secondary : AppTheme.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(session.date),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    storeLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${session.items.length} articles',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.totalAmount.toStringAsFixed(2),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
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
      return 'Aujourd\'hui';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
