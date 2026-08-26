import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../screens/profile_screen.dart';
import '../utils/debt_simplifier.dart';
import '../utils/format_utils.dart';

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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onSettle ??
            () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(memberId: settlement.from),
                ),
              );
            },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFEF4444).withOpacity(0.12),
                child: Text(
                  fromMember.name.isNotEmpty ? fromMember.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const TextSpan(text: ' pays '),
                          TextSpan(
                            text: toMember.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    if (onSettle != null)
                      const Text(
                        'Tap to record settlement payment',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      )
                    else
                      const Text(
                        'Tap to view ledger & history',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  FormatUtils.formatCurrency(settlement.amount, config.currency),
                  style: const TextStyle(
                    color: Color(0xFF047857),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettlementSummaryCard extends StatelessWidget {
  final List<Settlement> settlements;
  final AppConfig config;

  const SettlementSummaryCard({
    super.key,
    required this.settlements,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    if (settlements.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'All balances are settled! No debt outstanding.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.handshake_outlined, color: Color(0xFF059669), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Debt Simplification Plan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...settlements.map((s) => SettlementCard(settlement: s, config: config)),
          ],
        ),
      ),
    );
  }
}
