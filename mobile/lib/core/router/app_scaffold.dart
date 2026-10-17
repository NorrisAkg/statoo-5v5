import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../theme/app_colors.dart';
import '../widgets/adaptive_bottom_navigation.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: AdaptiveBottomNavigation(
          currentIndex: navigationShell.currentIndex,
          onTap: (index) => _onTap(context, index),
          backgroundColor: context.colors.background900,
          selectedItemColor: context.colors.primary500,
          unselectedItemColor: context.colors.foreground500,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Remix.home_5_line),
              activeIcon: Icon(Remix.home_5_fill),
              label: 'Accueil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Remix.football_line),
              activeIcon: Icon(Remix.football_fill),
              label: 'Séances',
            ),
            BottomNavigationBarItem(
              icon: Icon(Remix.user_3_line),
              activeIcon: Icon(Remix.user_3_fill),
              label: 'Joueurs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Remix.trophy_line),
              activeIcon: Icon(Remix.trophy_fill),
              label: 'Classement',
            ),
            BottomNavigationBarItem(
              icon: Icon(Remix.pie_chart_line),
              activeIcon: Icon(Remix.pie_chart_fill),
              label: 'Stats',
            ),
          ],
        ),
      ),
    );
  }
}
