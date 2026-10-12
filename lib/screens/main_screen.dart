import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../utils/web_route_helper.dart';
import '../widgets/glass_container.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'admin_screen.dart';
import 'add_transaction_screen.dart';
import 'manage_config_screen.dart';
import 'reset_commit_screen.dart';

class MainScreen extends StatefulWidget {
  final String? initialRoute;

  const MainScreen({super.key, this.initialRoute});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _hasCheckedInitialRoute = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final storage = context.read<StorageService>();
      if (storage.getLastRoute() == null) {
        // Cache expired after 10+ minutes: reset to Home tab
        if (mounted && _currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          WebRouteHelper.setRoute('transactions');
        }
        // Pop any pushed screens back to the root screen
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCheckedInitialRoute) {
      _hasCheckedInitialRoute = true;
      final parsed = ParsedRoute.parse(widget.initialRoute);
      final storage = context.read<StorageService>();
      final isAdminSubroute = parsed.path == 'manage_config' ||
          parsed.path == 'reset_commit' ||
          (parsed.path == 'add_tx' && (parsed.from == null || parsed.from == 'admin'));
      if ((parsed.path == 'admin' || isAdminSubroute) && storage.isAdminVerified) {
        _currentIndex = kIsWeb ? 1 : 2;
      } else if (parsed.path == 'profile' && !kIsWeb) {
        _currentIndex = 1;
      }

      if (parsed.path == 'manage_config') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ManageConfigScreen(isRestoredAfterRefresh: true),
              ),
            ).then((_) {
              if (mounted) {
                WebRouteHelper.setRoute('admin');
                context.read<StorageService>().setLastRoute('admin');
              }
            });
          }
        });
      } else if (parsed.path == 'reset_commit') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ResetCommitScreen(isRestoredAfterRefresh: true),
              ),
            ).then((_) {
              if (mounted) {
                WebRouteHelper.setRoute('admin');
                context.read<StorageService>().setLastRoute('admin');
              }
            });
          }
        });
      } else if (parsed.path == 'add_tx') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddTransactionScreen(
                  returnRoute: parsed.from ?? 'admin',
                  isRestoredAfterRefresh: true,
                ),
              ),
            ).then((_) {
              if (mounted) {
                final ret = parsed.from ?? 'admin';
                WebRouteHelper.setRoute(ret);
                context.read<StorageService>().setLastRoute(ret);
              }
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storage = context.watch<StorageService>();
    final isAdminVerified = storage.isAdminVerified;

    // Dynamically adjust destinations and screens based on platform (kIsWeb) and admin verification
    final screens = <Widget>[
      HomeScreen(initialRoute: widget.initialRoute),
      if (!kIsWeb) const ProfileScreen(),
      if (isAdminVerified) const AdminScreen(),
    ];

    final destinations = <_NavDestinationItem>[
      const _NavDestinationItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: 'Home',
      ),
      if (!kIsWeb)
        const _NavDestinationItem(
          icon: Icons.person_outline,
          selectedIcon: Icons.person_rounded,
          label: 'Profile',
        ),
      if (isAdminVerified)
        const _NavDestinationItem(
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings_rounded,
          label: 'Admin',
        ),
    ];

    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    // If there is only 1 screen (e.g. only Home tab), hide the navigation bar completely
    if (screens.length <= 1) {
      return Scaffold(
        body: screens.first,
      );
    }

    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      extendBody: true,
      body: AuroraBackground(
        child: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: isKeyboardOpen
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: GlassContainer(
                      borderRadius: 36,
                      blur: 26,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(destinations.length, (index) {
                        final isSelected = _currentIndex == index;
                        final item = destinations[index];
                        final isDark = theme.brightness == Brightness.dark;

                        return Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _currentIndex = index;
                              });
                              final item = destinations[index];
                              if (item.label == 'Admin') {
                                WebRouteHelper.setRoute('admin');
                                storage.setLastRoute('admin');
                              } else if (item.label == 'Profile') {
                                WebRouteHelper.setRoute('profile');
                                storage.setLastRoute('profile');
                              }
                            },
                            borderRadius: BorderRadius.circular(28),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark
                                        ? Colors.white.withValues(alpha: 0.16)
                                        : theme.colorScheme.primary.withValues(alpha: 0.14))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSelected ? item.selectedIcon : item.icon,
                                    color: isSelected
                                        ? (isDark ? Colors.white : theme.colorScheme.primary)
                                        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                    size: 22,
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        item.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
  }
}

class _NavDestinationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavDestinationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

