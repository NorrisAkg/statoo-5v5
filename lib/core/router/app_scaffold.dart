import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../theme/app_colors.dart';

class AppScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppScaffold({super.key, required this.navigationShell});

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
        child: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          onTap: (index) => _onTap(context, index),
          backgroundColor: AppColors.background900,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary500,
          unselectedItemColor: AppColors.foreground500,
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Remix.home_line),
              activeIcon: Icon(Remix.home_fill),
              label: 'Accueil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Remix.user_line),
              activeIcon: Icon(Remix.user_fill),
              label: 'Joueurs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Remix.calendar_event_line),
              activeIcon: Icon(Remix.calendar_event_fill),
              label: 'Séances',
            ),
            BottomNavigationBarItem(
              icon: Icon(Remix.bar_chart_line),
              activeIcon: Icon(Remix.bar_chart_fill),
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
