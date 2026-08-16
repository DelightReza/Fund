import 'package:flutter_test/flutter_test.dart';
import 'package:fund/models/config.dart';
import 'package:fund/models/fund_data.dart';
import 'package:fund/models/transaction.dart';

void main() {
  group('Models Serialization and Legacy Compatibility', () {
    test('AppConfig toJson and fromJson roundtrip', () {
      const config = AppConfig(
        siteTitle: 'My Fund',
        siteSubtitle: 'Shared Expenses',
        currency: 'USD',
        repoOwner: 'DelightReza',
        repoName: 'Fund-Template-App',
        repoBranch: 'main',
        dataFileName: 'data.json',
        people: [
          MemberConfig(id: 'reza', name: 'Reza', active: true),
        ],
        billTypes: [
          BillTypeConfig(id: 'food', name: 'Food', icon: '🍲'),
        ],
      );

      final json = config.toJson();
      final parsed = AppConfig.fromJson(json);

      expect(parsed.siteTitle, 'My Fund');
      expect(parsed.currency, 'USD');
      expect(parsed.repoOwner, 'DelightReza');
      expect(parsed.people.first.name, 'Reza');
      expect(parsed.billTypes.first.icon, '🍲');
    });

    test('Transaction toJson and fromJson roundtrip', () {
      final tx = Transaction(
        id: 'tx_123',
        type: TransactionType.expense,
        amount: 45.5,
        actorId: null,
        targetId: 'food',
        participantIds: ['p1', 'p2'],
        note: 'Pizza night',
        timestamp: '2026-08-15T12:00:00Z',
        parentId: 'parent_abc',
        distributionTotal: 100.0,
      );

      final json = tx.toJson();
      final parsed = Transaction.fromJson(json);

      expect(parsed.id, 'tx_123');
      expect(parsed.type, TransactionType.expense);
      expect(parsed.amount, 45.5);
      expect(parsed.targetId, 'food');
      expect(parsed.participantIds, ['p1', 'p2']);
      expect(parsed.note, 'Pizza night');
      expect(parsed.parentId, 'parent_abc');
      expect(parsed.distributionTotal, 100.0);
    });

    test('Legacy React and Kotlin JSON format compatibility', () {
      final legacyExpense = {
        'id': 'legacy_1',
        'type': 'expense',
        'amount': '75.50',
        'date': '2026-08-10T12:00:00Z',
        'payerId': 'user_1',
        'billTypeId': 'electricity',
        'splitAmong': ['user_1', 'user_2'],
        'note': 'Power bill',
      };

      final parsed = Transaction.fromJson(legacyExpense);
      expect(parsed.id, 'legacy_1');
      expect(parsed.type, TransactionType.expense);
      expect(parsed.amount, 75.50);
      expect(parsed.actorId, 'user_1');
      expect(parsed.targetId, 'electricity');
      expect(parsed.participantIds, ['user_1', 'user_2']);

      final legacyCredit = {
        'id': 'legacy_2',
        'type': 'credit',
        'amount': 200,
        'whoOrBill': 'user_3',
        'timestamp': '2026-08-11T12:00:00Z',
      };

      final parsedCredit = Transaction.fromJson(legacyCredit);
      expect(parsedCredit.actorId, 'user_3');
      expect(parsedCredit.amount, 200.0);
    });

    test('FundData roundtrip', () {
      final data = FundData(
        transactions: [
          Transaction(
            id: 't1',
            type: TransactionType.credit,
            amount: 100,
            note: 'Top up',
            timestamp: '2026-08-15T00:00:00Z',
          )
        ],
      );

      final json = data.toJson();
      final parsed = FundData.fromJson(json);

      expect(parsed.transactions.length, 1);
      expect(parsed.transactions.first.amount, 100.0);
    });
  });
}
