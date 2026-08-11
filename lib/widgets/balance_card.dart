import 'package:flutter/material.dart';

import '../utils/format_utils.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.name,
    required this.amount,
    required this.currency,
  });

  final String name;
  final double amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(name),
      trailing: Text(FormatUtils.currency(amount, currency)),
    );
  }
}
