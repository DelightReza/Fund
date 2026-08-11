
import 'package:flutter/material.dart';
import '../utils/format_utils.dart';

class BalanceCard extends StatelessWidget {
  final String name;
  final double amount;
  final String currency;

  const BalanceCard({
    super.key,
    required this.name,
    required this.amount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = amount >= 0;
    return Card(
      child: ListTile(
        title: Text(name),
        trailing: Text(
          FormatUtils.formatCurrency(amount, currency),
          style: TextStyle(color: isPositive ? Colors.green : Colors.red),
        ),
      ),
    );
  }
}

