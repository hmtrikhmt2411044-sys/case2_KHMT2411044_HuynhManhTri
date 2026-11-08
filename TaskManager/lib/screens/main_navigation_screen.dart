import 'package:flutter/material.dart';
import 'tasks/task_list_screen.dart';
import 'statistics/statistics_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          TaskListScreen(
            isTab: true,
            onSwitchTab: _onTabTapped,
          ),
          const StatisticsScreen(isTab: true),
          const ProfileScreen(isTab: true),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabTapped,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
          elevation: 0,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.task_alt_outlined, color: Color(0xFF64748B), size: 22),
              selectedIcon: Icon(Icons.task_alt_rounded, color: Color(0xFF2563EB), size: 24),
              label: 'Công việc',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined, color: Color(0xFF64748B), size: 22),
              selectedIcon: Icon(Icons.insights_rounded, color: Color(0xFF2563EB), size: 24),
              label: 'Thống kê',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, color: Color(0xFF64748B), size: 22),
              selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 24),
              label: 'Cá nhân',
            ),
          ],
        ),
      ),
    );
  }
}
