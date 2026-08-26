import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fund/models/app_config.dart';
import 'package:fund/models/fund_data.dart';
import 'package:fund/models/transaction.dart';
import 'package:fund/utils/json_formatter.dart';

void main() {
  group('JSON Contract & Schema Tests', () {
    test('AppConfig parses config.json format correctly', () {
      const sampleConfigJson = '''{
        "siteTitle": "Batch 2026 Fund",
        "siteSubtitle": "Shared expenses",
        "currency": "₹",
        "people": [
          {"id": "reza", "name": "Reza", "active": true},
          {"id": "john", "name": "John", "active": false}
        ],
        "billTypes": [
          {"id": "food", "name": "Food & Snacks", "icon": "🍔", "active": true}
        ]
      }''';

      final config = AppConfig.fromJson(jsonDecode(sampleConfigJson));
      expect(config.siteTitle, 'Batch 2026 Fund');
      expect(config.currency, '₹');
      expect(config.members.length, 2);
      expect(config.members[0].id, 'reza');
      expect(config.members[0].active, isTrue);
      expect(config.members[1].active, isFalse);
      expect(config.billTypes.length, 1);
      expect(config.billTypes[0].icon, '🍔');
    });

    test('FundData and TransactionModel serialization preserves fields', () {
      final tx = TransactionModel(
        id: 'tx_123',
        parentId: 'grp_123',
        type: 'debit',
        billTypeId: 'food',
        whoOrBill: 'food',
        amount: 250.0,
        note: 'Snacks party',
        date: '2026-08-23',
        splitAmong: ['reza', 'john'],
      );

      final json = tx.toJson();
      expect(json['id'], 'tx_123');
      expect(json['parentId'], 'grp_123');
      expect(json['type'], 'debit');
      expect(json['amount'], 250);
      expect(json['splitAmong'], ['reza', 'john']);

      final reconstructed = TransactionModel.fromJson(json);
      expect(reconstructed.id, tx.id);
      expect(reconstructed.parentId, tx.parentId);
      expect(reconstructed.amount, 250.0);
      expect(reconstructed.splitAmong, ['reza', 'john']);
    });

    test('JsonFormatter formats styled config.json and data.json matching Kotlin & Web apps', () {
      final config = AppConfig(
        siteTitle: 'Fand',
        siteSubtitle: 'Expense Tracker',
        currency: '₹',
        repoOwner: 'delightreza',
        repoName: 'Fand',
        members: [MemberConfig(id: 'me', name: 'Me', active: true)],
        billTypes: [BillTypeConfig(id: 'y', name: 'yiu', icon: '🧾', active: true)],
      );

      final formattedConfig = JsonFormatter.formatAppConfig(config);
      expect(formattedConfig.contains('{ "id": "me", "name": "Me", "active": true }'), isTrue);
      expect(formattedConfig.contains('{ "id": "y", "name": "yiu", "icon": "🧾", "active": true }'), isTrue);

      final data = FundData(
        transactions: [
          TransactionModel(
            id: 'tx_1',
            type: 'debit',
            whoOrBill: 'y',
            amount: 50,
            note: 'test note',
            date: '2026-08-23',
            splitAmong: ['me'],
          ),
        ],
      );

      final formattedData = JsonFormatter.formatFundData(data);
      expect(formattedData.contains('"splitAmong": ["me"]'), isTrue);
    });

    test('FundData updateSummaries recalculates people and billTypes totals', () {
      final config = AppConfig(
        members: [
          MemberConfig(id: 'me', name: 'Me', active: true),
          MemberConfig(id: 'bob', name: 'Bob', active: true),
        ],
        billTypes: [
          BillTypeConfig(id: 'food', name: 'Food', icon: '🍔', active: true),
        ],
      );

      final data = FundData(
        transactions: [
          TransactionModel(
            id: 'tx_1',
            type: 'credit',
            whoOrBill: 'me',
            amount: 500,
            note: 'Deposit',
            date: '2026-08-23',
          ),
          TransactionModel(
            id: 'tx_2',
            type: 'credit',
            whoOrBill: 'me',
            amount: 50,
            note: 'Paid for food',
            date: '2026-08-23',
          ),
          TransactionModel(
            id: 'tx_3',
            type: 'debit',
            whoOrBill: 'food',
            amount: 50,
            note: 'Food expense',
            date: '2026-08-23',
            splitAmong: ['me'],
          ),
        ],
      );

      data.updateSummaries(config);
      expect(data.people['me'], 550.0);
      expect(data.billTypes['food'], 50.0);

      final json = data.toJson();
      expect(json['people']['me'], 550);
      expect(json['billTypes']['food'], 50);
    });
  });
}
