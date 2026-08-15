import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../utils/format_utils.dart';

class MemberCard extends StatelessWidget {
  const MemberCard({
    super.key,
    required this.name,
    required this.net,
    required this.currency,
    this.onTap,
  });

  final String name;
  final double net;
  final String currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = net >= 0;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final badgeBg = isPositive
        ? (theme.brightness == Brightness.dark ? AppColors.emerald900.withOpacity(0.4) : AppColors.emerald50)
        : (theme.brightness == Brightness.dark ? AppColors.rose900.withOpacity(0.4) : AppColors.rose50);

    final badgeFg = isPositive
        ? (theme.brightness == Brightness.dark ? AppColors.emerald300 : AppColors.emerald800)
        : (theme.brightness == Brightness.dark ? AppColors.rose300 : AppColors.rose800);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 14,
                      color: badgeFg,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      FormatUtils.currency(net, currency),
                      style: TextStyle(
                        color: badgeFg,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
