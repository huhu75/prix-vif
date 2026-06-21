import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets/price_card.dart';

// 📋 Écran de détail d'une session
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
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Session #${session.id.substring(0, 6)}',
          style: theme.appBarTheme.titleTextStyle,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: onBack,
        ),
      ),
      body: Column(
        children: [
          // En-tête avec infos
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.glassmorphism(blur: 15, opacity: 0.1),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _DetailStat(
                      icon: Icons.calendar_today,
                      label: 'Date',
                      value: _formatDate(session.date),
                      color: AppTheme.primary,
                    ),
                    _DetailStat(
                      icon: Icons.shopping_bag,
                      label: 'Articles',
                      value: session.items.length.toString(),
                      color: AppTheme.accent,
                    ),
                    _DetailStat(
                      icon: Icons.euro,
                      label: 'Total',
                      value: session.totalAmount.toStringAsFixed(2),
                      color: AppTheme.secondary,
                      suffix: '€',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(
                  color: Color(0xFF2D2D2D),
                  height: 1,
                ),
                const SizedBox(height: 16),
                if (session.endDate != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: AppTheme.textMuted,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Durée: ${_formatDuration(session)}',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Liste des articles
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: session.items.length,
              itemBuilder: (context, index) {
                final item = session.items[index];
                return PriceCard(
                  item: item,
                  onTap: onItemTap,
                  showQuantity: true,
                  showDate: true,
                );
              },
            ),
          ),
          
          // Total en bas
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${session.items.length} articles',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      session.totalAmount.toStringAsFixed(2),
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(width: 4),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDuration(ScanSession session) {
    if (session.endDate == null) {
      return 'Non terminée';
    }
    
    final duration = session.endDate!.difference(session.date);
    
    if (duration.inMinutes < 1) {
      return 'quelques secondes';
    } else if (duration.inHours < 1) {
      return '${duration.inMinutes} min';
    } else {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return minutes > 0 ? '$hours h $minutes min' : '$hours h';
    }
  }
}

// 📊 Statistique détaillée
class _DetailStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? suffix;

  const _DetailStat({
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
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}
