import 'dart:math';
import '../models/app_config.dart';
import '../models/fund_data.dart';
import '../models/transaction.dart';

class Settlement {
  final String from;
  final String to;
  final double amount;

  Settlement({
    required this.from,
    required this.to,
    required this.amount,
  });
}

class MemberFinancialSummary {
  final String memberId;
  final double totalPaid;
  final double totalConsumed;
  final double netBalance;

  MemberFinancialSummary({
    required this.memberId,
    required this.totalPaid,
    required this.totalConsumed,
    required this.netBalance,
  });
}

class PersonTransactionItem {
  final TransactionModel transaction;
  final String displayTitle;
  final String displayType;
  final String sign; // '+' or '-'
  final double displayAmount;
  final double change;
  final double runningBalance;
  final double balanceBefore;
  final double balanceAfter;
  final double splitPerPerson;
  final List<String> splitMembers;

  PersonTransactionItem({
    required this.transaction,
    required this.displayTitle,
    required this.displayType,
    required this.sign,
    required this.displayAmount,
    required this.change,
    required this.runningBalance,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.splitPerPerson,
    required this.splitMembers,
  });
}

class BalanceEngine {
  /// Sort transactions chronologically
  static List<TransactionModel> sortTransactions(
    List<TransactionModel> transactions, {
    bool ascending = true,
  }) {
    final list = List<TransactionModel>.from(transactions);
    list.sort((a, b) {
      final timeA = DateTime.tryParse(a.date)?.millisecondsSinceEpoch ?? 0;
      final timeB = DateTime.tryParse(b.date)?.millisecondsSinceEpoch ?? 0;
      int diff = 0;
      if (timeA != timeB) {
        diff = timeA.compareTo(timeB);
      } else {
        final parentA = (a.parentId != null && a.parentId!.isNotEmpty) ? a.parentId! : a.id;
        final parentB = (b.parentId != null && b.parentId!.isNotEmpty) ? b.parentId! : b.id;
        if (parentA == parentB) {
          if (a.type != b.type) {
            diff = a.type == 'credit' ? -1 : 1;
          } else {
            diff = a.id.compareTo(b.id);
          }
        } else {
          diff = parentA.compareTo(parentB);
          if (diff == 0) {
            diff = a.id.compareTo(b.id);
          }
        }
      }
      return ascending ? diff : -diff;
    });
    return list;
  }

