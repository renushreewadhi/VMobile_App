import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../admin/screens/admin_announcements_screen.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../core/widgets/module_card.dart';
import '../../core/widgets/section_label.dart';
import '../../employee/screens/my_settings_screen.dart';
import '../../helpdesk/screens/helpdesk_chatbot_screen.dart';
import '../../helpdesk/screens/helpdesk_dashboard_screen.dart';
import '../../helpdesk/screens/helpdesk_knowledge_base_screen.dart';
import '../../helpdesk/screens/helpdesk_tickets_screen.dart';
import '../../resources/screens/holidays_screen.dart';
import 'it_access_screen.dart';
import 'it_asset_requests_screen.dart';
import 'it_assets_screen.dart';
import 'it_employee_accounts_screen.dart';
import 'it_offboarding_screen.dart';
import 'it_onboarding_screen.dart';
import 'it_reports_screen.dart';
import 'it_security_screen.dart';
import 'it_software_screen.dart';
import 'it_tickets_screen.dart';

class SubModuleItem {
  final String name;
  final String description;
  final IconData icon;
  final List<Color> colors;
  final Widget screen;

  SubModuleItem({
    required this.name,
    required this.description,
    required this.icon,
    required this.colors,
    required this.screen,
  });
}

class ParentModuleItem {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> colors;
  final List<SubModuleItem> submodules;

  ParentModuleItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.colors,
    required this.submodules,
  });
}

class SearchResultItem {
  final String parentTitle;
  final SubModuleItem submodule;

  SearchResultItem({
    required this.parentTitle,
    required this.submodule,
  });
}

class ItMoreScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const ItMoreScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<ItMoreScreen> createState() => _ItMoreScreenState();
}

class _ItMoreScreenState extends ConsumerState<ItMoreScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<ParentModuleItem> _parentModules = [
    ParentModuleItem(
      title: 'Resources',
      description: 'Company holidays calendar and announcements',
      icon: Icons.folder_open_rounded,
      colors: [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
      submodules: [
        SubModuleItem(
          name: 'Holidays',
          description: 'Company holiday calendar and list',
          icon: Icons.calendar_today_rounded,
          colors: [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
          screen: const HolidaysScreen(),
        ),
        SubModuleItem(
          name: 'Announcements',
          description: 'Company news and announcements',
          icon: Icons.campaign_rounded,
          colors: [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
          screen: const AdminAnnouncementsScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'IT Operations',
      description: 'Assets, Software, Accounts, Access, Support, Onboarding & Audits',
      icon: Icons.devices_other_rounded,
      colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
      submodules: [
        SubModuleItem(
          name: 'IT Assets',
          description: 'Manage company IT hardware and devices',
          icon: Icons.laptop_mac_rounded,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const ItAssetsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Asset Requests',
          description: 'Review and process IT hardware requests',
          icon: Icons.assignment_turned_in_rounded,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const ItAssetRequestsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Asset Assignment',
          description: 'Assign and track hardware assigned to staff',
          icon: Icons.swap_horiz_rounded,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const ItAssetsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Software & Licenses',
          description: 'Manage software subscriptions and licenses',
          icon: Icons.apps_rounded,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const ItSoftwareScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Employee Accounts',
          description: 'Manage employee system IT user accounts',
          icon: Icons.manage_accounts_rounded,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const ItEmployeeAccountsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Access Management',
          description: 'Manage access controls and permissions',
          icon: Icons.vpn_key_rounded,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const ItAccessScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'IT Tickets / Support',
          description: 'Manage IT support tickets and requests',
          icon: Icons.support_agent_rounded,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const ItTicketsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'IT Onboarding',
          description: 'IT provisioning and setup for new hires',
          icon: Icons.person_add_rounded,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const ItOnboardingScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'IT Offboarding',
          description: 'IT de-provisioning and asset collection',
          icon: Icons.person_remove_rounded,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const ItOffboardingScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Security & Audit',
          description: 'IT security logs and system audit trails',
          icon: Icons.security_rounded,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const ItSecurityScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'IT Reports',
          description: 'IT operational reports and analytics',
          icon: Icons.bar_chart_rounded,
          colors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          screen: const ItReportsScreen(showAppBar: true),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'HR Helpdesk',
      description: 'Support dashboard, tickets, knowledge base & AI',
      icon: Icons.headset_mic_rounded,
      colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
      submodules: [
        SubModuleItem(
          name: 'Helpdesk Dashboard',
          description: 'Support tickets overview and metrics',
          icon: Icons.dashboard_rounded,
          colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
          screen: const HelpdeskDashboardScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Helpdesk Tickets',
          description: 'Manage and resolve support tickets',
          icon: Icons.confirmation_number_rounded,
          colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
          screen: const HelpdeskTicketsScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'Knowledge Base',
          description: 'FAQs, articles, and IT guides',
          icon: Icons.auto_stories_rounded,
          colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
          screen: const HelpdeskKnowledgeBaseScreen(showAppBar: true),
        ),
        SubModuleItem(
          name: 'AI Assistant',
          description: 'Chat with AI assistant for instant answers',
          icon: Icons.smart_toy_rounded,
          colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
          screen: const HelpdeskChatbotScreen(),
        ),
      ],
    ),
    ParentModuleItem(
      title: 'Settings',
      description: 'Personal application preferences and account settings',
      icon: Icons.settings_rounded,
      colors: [const Color(0xFF64748B), const Color(0xFF334155)],
      submodules: [
        SubModuleItem(
          name: 'My Settings',
          description: 'App preferences and account settings',
          icon: Icons.manage_accounts_rounded,
          colors: [const Color(0xFF64748B), const Color(0xFF334155)],
          screen: const MySettingsScreen(),
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchQuery.trim().isNotEmpty;

    final filteredParents = _parentModules.where((parent) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      if (parent.title.toLowerCase().contains(q) || parent.description.toLowerCase().contains(q)) {
        return true;
      }
      return parent.submodules.any((s) => s.name.toLowerCase().contains(q) || s.description.toLowerCase().contains(q));
    }).toList();

    final content = ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      children: [
        GlassSearchBar(
          controller: _searchController,
          placeholder: "Search IT modules...",
          onChanged: (val) => setState(() => _searchQuery = val),
          onClear: () => setState(() => _searchQuery = ''),
        ),
        const SectionLabel("IT OPERATIONS MODULES"),
        if (isSearching && filteredParents.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No IT modules found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('No results for "$_searchQuery"', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Text('Clear Search'),
                  ),
                ],
              ),
            ),
          )
        else
          ...filteredParents.map((parent) {
            return ModuleCard(
              icon: parent.icon,
              gradientColors: parent.colors,
              title: parent.title,
              subtitle: parent.description,
              count: parent.submodules.length,
              onPress: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ParentSubmodulesScreen(parent: parent),
                  ),
                );
              },
            );
          }),
      ],
    );

    if (!widget.showAppBar) {
      return Material(color: Colors.transparent, child: content);
    }

    return GlassScaffold(
      title: "IT Modules",
      showBottomBar: false,
      body: content,
    );
  }
}

class ParentSubmodulesScreen extends StatelessWidget {
  final ParentModuleItem parent;
  const ParentSubmodulesScreen({super.key, required this.parent});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassHeader(
        title: parent.title,
        userInitial: "IT",
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        children: [
          const SectionLabel("SUBMODULES"),
          ...parent.submodules.map((sub) {
            return ModuleCard(
              icon: sub.icon,
              gradientColors: sub.colors,
              title: sub.name,
              subtitle: sub.description,
              count: 1,
              onPress: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => sub.screen),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}
