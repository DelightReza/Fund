import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../screens/profile_screen.dart';
import '../theme/app_theme.dart';
import '../utils/debt_simplifier.dart';
import '../utils/format_utils.dart';
import 'glass_container.dart';

class SettlementCard extends StatelessWidget {
  final Settlement settlement;
  final AppConfig config;
  final VoidCallback? onSettle;

  const SettlementCard({
    super.key,
    required this.settlement,
    required this.config,
    this.onSettle,
  });

  @override
  Widget build(BuildContext context) {
    final fromMember = config.members.firstWhere(
      (m) => m.id == settlement.from,
      orElse: () => MemberConfig(id: settlement.from, name: settlement.from),
    );
    final toMember = config.members.firstWhere(
      (m) => m.id == settlement.to,
      orElse: () => MemberConfig(id: settlement.to, name: settlement.to),
    );

    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 4.5),
      borderRadius: 18,
      padding: EdgeInsets.zero,
      onTap: onSettle ??
          () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileScreen(memberId: settlement.from),
              ),
            );
          },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: AppTheme.roseGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.roseCrimson.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                fromMember.name.isNotEmpty
                    ? fromMember.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: AppTheme.electricViolet.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 8),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: AppTheme.emeraldGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.emeraldGreen.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                toMember.name.isNotEmpty ? toMember.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: fromMember.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const TextSpan(text: ' pays '),
                        TextSpan(
                          text: toMember.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    onSettle != null
                        ? 'Tap to record settlement payment'
                        : 'Tap to view ledger & history',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.emeraldGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.emeraldGreen.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                FormatUtils.formatCurrency(settlement.amount, config.currency),
                style: const TextStyle(
                  color: AppTheme.emeraldDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
