import 'package:flutter_test/flutter_test.dart';
import 'package:fund/models/config.dart';
import 'package:fund/models/fund_data.dart';
import 'package:fund/models/transaction.dart';
import 'package:fund/services/calculations.dart';

void main() {
  group('Calculations Engine', () {
    const people = [
      MemberConfig(id: 'alice', name: 'Alice'),
      MemberConfig(id: 'bob', name: 'Bob'),
      MemberConfig(id: 'charlie', name: 'Charlie'),
    ];

    test('calculateBalances with credits and expenses', () {
      final transactions = [
        Transaction(
          id: 'tx1',
          type: TransactionType.credit,
          amount: 300,
          actorId: 'alice',
          note: 'Alice deposit',
          timestamp: '2026-08-01T10:00:00Z',
        ),
        Transaction(
          id: 'tx2',
          type: TransactionType.expense,
          amount: 90,
          actorId: null,
          targetId: 'groceries',
          participantIds: ['alice', 'bob', 'charlie'],
          note: 'Group grocery',
          timestamp: '2026-08-02T10:00:00Z',
        ),
      ];

      final data = FundData(transactions: transactions);
      final balances = Calculations.calculateBalances(data, people);

      // Alice: +300 - 30 = 270
      // Bob: -30
      // Charlie: -30
      expect(balances['alice'], 270.0);
      expect(balances['bob'], -30.0);
      expect(balances['charlie'], -30.0);
    });

    test('calculateDebtSettlements minimizes transactions', () {
      final balances = {
        'alice': 200.0,
        'bob': -100.0,
        'charlie': -100.0,
      };

      final settlements = Calculations.calculateDebtSettlements(balances);
      expect(settlements.length, 2);

      final bobSettlement = settlements.firstWhere((s) => s.from == 'bob');
      expect(bobSettlement.to, 'alice');
      expect(bobSettlement.amount, 100.0);

      final charlieSettlement = settlements.firstWhere((s) => s.from == 'charlie');
      expect(charlieSettlement.to, 'alice');
      expect(charlieSettlement.amount, 100.0);
    });

    test('totals calculates correct credits and debits', () {
      final data = FundData(
        transactions: [
          Transaction(
            id: '1',
            type: TransactionType.credit,
            amount: 500,
            note: 'Initial pool',
            timestamp: '2026-08-01T00:00:00Z',
          ),
          Transaction(
            id: '2',
            type: TransactionType.expense,
            amount: 150,
            note: 'Dinner',
            timestamp: '2026-08-02T00:00:00Z',
          ),
          Transaction(
            id: '3',
            type: TransactionType.debit,
            amount: 50,
            note: 'Internet',
            timestamp: '2026-08-03T00:00:00Z',
          ),
        ],
      );

      final totals = Calculations.totals(data);
      expect(totals.credits, 500.0);
      expect(totals.debits, 200.0);
    });
  });
}
