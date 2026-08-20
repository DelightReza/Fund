import '../models/config.dart';
import '../models/fund_data.dart';
import '../models/settlement.dart';
import '../models/transaction.dart';

class Calculations {
  /// Calculate net balance for each member:
  /// (Total Credits deposited/paid) - (Total Debits share split)
  static Map<String, double> calculateBalances(FundData data, List<MemberConfig> members) {
    final balances = <String, double>{
      for (final member in members) member.id: 0.0,
    };

    final activeIds = members.where((m) => m.active).map((m) => m.id).toList();

    for (final tx in data.transactions) {
      if (tx.type == TransactionType.credit) {
        final actor = tx.whoOrBill;
        if (actor.isNotEmpty) {
          balances[actor] = (balances[actor] ?? 0.0) + tx.amount;
        }
      } else if (tx.type == TransactionType.debit || tx.type == TransactionType.expense) {
        final participants = _resolveParticipants(tx, activeIds);
        if (participants.isNotEmpty) {
          final each = tx.amount / participants.length;
          for (final id in participants) {
            balances[id] = (balances[id] ?? 0.0) - each;
          }
        }
      } else if (tx.type == TransactionType.distribution) {
        final participants = _resolveParticipants(tx, activeIds);
        if (participants.isNotEmpty) {
          final each = tx.amount / participants.length;
          for (final id in participants) {
            balances[id] = (balances[id] ?? 0.0) + each;
          }
        }
      } else if (tx.type == TransactionType.settlement || tx.type == TransactionType.transfer) {
        final actor = tx.actorId ?? tx.whoOrBill;
        final target = tx.targetId;
        if (actor != null && actor.isNotEmpty) {
          balances[actor] = (balances[actor] ?? 0.0) + tx.amount;
        }
        if (target != null && target.isNotEmpty) {
          balances[target] = (balances[target] ?? 0.0) - tx.amount;
        }
      }
    }

    return balances.map((k, v) => MapEntry(k, double.parse(v.toStringAsFixed(2))));
  }

  /// Calculates total credits (given/deposited) for each person
  /// (This is what is stored in data.json under "people")
  static Map<String, double> calculatePeopleCredits(FundData data, List<MemberConfig> members) {
    final totals = <String, double>{};
    for (final m in members) {
      totals[m.id] = 0.0;
    }

    for (final tx in data.transactions) {
      if (tx.type == TransactionType.credit) {
        final who = tx.whoOrBill;
        if (who.isNotEmpty) {
          totals[who] = (totals[who] ?? 0.0) + tx.amount;
        }
      }
    }

    // Keep only active/positive totals, matching original app behavior
    final result = <String, double>{};
    for (final entry in totals.entries) {
      if (entry.value > 0.0 || members.any((m) => m.id == entry.key && m.active)) {
        result[entry.key] = double.parse(entry.value.toStringAsFixed(2));
      }
    }
    return result;
  }

  /// Calculates total debits (spent) for each bill category
  /// (This is what is stored in data.json under "billTypes")
  static Map<String, double> calculateBillTotals(FundData data, [List<BillTypeConfig>? billTypes]) {
    final totals = <String, double>{};
    if (billTypes != null) {
      for (final b in billTypes) {
        totals[b.id] = 0.0;
      }
    }

    for (final tx in data.transactions) {
      if (tx.type == TransactionType.debit || tx.type == TransactionType.expense) {
        final who = tx.whoOrBill;
        if (who.isNotEmpty) {
          totals[who] = (totals[who] ?? 0.0) + tx.amount;
        }
      }
    }

    final result = <String, double>{};
    for (final entry in totals.entries) {
      if (entry.value > 0.0) {
        result[entry.key] = double.parse(entry.value.toStringAsFixed(2));
      }
    }
    return result;
  }

  /// Net impact of a transaction on a specific member
  static double impactForMember(Transaction tx, String memberId, {List<String>? activeIds}) {
    final active = activeIds ?? const [];
    if (tx.type == TransactionType.credit) {
      return tx.whoOrBill == memberId ? tx.amount : 0.0;
    } else if (tx.type == TransactionType.debit || tx.type == TransactionType.expense) {
      final participants = _resolveParticipants(tx, active);
      if (participants.contains(memberId) && participants.isNotEmpty) {
        return -(tx.amount / participants.length);
      }
      return 0.0;
    } else if (tx.type == TransactionType.distribution) {
      final participants = _resolveParticipants(tx, active);
      if (participants.contains(memberId) && participants.isNotEmpty) {
        return tx.amount / participants.length;
      }
      return 0.0;
    } else if (tx.type == TransactionType.settlement || tx.type == TransactionType.transfer) {
      if (tx.whoOrBill == memberId || tx.actorId == memberId) return tx.amount;
      if (tx.targetId == memberId) return -tx.amount;
      return 0.0;
    }
    return 0.0;
  }

  /// Calculates simplified debts (who owes whom)
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
      final roundedAmount = double.parse(amount.toStringAsFixed(2));
      
      if (roundedAmount > 0) {
        suggestions.add(Settlement(from: debtor.key, to: creditor.key, amount: roundedAmount));
      }

      debtLeft[i] = MapEntry(debtor.key, debtor.value - amount);
      creditLeft[j] = MapEntry(creditor.key, creditor.value - amount);

      if (debtLeft[i].value <= 0.01) i++;
      if (creditLeft[j].value <= 0.01) j++;
    }

    return suggestions;
  }

  /// Calculates total collected credits and total spent debits in the fund
  static ({double credits, double debits}) totals(FundData data) {
    var credits = 0.0;
    var debits = 0.0;

    for (final tx in data.transactions) {
      if (tx.type == TransactionType.credit) {
        if (tx.amount > 0) {
          credits += tx.amount;
        }
      } else if (tx.type == TransactionType.debit || tx.type == TransactionType.expense) {
        debits += tx.amount;
      }
    }

    return (
      credits: double.parse(credits.toStringAsFixed(2)),
      debits: double.parse(debits.toStringAsFixed(2)),
    );
  }

  static List<String> _resolveParticipants(Transaction tx, List<String> activeIds) {
    if (tx.splitAmong != null && tx.splitAmong!.isNotEmpty) {
      return tx.splitAmong!;
    }
    if (tx.exemptions != null && tx.exemptions!.isNotEmpty) {
      return activeIds.where((id) => !tx.exemptions!.contains(id)).toList();
    }
    return activeIds;
  }
}
