import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets/price_card.dart';
import '../widgets/magic_title.dart';

class SessionDetailScreen extends StatelessWidget {
  final ScanSession session;
  final VoidCallback onBack;
  final VoidCallback? onItemTap;

  const SessionDetailScreen({
    super.key,
    required this.session,
    required this.onBack,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stores = session.items.map((i) => i.storeName).toSet();
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const NeonTitle(text: 'DÉTAILS', fontSize: 22),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: onBack,
        ),
      ),
      body: Column(
        children: [
          // En-tête
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(session.date),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stores.join(' • '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Statistiques
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatItem(
                  icon: Icons.shopping_bag,
                  label: 'Articles',
                  value: session.items.length.toString(),
                ),
                const SizedBox(width: 12),
                _StatItem(
                  icon: Icons.euro,
                  label: 'Total',
                  value: session.totalAmount.toStringAsFixed(2),
                  suffix: '€',
                ),
                const SizedBox(width: 12),
                _StatItem(
                  icon: Icons.access_time,
                  label: 'Durée',
                  value: _formatDuration(session),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Liste des articles
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: session.items.length,
              itemBuilder: (context, index) {
                final item = session.items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PriceCard(
                    item: item,
                    onTap: onItemTap,
                    showQuantity: true,
                    showDate: true,
                  ),
                );
              },
            ),
          ),
        ],
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

// Élément de stat
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? suffix;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
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
