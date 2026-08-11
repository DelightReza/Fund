
import 'package:flutter/material.dart';
import '../utils/format_utils.dart';

class MemberCard extends StatelessWidget {
  final String name;
  final double net;
  final double given;
  final String currency;
  final VoidCallback? onTap;

  const MemberCard({
    super.key,
    required this.name,
    required this.net,
    required this.given,
    required this.currency,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = net >= 0;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    FormatUtils.formatCurrency(net, currency),
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Given: ${FormatUtils.formatCurrency(given, currency)}'),
            ],
          ),
        ),
      ),
    );
  }
}

