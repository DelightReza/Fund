import 'package:flutter/material.dart';

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
    final isPositive = net >= 0;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(
                FormatUtils.currency(net, currency),
                style: TextStyle(
                  color: isPositive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
