import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart';
import 'inbox_screen.dart';
import 'profile_screen.dart';
import 'tasks_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  int _tab = 0;
  late final AnimationController _fade = AnimationController(vsync: this, duration: Motion.medium, value: 1);

  void goTo(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final unread = state.unreadCount;
    final a = CurvedAnimation(parent: _fade, curve: Motion.curve);
    return Scaffold(
      body: AnimatedBuilder(
        animation: a,
        builder: (_, child) => Opacity(
          opacity: a.value,
          child: Transform.translate(offset: Offset(0, 10 * (1 - a.value)), child: child),
        ),
        child: IndexedStack(index: _tab, children: [
          HomeScreen(onOpenTab: goTo),
          const TasksScreen(),
          const InboxScreen(),
          const ProfileScreen(),
        ]),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 66,
            child: Row(children: [
              _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Beranda', active: _tab == 0, onTap: () => goTo(0)),
              _NavItem(icon: Icons.assignment_outlined, activeIcon: Icons.assignment_rounded, label: 'Tugas', active: _tab == 1, onTap: () => goTo(1)),
              _NavItem(icon: Icons.notifications_none_rounded, activeIcon: Icons.notifications_rounded, label: 'Inbox', active: _tab == 2, badge: unread, onTap: () => goTo(2)),
              _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profil', active: _tab == 3, onTap: () => goTo(3)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final c = active ? AppColors.primary : const Color(0xFF9AA0A6);
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Pressable(
            scale: 0.9,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedContainer(
                duration: Motion.medium,
                curve: Motion.curve,
                width: active ? 56 : 40,
                height: 30,
                decoration: BoxDecoration(
                  color: active ? AppColors.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                  AnimatedSwitcher(
                    duration: Motion.fast,
                    transitionBuilder: (child, an) => ScaleTransition(scale: an, child: child),
                    child: Icon(active ? activeIcon : icon, key: ValueKey(active), color: c, size: 23),
                  ),
                  Positioned(right: active ? 6 : -2, top: -5, child: CountBadge(badge)),
                ]),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: Motion.fast,
                style: TextStyle(color: c, fontSize: 11.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500),
                child: Text(label),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
