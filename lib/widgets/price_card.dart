import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';

// 💳 Carte d'article scanné - Design épuré français
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
        decoration: AppTheme.subtleCard(),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête : magasin + date
              if (item.storeName != null || showDate)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (item.storeName != null)
                        Text(
                          item.storeName!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
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
              
              // Contenu principal
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.black.withOpacity(0.05),
                        width: 1,
                      ),
                    ),
                    child: item.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              item.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.shopping_bag_outlined,
                                color: AppTheme.textSecondary,
                                size: 28,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.shopping_bag_outlined,
                            color: AppTheme.textSecondary,
                            size: 28,
                          ),
                  ),
                  const SizedBox(width: 14),
                  
                  // Infos principales
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom du produit
                        Text(
                          item.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        
                        // Marque
                        if (item.brand != null)
                          Text(
                            item.brand!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        
                        // Quantité
                        if (showQuantity && item.formattedQuantity.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              item.formattedQuantity,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Prix - en grand
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item.price.toStringAsFixed(2),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                          height: 1,
                        ),
                      ),
                      Text(
                        item.currency ?? '€',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
        decoration: AppTheme.subtleCard(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icône
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppTheme.textSecondary,
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
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.formattedPrice}${item.storeName != null ? ' • ${item.storeName}' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                        fontSize: 11,
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