  /// Calculates a complete chronological timeline of transactions for a specific member,
  /// with exact change, share, and running balance after each transaction.
  static List<PersonTransactionItem> calculatePersonTimeline(
    FundData data,
    AppConfig config,
    String personId,
  ) {
    final allIds = config.members.map((m) => m.id).toList();
    final chronological = sortTransactions(data.transactions, ascending: true);

    double running = 0.0;
    final balanceMap = <String, Map<String, double>>{}; // tx.id -> {before, after, change}

    for (final tx in chronological) {
      double change = 0.0;
      final isCredit = tx.type == 'credit';
      final payer = (tx.payerId != null && tx.payerId!.isNotEmpty) ? tx.payerId! : tx.whoOrBill;

      if (isCredit && payer == personId) {
        change += tx.amount;
      } else if (!isCredit) {
        if (tx.customSplit != null && tx.customSplit!.isNotEmpty) {
          if (tx.customSplit!.containsKey(personId)) {
            change -= (tx.customSplit![personId] ?? 0.0);
          }
        } else {
          List<String> paying;
          if (tx.cleanSplitMembers.isNotEmpty) {
            paying = tx.cleanSplitMembers;
          } else if (tx.splitAmong != null && tx.splitAmong!.isNotEmpty) {
            paying = tx.splitAmong!;
          } else {
            final exemptions = tx.exemptions ?? [];
            paying = allIds.where((id) => !exemptions.contains(id)).toList();
          }

          if (paying.contains(personId) && paying.isNotEmpty) {
            change -= (tx.amount / paying.length);
          }
        }
      }

      final before = running;
      running += change;
      final after = running;

      balanceMap[tx.id] = {
        'before': before,
        'after': after,
        'change': change,
      };
    }

    final items = <PersonTransactionItem>[];

    for (final tx in chronological) {
      final isCredit = tx.type == 'credit';
      final payer = (tx.payerId != null && tx.payerId!.isNotEmpty) ? tx.payerId! : tx.whoOrBill;
      final mapData = balanceMap[tx.id] ?? {'before': 0.0, 'after': 0.0, 'change': 0.0};
      final change = mapData['change']!;
      final before = mapData['before']!;
      final after = mapData['after']!;

      if (isCredit) {
        if (payer == personId) {
          final payerMember = config.members.firstWhere(
            (m) => m.id == payer,
            orElse: () => MemberConfig(id: payer, name: payer),
          );
          final String title = tx.note.trim().isNotEmpty
              ? tx.note.trim()
              : (payerMember.name.isNotEmpty ? payerMember.name : 'Credit Deposit');

          items.add(
            PersonTransactionItem(
              transaction: tx,
              displayTitle: title,
              displayType: 'Credit',
              sign: '+',
              displayAmount: tx.amount,
              change: change,
              runningBalance: after,
              balanceBefore: before,
              balanceAfter: after,
              splitPerPerson: 0.0,
              splitMembers: const [],
            ),
          );
        }
      } else {
        final hasCustom = tx.customSplit != null && tx.customSplit!.isNotEmpty;
        List<String> paying;
        if (hasCustom) {
          paying = tx.customSplit!.keys.toList();
        } else if (tx.splitAmong != null && tx.splitAmong!.isNotEmpty) {
          paying = tx.splitAmong!;
        } else {
          final exemptions = tx.exemptions ?? [];
          paying = allIds.where((id) => !exemptions.contains(id)).toList();
        }

        final isInvolved = hasCustom ? tx.customSplit!.containsKey(personId) : paying.contains(personId);
        if (isInvolved) {
          final share = hasCustom
              ? (tx.customSplit![personId] ?? 0.0)
              : (paying.isNotEmpty ? (tx.amount / paying.length) : 0.0);
          final bill = config.billTypes.firstWhere(
            (b) => b.id == (tx.billTypeId ?? tx.whoOrBill),
            orElse: () => BillTypeConfig(id: tx.whoOrBill, name: tx.whoOrBill, icon: '🧾'),
          );
          final String title = tx.note.trim().isNotEmpty
              ? tx.note.trim()
              : bill.name;

          items.add(
            PersonTransactionItem(
              transaction: tx,
              displayTitle: title,
              displayType: hasCustom ? 'Custom Debit Share' : 'Debit Share',
              sign: '-',
              displayAmount: share,
              change: change,
              runningBalance: after,
              balanceBefore: before,
              balanceAfter: after,
              splitPerPerson: share,
              splitMembers: paying,
            ),
          );
        }
      }
    }

    // Return descending (newest first)
    return items.reversed.toList();
  }

  /// Calculates a member's running balance before and after a specific transaction
  static Map<String, double> calculatePersonRunningBalanceForTx(
    List<TransactionModel> allTransactions,
    String targetTxId,
    String personId,
    List<String> allMemberIds,
  ) {
    double running = 0.0;
    final sorted = sortTransactions(allTransactions, ascending: true);
    double balanceBefore = 0.0;
    double balanceAfter = 0.0;
    double personShare = 0.0;
    bool found = false;

    for (final tx in sorted) {
      double change = 0.0;
      final isCredit = tx.type == 'credit';
      final payer = (tx.payerId != null && tx.payerId!.isNotEmpty) ? tx.payerId! : tx.whoOrBill;

      if (isCredit && payer == personId) {
        change += tx.amount;
      } else if (!isCredit) {
        if (tx.customSplit != null && tx.customSplit!.isNotEmpty) {
          if (tx.customSplit!.containsKey(personId)) {
            change -= (tx.customSplit![personId] ?? 0.0);
          }
        } else {
          List<String> paying;
          if (tx.cleanSplitMembers.isNotEmpty) {
            paying = tx.cleanSplitMembers;
          } else if (tx.splitAmong != null && tx.splitAmong!.isNotEmpty) {
            paying = tx.splitAmong!;
          } else {
            final exemptions = tx.exemptions ?? [];
            paying = allMemberIds.where((id) => !exemptions.contains(id)).toList();
          }

          if (paying.contains(personId) && paying.isNotEmpty) {
            change -= (tx.amount / paying.length);
          }
        }
      }

      if (tx.id == targetTxId) {
        found = true;
        balanceBefore = running;
        balanceAfter = running + change;
        personShare = change;
      }

      running += change;
      if (found) break;
    }

    return {
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'personShare': personShare,
    };
  }

