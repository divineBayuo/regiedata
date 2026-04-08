// root shell that hosts bottom navbar

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:regie_data/screens/landing_page.dart';
import 'package:regie_data/screens/organization_selector_screen.dart';
import 'package:regie_data/screens/user_profile_screen.dart';
import 'package:regie_data/screens/notification_screen.dart';
import 'package:regie_data/services/notification_service.dart';

const _bg = Color(0xFF0A0F0A);
const _green = Color(0xFF22C55E);

class MainShell extends StatefulWidget {
  final int initialIndex;
  final Widget homeWidget;

  const MainShell({
    super.key,
    this.initialIndex = 0,
    this.homeWidget = const LandingPage(),
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  // Keep pages alive when switching tabs
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pages = [
      widget.homeWidget, // 0 - Home
      OrganizationSelectorScreen(), // 1 - Organizations
      NotificationScreen(), // 2 - Notifications
      UserProfileScreen(), // 3 - Profile
    ];
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: _bg,
      // maintain scroll position with indexstack
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Separator
          Container(height: 1, color: Colors.white.withOpacity(0.07)),
          Container(
            color: const Color(0xFF080D08),
            padding: EdgeInsets.only(
              top: 10,
              bottom: MediaQuery.of(context).padding.bottom + 8,
              left: 8,
              right: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(
                    index: 0,
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Home'),
                _navItem(
                    index: 1,
                    icon: Icons.business_outlined,
                    activeIcon: Icons.business_rounded,
                    label: 'Organizations'),
                _notificationNavItem(uid),
                _navItem(
                    index: 3,
                    icon: Icons.person_outlined,
                    activeIcon: Icons.person_rounded,
                    label: 'Profile'),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _navItem(
      {required int index,
      required IconData icon,
      required IconData activeIcon,
      required String label}) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _green.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? _green : Colors.white.withOpacity(0.35),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? _green : Colors.white.withOpacity(0.3),
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _notificationNavItem(String? uid) {
    final isActive = _currentIndex == 2;
    if (uid == null) {
      return _navItem(
          index: 2,
          icon: Icons.notifications_outlined,
          activeIcon: Icons.notifications_rounded,
          label: 'Alerts');
    }

    return StreamBuilder<int>(
      stream: NotificationService.unreadCount(uid),
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _currentIndex = 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? _green.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isActive
                          ? Icons.notifications_rounded
                          : Icons.notifications_outlined,
                      color: isActive ? _green : Colors.white.withOpacity(0.35),
                      size: 22,
                    ),
                    if (unread > 0)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Alerts',
                  style: TextStyle(
                    color: isActive ? _green : Colors.white.withOpacity(0.3),
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
