
import '../models/fund_data.dart';
import '../models/transaction.dart';
import '../models/settlement.dart';
import '../models/config.dart';

class Calculations {
  /// Compute net balance per person (credits - debits).
  static Map<String, double> calculateBalances(
      FundData data, List<MemberConfig> members) {
    final balances = <String, double>{};
    for (final member in members) {
      balances[member.id] = 0.0;
    }

    for (final tx in data.transactions) {
      if (tx.type == 'credit') {
        final pid = tx.payerId ?? tx.whoOrBill;
        balances[pid] = (balances[pid] ?? 0.0) + tx.amount;
      } else {
        // Debit: split among payers
        List<String> payers;
        if (tx.splitAmong != null && tx.splitAmong!.isNotEmpty) {
          payers = tx.splitAmong!;
        } else {
          final exemptions = tx.exemptions ?? [];
          payers = members.map((m) => m.id).where((id) => !exemptions.contains(id)).toList();
        }
        if (payers.isNotEmpty) {
          final perPerson = tx.amount / payers.length;
          for (final pid in payers) {
            balances[pid] = (balances[pid] ?? 0.0) - perPerson;
          }
        }
      }
    }
    return balances;
  }

  /// Compute debt settlements using greedy algorithm.
  static List<Settlement> calculateDebtSettlements(Map<String, double> balances) {
    final debtors = balances.entries
        .where((e) => e.value < -0.01)
        .map((e) => MapEntry(e.key, -e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final creditors = balances.entries
        .where((e) => e.value > 0.01)
        .map((e) => MapEntry(e.key, e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final settlements = <Settlement>[];
    int i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      final debtor = debtors[i];
      final creditor = creditors[j];
      final amount = debtor.value < creditor.value ? debtor.value : creditor.value;
      settlements.add(Settlement(
        from: debtor.key,
        to: creditor.key,
        amount: amount,
      ));
      debtors[i] = MapEntry(debtor.key, debtor.value - amount);
      creditors[j] = MapEntry(creditor.key, creditor.value - amount);
      if (debtors[i].value < 0.01) i++;
      if (creditors[j].value < 0.01) j++;
    }
    return settlements;
  }

  /// Running balance for a specific person.
  static ({double before, double after}) runningBalanceForPerson(
      FundData data,
      String transactionId,
      String personId,
      List<MemberConfig> members) {
    final allIds = members.map((m) => m.id).toList();
    final sorted = List<Transaction>.from(data.transactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    double running = 0.0;
    double before = 0.0;
    double after = 0.0;
    bool found = false;

    for (final tx in sorted) {
      double change = 0.0;
      if (tx.type == 'credit' && tx.whoOrBill == personId) {
        change = tx.amount;
      } else if (tx.type == 'debit') {
        List<String> payers;
        if (tx.splitAmong != null && tx.splitAmong!.isNotEmpty) {
          payers = tx.splitAmong!;
        } else {
          final exemptions = tx.exemptions ?? [];
          payers = allIds.where((id) => !exemptions.contains(id)).toList();
        }
        if (payers.contains(personId)) {
          change = -tx.amount / payers.length;
        }
      }

      if (tx.id == transactionId) {
        before = running;
        after = running + change;
        found = true;
        break;
      }
      running += change;
    }

    if (!found) {
      // If transaction not found (should not happen), return current running.
      before = running;
      after = running;
    }
    return (before: before, after: after);
  }

  /// Total credits and debits.
  static ({double credits, double debits}) totals(FundData data) {
    double c = 0.0, d = 0.0;
    for (final tx in data.transactions) {
      if (tx.type == 'credit') c += tx.amount;
      else d += tx.amount;
    }
    return (credits: c, debits: d);
  }
}

