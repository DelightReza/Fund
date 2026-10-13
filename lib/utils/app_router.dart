import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/fund_repository.dart';
import '../services/storage_service.dart';
import '../screens/main_screen.dart';
import '../screens/transaction_detail_screen.dart';
import '../screens/category_expenses_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/add_transaction_screen.dart';
import '../screens/manage_config_screen.dart';
import '../screens/reset_commit_screen.dart';
import 'web_route_helper.dart';

class AppRouter {
  static Widget buildScreenForRoute(
    BuildContext context,
    String rawRoute, {
    bool isRestored = false,
  }) {
    final parsed = ParsedRoute.parse(rawRoute);
    final path = parsed.path;

    if (path == 'tx' || path == 'transaction') {
      final txId = parsed.id;
      final repo = context.read<FundRepository>();
      final txList = repo.data?.transactions ?? [];
      final matches =
          txList.where((t) => t.id == txId || t.id.toString() == txId).toList();
      if (matches.isNotEmpty) {
        return TransactionDetailScreen(
          transaction: matches.first,
          personId: parsed.memberId,
          returnRoute: parsed.parentRoute,
          isRestoredAfterRefresh: isRestored,
        );
      }
      return const MainScreen(initialRoute: 'transactions');
    }

    if (path == 'category') {
      return CategoryExpensesScreen(
        billTypeId: parsed.id ?? '',
        returnRoute: 'expenses',
        isRestoredAfterRefresh: isRestored,
      );
    }

    if (path == 'member' || path == 'profile') {
      return ProfileScreen(
        memberId: parsed.id,
        returnRoute: 'people',
        isRestoredAfterRefresh: isRestored,
      );
    }

    if (path == 'add_tx') {
      return AddTransactionScreen(
        returnRoute: parsed.from ?? 'admin',
        isRestoredAfterRefresh: isRestored,
      );
    }

    if (path == 'manage_config') {
      return ManageConfigScreen(
        isRestoredAfterRefresh: isRestored,
      );
    }

    if (path == 'reset_commit') {
      return ResetCommitScreen(
        isRestoredAfterRefresh: isRestored,
      );
    }

    if (path == 'admin') {
      return const MainScreen(initialRoute: 'admin');
    }

    if (path == 'expenses' || path == 'bills') {
      return const MainScreen(initialRoute: 'expenses');
    }

    if (path == 'people') {
      return const MainScreen(initialRoute: 'people');
    }

    return const MainScreen(initialRoute: 'transactions');
  }

  static void navigateTo(
    BuildContext context,
    String targetRoute, {
    bool replace = false,
    bool isRestored = false,
  }) {
    final storage = context.read<StorageService>();
    WebRouteHelper.setRoute(targetRoute, replace: replace);
    if (replace) {
      storage.setLastRoute(targetRoute);
    } else {
      storage.pushRoute(targetRoute);
    }

    final screen =
        buildScreenForRoute(context, targetRoute, isRestored: isRestored);
    if (replace) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => screen),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => screen),
      );
    }
  }

  /// Handles Back navigation: if forceDirect is true or cannot pop,
  /// seamlessly replaces the current screen with the parent target route.
  static void popOrNavigateTo(
    BuildContext context,
    String targetRoute, {
    bool forceDirect = false,
  }) {
    final storage = context.read<StorageService>();
    if (!forceDirect && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    } else {
      WebRouteHelper.setRoute(targetRoute, replace: true);
      storage.popRoute();
      storage.setLastRoute(targetRoute);
      final screen =
          buildScreenForRoute(context, targetRoute, isRestored: true);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => screen),
      );
    }
  }
}
