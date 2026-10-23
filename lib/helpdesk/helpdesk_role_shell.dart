import 'package:flutter/material.dart';

import '../shared/layouts/app_shell.dart';
import 'screens/helpdesk_dashboard_screen.dart';
import 'screens/helpdesk_knowledge_base_screen.dart';
import 'screens/helpdesk_tickets_screen.dart';

class HelpdeskRoleShell extends StatefulWidget {
  const HelpdeskRoleShell({super.key});

  @override
  State<HelpdeskRoleShell> createState() => _HelpdeskRoleShellState();
}

class _HelpdeskRoleShellState extends State<HelpdeskRoleShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HelpdeskDashboardScreen(onNavigateTab: (idx) => setState(() => _currentIndex = idx)),
      const HelpdeskTicketsScreen(),
      const HelpdeskKnowledgeBaseScreen(),
    ];

    final titles = [
      'Helpdesk Dashboard',
      'Support Tickets',
      'Knowledge Base',
    ];

    return AppShell(
      title: titles[_currentIndex],
      selectedIndex: _currentIndex,
      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.confirmation_number), label: 'Tickets'),
        NavigationDestination(icon: Icon(Icons.menu_book), label: 'Guides'),
      ],
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
    );
  }
}
