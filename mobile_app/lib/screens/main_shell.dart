import 'package:flutter/material.dart';
import '../services/alert_service.dart';
import 'tabs/home_tab.dart';
import 'tabs/cameras_tab.dart';
import 'tabs/incidents_tab.dart';
import 'tabs/profile_tab.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final AlertService _alertService = AlertService();

  @override
  void initState() {
    super.initState();
    _alertService.init().then((_) {
      if (mounted) {
        _alertService.startPolling(
          context,
          onNavigate: (tabIndex, incident) {
            setState(() => _currentIndex = tabIndex);
          },
        );
      }
    });
  }

  @override
  void dispose() {
    _alertService.stopPolling();
    super.dispose();
  }

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      HomeTab(onTabSwitch: _switchTab),
      const CamerasTab(),
      const IncidentsTab(),
      ProfileTab(onTabSwitch: _switchTab),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam_rounded),
            label: 'Cameras',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_rounded),
            selectedIcon: Icon(Icons.warning_rounded),
            label: 'Incidents',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
