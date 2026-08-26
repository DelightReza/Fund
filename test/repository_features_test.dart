import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fund_app/models/app_config.dart';
import 'package:fund_app/models/fund_data.dart';
import 'package:fund_app/models/transaction.dart';
import 'package:fund_app/repositories/fund_repository.dart';
import 'package:fund_app/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FundRepository & Storage Namespacing Tests', () {
    late StorageService storage;
    late FundRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'config_DelightReza_Fund-Template': '''
        {
          "repoOwner": "DelightReza",
          "repoName": "Fund-Template",
          "siteTitle": "Test Fund",
          "currency": "\$",
          "members": [{"id": "me", "name": "Me", "active": true}],
          "billTypes": [{"id": "food", "name": "Food", "icon": "🍔"}]
        }
        ''',
        'data_DelightReza_Fund-Template': '''
        {
          "people": {"me": 100},
          "billTypes": {"food": 50},
          "transactions": [
            {
              "id": "tx_1",
              "type": "credit",
              "whoOrBill": "me",
              "amount": 100,
              "note": "Deposit",
              "date": "2026-08-23"
            }
          ]
        }
        ''',
        'active_repo_owner': 'DelightReza',
        'active_repo_name': 'Fund-Template',
      });

      storage = await StorageService.create();
      repo = FundRepository(storage);
    });

    test('Loads config and data from namespaced keys', () {
      final config = storage.getConfigFor(owner: 'DelightReza', repo: 'Fund-Template');
      expect(config, isNotNull);
      expect(config?.siteTitle, equals('Test Fund'));

      final data = storage.getDataCacheFor(owner: 'DelightReza', repo: 'Fund-Template');
      expect(data, isNotNull);
      expect(data?.transactions.length, equals(1));
      expect(data?.transactions.first.amount, equals(100.0));
    });

    test('Admin verification state works per repository', () async {
      expect(storage.isAdminVerifiedFor(owner: 'DelightReza', repo: 'Fund-Template'), isFalse);

      await storage.saveToken('ghp_testtoken123', owner: 'DelightReza', repo: 'Fund-Template');
      await storage.setAdminVerified(true, owner: 'DelightReza', repo: 'Fund-Template');

      expect(storage.isAdminVerifiedFor(owner: 'DelightReza', repo: 'Fund-Template'), isTrue);

      // Clearing token also resets verification
      await storage.saveToken('', owner: 'DelightReza', repo: 'Fund-Template');
      expect(storage.isAdminVerifiedFor(owner: 'DelightReza', repo: 'Fund-Template'), isFalse);
    });

    test('Saves multi-fund keys separately without collision', () async {
      final config2 = AppConfig(
        repoOwner: 'TeamOrg',
        repoName: 'Project-Fund',
        siteTitle: 'Project Fund',
        currency: '€',
      );
      final data2 = FundData(
        people: {'alice': 200},
        billTypes: {'rent': 200},
        transactions: [
          TransactionModel(
            id: 'tx_p1',
            type: 'credit',
            whoOrBill: 'alice',
            amount: 200,
            note: 'Rent payment',
            date: '2026-08-23',
          ),
        ],
      );

      await storage.saveConfig(config2);
      await storage.saveDataCache(data2, owner: 'TeamOrg', repo: 'Project-Fund');

      expect(storage.configKey('TeamOrg', 'Project-Fund'), equals('config_TeamOrg_Project-Fund'));
      expect(storage.dataKey('TeamOrg', 'Project-Fund'), equals('data_TeamOrg_Project-Fund'));
      expect(storage.fundKey('TeamOrg', 'Project-Fund'), equals('fund_TeamOrg_Project-Fund'));

      final loadedConfig1 = storage.getConfigFor(owner: 'DelightReza', repo: 'Fund-Template');
      final loadedConfig2 = storage.getConfigFor(owner: 'TeamOrg', repo: 'Project-Fund');
      expect(loadedConfig1?.currency, equals('\$'));
      expect(loadedConfig2?.currency, equals('€'));
    });

    test('CSV export returns formatted CSV string', () {
      final csv = repo.exportToCsv();
      expect(csv.contains('ID,Date,Type,Amount'), isTrue);
      expect(csv.contains('tx_1,2026-08-23,credit,100'), isTrue);
    });

    test('JSON formatted export returns non-empty formatted JSON', () {
      final jsonStr = repo.exportToJsonFormatted();
      expect(jsonStr.contains('"transactions": ['), isTrue);
      expect(jsonStr.contains('"people": {'), isTrue);
    });
  });
}
