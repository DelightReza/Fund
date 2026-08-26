import 'package:flutter_test/flutter_test.dart';
import 'package:fund/models/app_config.dart';
import 'package:fund/models/fund_data.dart';
import 'package:fund/models/transaction.dart';
import 'package:fund/utils/debt_simplifier.dart';

void main() {
  group('BalanceEngine & Multi-Party Split Verification', () {
    final config = AppConfig(
      currency: '₹',
      members: [
        MemberConfig(id: 'alice', name: 'Alice'),
        MemberConfig(id: 'bob', name: 'Bob'),
        MemberConfig(id: 'charlie', name: 'Charlie'),
      ],
      billTypes: [
        BillTypeConfig(id: 'groceries', name: 'Groceries', icon: '🛒'),
        BillTypeConfig(id: 'utilities', name: 'Utilities', icon: '💡'),
      ],
    );

    test('correctly credits payer and debits split members', () {
      final data = FundData(
        transactions: [
          // Alice deposits 300
          TransactionModel(
            id: 'tx1',
            type: 'credit',
            payerId: 'alice',
            whoOrBill: 'alice',
            amount: 300,
            note: 'Alice deposit',
            date: '2026-08-20',
          ),
          // Group expense of 300 split across all 3
          TransactionModel(
            id: 'tx2',
            type: 'debit',
            billTypeId: 'groceries',
            whoOrBill: 'groceries',
            amount: 300,
            note: 'Grocery bill',
            date: '2026-08-20',
            splitAmong: ['alice', 'bob', 'charlie'],
          ),
        ],
      );

      final balances = BalanceEngine.calculateBalances(data, config);
      expect(balances['alice'], 200.0);
      expect(balances['bob'], -100.0);
      expect(balances['charlie'], -100.0);

      final settlements = BalanceEngine.calculateDebtSettlements(balances);
      expect(settlements.length, 2);
      expect(
        settlements.any((s) => s.from == 'bob' && s.to == 'alice' && s.amount == 100.0),
        isTrue,
      );
      expect(
        settlements.any((s) => s.from == 'charlie' && s.to == 'alice' && s.amount == 100.0),
        isTrue,
      );
    });

    test('correctly handles exemptions in debit calculations', () {
      final data = FundData(
        transactions: [
          // Bob pays 200 for utilities with charlie exempt
          TransactionModel(
            id: 'tx_b_credit',
            type: 'credit',
            payerId: 'bob',
            whoOrBill: 'bob',
            amount: 200,
            note: 'Bob paid utilities',
            date: '2026-08-20',
          ),
          TransactionModel(
            id: 'tx_b_debit',
            type: 'debit',
            billTypeId: 'utilities',
            whoOrBill: 'utilities',
            amount: 200,
            note: 'Utilities for alice and bob only',
            date: '2026-08-20',
            exemptions: ['charlie'],
          ),
        ],
      );

      final balances = BalanceEngine.calculateBalances(data, config);
      expect(balances['bob'], 100.0);
      expect(balances['alice'], -100.0);
      expect(balances['charlie'], 0.0);
    });
  });
}
