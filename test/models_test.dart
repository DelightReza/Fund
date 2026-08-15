import 'package:flutter_test/flutter_test.dart';
import 'package:fund/models/config.dart';
import 'package:fund/models/fund_data.dart';
import 'package:fund/models/transaction.dart';

void main() {
  group('Models Serialization', () {
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
      );

      final json = tx.toJson();
      final parsed = Transaction.fromJson(json);

      expect(parsed.id, 'tx_123');
      expect(parsed.type, TransactionType.expense);
      expect(parsed.amount, 45.5);
      expect(parsed.targetId, 'food');
      expect(parsed.participantIds, ['p1', 'p2']);
      expect(parsed.note, 'Pizza night');
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