  /// Calculates each member's total deposited/paid (credit) and total consumed/share (debit),
  /// and resulting net balance.
  static Map<String, MemberFinancialSummary> calculateMemberSummaries(
    FundData data,
    AppConfig config,
  ) {
    final paidMap = <String, double>{for (final m in config.members) m.id: 0.0};
    final consumedMap = <String, double>{for (final m in config.members) m.id: 0.0};

    for (final tx in data.transactions) {
      if (tx.type == 'credit') {
        final pid = (tx.payerId != null && tx.payerId!.isNotEmpty) ? tx.payerId! : tx.whoOrBill;
        if (paidMap.containsKey(pid)) {
          paidMap[pid] = (paidMap[pid] ?? 0.0) + tx.amount;
        }
      } else if (tx.type == 'debit') {
        if (tx.customSplit != null && tx.customSplit!.isNotEmpty) {
          for (final entry in tx.customSplit!.entries) {
            if (consumedMap.containsKey(entry.key)) {
              consumedMap[entry.key] = (consumedMap[entry.key] ?? 0.0) + entry.value;
            }
          }
        } else {
          List<String> payers;
          if (tx.cleanSplitMembers.isNotEmpty) {
            payers = tx.cleanSplitMembers;
          } else if (tx.splitAmong != null && tx.splitAmong!.isNotEmpty) {
            payers = tx.splitAmong!;
          } else {
            final exemptions = tx.exemptions ?? [];
            payers = config.members
                .map((m) => m.id)
                .where((id) => !exemptions.contains(id))
                .toList();
          }

          if (payers.isNotEmpty) {
            final share = tx.amount / payers.length;
            for (final pid in payers) {
              if (consumedMap.containsKey(pid)) {
                consumedMap[pid] = (consumedMap[pid] ?? 0.0) + share;
              }
            }
          }
        }
      }
    }

    final summaries = <String, MemberFinancialSummary>{};
    for (final member in config.members) {
      final paid = paidMap[member.id] ?? 0.0;
      final consumed = consumedMap[member.id] ?? 0.0;
      summaries[member.id] = MemberFinancialSummary(
        memberId: member.id,
        totalPaid: paid,
        totalConsumed: consumed,
        netBalance: paid - consumed,
      );
    }
    return summaries;
  }

  /// Calculates net balance map (positive = owed money, negative = owes money)
  static Map<String, double> calculateBalances(FundData data, AppConfig config) {
    final summaries = calculateMemberSummaries(data, config);
    return summaries.map((k, v) => MapEntry(k, v.netBalance));
  }

  /// Calculates bill type totals
  static Map<String, double> calculateBillTypeTotals(FundData data, AppConfig config) {
    final totals = <String, double>{for (final b in config.billTypes) b.id: 0.0};
    for (final tx in data.transactions) {
      if (tx.type == 'debit') {
        final billId = (tx.billTypeId != null && tx.billTypeId!.isNotEmpty)
            ? tx.billTypeId!
            : tx.whoOrBill;
        totals[billId] = (totals[billId] ?? 0.0) + tx.amount;
      }
    }
    return totals;
  }

  /// Total fund balance in bank/hand (Total credits - Total debits)
  static double calculateTotalFundBalance(FundData data) {
    double credits = 0.0;
    double debits = 0.0;
    for (final tx in data.transactions) {
      if (tx.type == 'credit') {
        credits += tx.amount;
      } else if (tx.type == 'debit') {
        debits += tx.amount;
      }
    }
    return credits - debits;
  }

  /// Greedy Debt Simplification Algorithm
  static List<Settlement> calculateDebtSettlements(Map<String, double> balances) {
    final creditors = balances.entries
        .where((e) => e.value > 0.01)
        .map((e) => MapEntry(e.key, e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final debtors = balances.entries
        .where((e) => e.value < -0.01)
        .map((e) => MapEntry(e.key, -e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final settlements = <Settlement>[];
    int i = 0;
    int j = 0;

    while (i < debtors.length && j < creditors.length) {
      final debtor = debtors[i];
      final creditor = creditors[j];
      final amount = min(debtor.value, creditor.value);

      settlements.add(
        Settlement(from: debtor.key, to: creditor.key, amount: amount),
      );

      debtors[i] = MapEntry(debtor.key, debtor.value - amount);
      creditors[j] = MapEntry(creditor.key, creditor.value - amount);

      if (debtors[i].value < 0.01) i++;
      if (creditors[j].value < 0.01) j++;
    }

    return settlements;
  }
}
