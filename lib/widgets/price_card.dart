import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';

// 💳 Carte d'article scanné avec style moderne 2026
class PriceCard extends StatelessWidget {
  final ScannedItem item;
  final VoidCallback? onTap;
  final bool showQuantity;
  final bool showDate;

  const PriceCard({
    super.key,
    required this.item,
    this.onTap,
    this.showQuantity = true,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: AppTheme.glassmorphism(blur: 15, opacity: 0.08),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
            ),
            child: Row(
              children: [
                // Image / Icône
                Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: item.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                ),
                
                // Infos principales
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom + Marque
                        Text(
                          item.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (item.brand != null)
                          Text(
                            item.brand!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        const SizedBox(height: 4),
                        if (showQuantity && item.formattedQuantity.isNotEmpty)
                          Text(
                            item.formattedQuantity,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                // Prix
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.formattedPrice,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      if (showDate)
                        Text(
                          _formatDate(item.scanDate),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
}

// 📄 Carte compacte pour l'historique
class PriceCardCompact extends StatelessWidget {
  final ScannedItem item;
  final VoidCallback? onTap;

  const PriceCardCompact({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icône
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.formattedPrice} • ${_formatDate(item.scanDate)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            
            // Flèche
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted,
              size: 20,
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
    } else {
      return '${date.day}/${date.month}';
    }
  }
}
