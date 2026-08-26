import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'admin_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storage = context.watch<StorageService>();
    final isAdminVerified = storage.isAdminVerified;

    // Dynamically adjust destinations and screens based on platform (kIsWeb) and admin verification
    final screens = <Widget>[
      const HomeScreen(),
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
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: isKeyboardOpen
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 440),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.08),
                          blurRadius: 20,
                          spreadRadius: 0,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.45),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(destinations.length, (index) {
                        final isSelected = _currentIndex == index;
                        final item = destinations[index];

                        return Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _currentIndex = index;
                              });
                            },
                            borderRadius: BorderRadius.circular(28),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primaryContainer
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
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.onSurfaceVariant,
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
                                          color: theme.colorScheme.onPrimaryContainer,
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

