import '../models/config.dart';
import '../models/fund_data.dart';
import '../models/settlement.dart';
import '../models/transaction.dart';

class Calculations {
  static Map<String, double> calculateBalances(FundData data, List<MemberConfig> members) {
    final balances = <String, double>{
      for (final member in members) member.id: 0,
    };

    final activeIds = members.where((m) => m.active).map((m) => m.id).toList();

    for (final tx in data.transactions) {
      switch (tx.type) {
        case TransactionType.credit:
          if (tx.actorId case final actor?) {
            balances[actor] = (balances[actor] ?? 0) + tx.amount;
          }
          break;
        case TransactionType.debit:
          final participants = _participants(tx, activeIds);
          if (participants.isEmpty) continue;
          final each = tx.amount / participants.length;
          for (final id in participants) {
            balances[id] = (balances[id] ?? 0) - each;
          }
          break;
        case TransactionType.expense:
          if (tx.actorId case final actor?) {
            balances[actor] = (balances[actor] ?? 0) + tx.amount;
          }
          final participants = _participants(tx, activeIds);
          if (participants.isEmpty) continue;
          final each = tx.amount / participants.length;
          for (final id in participants) {
            balances[id] = (balances[id] ?? 0) - each;
          }
          break;
        case TransactionType.distribution:
          final participants = _participants(tx, activeIds);
          if (participants.isEmpty) continue;
          final each = tx.amount / participants.length;
          for (final id in participants) {
            balances[id] = (balances[id] ?? 0) + each;
          }
          break;
        case TransactionType.settlement:
          if (tx.actorId case final from?) {
            balances[from] = (balances[from] ?? 0) + tx.amount;
          }
          if (tx.targetId case final to?) {
            balances[to] = (balances[to] ?? 0) - tx.amount;
          }
          break;
        case TransactionType.transfer:
          if (tx.actorId case final from?) {
            balances[from] = (balances[from] ?? 0) - tx.amount;
          }
          if (tx.targetId case final to?) {
            balances[to] = (balances[to] ?? 0) + tx.amount;
          }
          break;
      }
    }

    return balances;
  }

  static Map<String, double> calculateBillTotals(FundData data) {
    final totals = <String, double>{};
    for (final tx in data.transactions) {
      if (tx.type == TransactionType.debit || tx.type == TransactionType.expense) {
        final key = tx.targetId ?? 'others';
        totals[key] = (totals[key] ?? 0) + tx.amount;
      }
    }
    return totals;
  }

  static List<Settlement> calculateDebtSettlements(Map<String, double> balances) {
    final creditors = balances.entries.where((e) => e.value > 0.01).toList();
    final debtors = balances.entries.where((e) => e.value < -0.01).toList();

    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => a.value.compareTo(b.value));

    var i = 0;
    var j = 0;

    final suggestions = <Settlement>[];

    final creditLeft = creditors.map((e) => MapEntry(e.key, e.value)).toList();
    final debtLeft = debtors.map((e) => MapEntry(e.key, -e.value)).toList();

    while (i < debtLeft.length && j < creditLeft.length) {
      final debtor = debtLeft[i];
      final creditor = creditLeft[j];

      final amount = debtor.value < creditor.value ? debtor.value : creditor.value;
      suggestions.add(Settlement(from: debtor.key, to: creditor.key, amount: amount));

      debtLeft[i] = MapEntry(debtor.key, debtor.value - amount);
      creditLeft[j] = MapEntry(creditor.key, creditor.value - amount);

      if (debtLeft[i].value <= 0.01) i++;
      if (creditLeft[j].value <= 0.01) j++;
    }

    return suggestions;
  }

  static ({double credits, double debits}) totals(FundData data) {
    var credits = 0.0;
    var debits = 0.0;

    for (final tx in data.transactions) {
      if (tx.type == TransactionType.credit || tx.type == TransactionType.expense || tx.type == TransactionType.distribution) {
        credits += tx.amount;
      }
      if (tx.type == TransactionType.debit || tx.type == TransactionType.expense) {
        debits += tx.amount;
      }
    }

    return (credits: credits, debits: debits);
  }

  static List<String> _participants(Transaction tx, List<String> activeIds) {
    if (tx.participantIds.isNotEmpty) return tx.participantIds;
    if (tx.exemptions.isNotEmpty) {
      return activeIds.where((id) => !tx.exemptions.contains(id)).toList();
    }
    return activeIds;
  }
}
