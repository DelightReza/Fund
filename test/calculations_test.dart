import 'package:flutter_test/flutter_test.dart';
import 'package:fund/models/config.dart';
import 'package:fund/models/fund_data.dart';
import 'package:fund/models/transaction.dart';
import 'package:fund/services/calculations.dart';

void main() {
  group('Calculations Engine Parity Tests', () {
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

    test('calculateBalances with settlement and transfer parity', () {
      final transactions = [
        // Bob deposits 100
        Transaction(
          id: 'tx1',
          type: TransactionType.credit,
          amount: 100,
          actorId: 'bob',
          timestamp: '2026-08-01T10:00:00Z',
        ),
        // Charlie transfers 40 to Bob
        Transaction(
          id: 'tx2',
          type: TransactionType.transfer,
          amount: 40,
          actorId: 'charlie',
          targetId: 'bob',
          timestamp: '2026-08-02T10:00:00Z',
        ),
        // Alice settles 20 to Charlie
        Transaction(
          id: 'tx3',
          type: TransactionType.settlement,
          amount: 20,
          actorId: 'alice',
          targetId: 'charlie',
          timestamp: '2026-08-03T10:00:00Z',
        ),
      ];

      final data = FundData(transactions: transactions);
      final balances = Calculations.calculateBalances(data, people);

      // Bob: +100 + 40 = 140
      // Charlie: -40 - 20 = -60
      // Alice: +20 = 20
      expect(balances['bob'], 140.0);
      expect(balances['charlie'], -60.0);
      expect(balances['alice'], 20.0);
    });

    test('calculateBalances with atomic grouped expenses', () {
      final transactions = [
        // Grouped receipt: Alice paid out-of-pocket for food (40) and drinks (20)
        Transaction(
          id: 'child1',
          type: TransactionType.expense,
          amount: 40,
          actorId: 'alice',
          targetId: 'food',
          participantIds: ['alice', 'bob'],
          parentId: 'group_receipt_1',
          timestamp: '2026-08-01T10:00:00Z',
        ),
        Transaction(
          id: 'child2',
          type: TransactionType.expense,
          amount: 20,
          actorId: 'alice',
          targetId: 'drinks',
          participantIds: ['alice', 'bob'],
          parentId: 'group_receipt_1',
          timestamp: '2026-08-01T10:00:00Z',
        ),
      ];

      final data = FundData(transactions: transactions);
      final balances = Calculations.calculateBalances(data, people);

      // Alice paid 60 total, share is 30 -> Net +30
      // Bob share is 30 -> Net -30
      // Charlie -> 0
      expect(balances['alice'], 30.0);
      expect(balances['bob'], -30.0);
      expect(balances['charlie'], 0.0);

      final totals = Calculations.totals(data);
      expect(totals.debits, 60.0);
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
