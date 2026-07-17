import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/bar_provider.dart';
import '../../theme/app_theme.dart';
import 'overview_tab.dart';
import '../menu/menu_screen.dart';
import 'orders_tab.dart';
import 'settings_tab.dart';
import 'staff_management_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  // ── Tab definitions per role ───────────────────────────────────────────────
  // Admin sees everything. Cook and waiter see only Orders + a logout option
  // baked into the orders header.

  static const _adminScreens = [
    OverviewTab(),
    OrdersTab(),
    MenuScreen(),
    StaffManagementTab(),
    SettingsTab(),
  ];

  static const _staffScreens = [
    OrdersTab(),
  ];

  static const _adminItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_outlined),
      activeIcon: Icon(Icons.dashboard),
      label: 'Overview',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.receipt_long_outlined),
      activeIcon: Icon(Icons.receipt_long),
      label: 'Orders',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.restaurant_menu_outlined),
      activeIcon: Icon(Icons.restaurant_menu),
      label: 'Menu',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.people_outline_rounded),
      activeIcon: Icon(Icons.people_rounded),
      label: 'Staff',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.settings_outlined),
      activeIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final prov    = context.watch<BarProvider>();
    final isAdmin = prov.isAdmin;

    // Staff (cook/waiter) only see orders — no bottom nav needed
    if (!isAdmin) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF8F0),
        body: OrdersTab(),
      );
    }

    // Admin full dashboard
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _adminScreens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: AppTheme.pebble, width: 1.2),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.textPrimary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            setState(() => _currentIndex = i);
            if (i == 2) context.read<BarProvider>().loadOrders();
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          items: _adminItems,
        ),
      ),
    );
  }
}