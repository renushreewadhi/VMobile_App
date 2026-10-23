import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class HelpdeskDashboardScreen extends ConsumerStatefulWidget {
  const HelpdeskDashboardScreen({super.key});

  @override
  ConsumerState<HelpdeskDashboardScreen> createState() => _HelpdeskDashboardScreenState();
}

class _HelpdeskDashboardScreenState extends ConsumerState<HelpdeskDashboardScreen> {
  bool _isLoading = true;
  List<dynamic> _tickets = [];

  @override
  void initState() {
    super.initState();
    _fetchHelpdesk();
  }

  Future<void> _fetchHelpdesk() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/helpdesk/tickets').catchError((_) => null);
      if (mounted) {
        setState(() {
          if (res is List) _tickets = res;
          else if (res is Map<String, dynamic> && res['data'] is List) _tickets = res['data'];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Helpdesk Dashboard')),
      body: _isLoading
          ? const DashboardSkeleton()
          : RefreshIndicator(
              onRefresh: _fetchHelpdesk,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Expanded(
                          child: StatCard(
                            title: 'Open Tickets',
                            value: '2',
                            icon: Icons.support_agent,
                            iconColor: Colors.blue,
                            iconBgColor: Color(0xFFE8EFFF),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            title: 'Resolved',
                            value: '14',
                            icon: Icons.check_circle_outline,
                            iconColor: Colors.green,
                            iconBgColor: Color(0xFFE6F7F0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Recent Support Tickets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    _tickets.isEmpty
                        ? const AppCard(child: Center(child: Text('No active helpdesk tickets.')))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _tickets.length,
                            itemBuilder: (context, index) {
                              final t = _tickets[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: AppCard(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(t['subject']?.toString() ?? 'Support Request', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const StatusChip(status: 'OPEN'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}

class HelpdeskTicketsScreen extends StatelessWidget {
  const HelpdeskTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Helpdesk Tickets')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          AppCard(
            child: ListTile(
              leading: Icon(Icons.confirmation_number, color: Colors.blue),
              title: Text('VPN Access & Credential Issue'),
              subtitle: Text('Priority: High • Opened Today'),
              trailing: StatusChip(status: 'OPEN'),
            ),
          ),
        ],
      ),
    );
  }
}

class HelpdeskKnowledgeBaseScreen extends StatelessWidget {
  const HelpdeskKnowledgeBaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Knowledge Base')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          AppCard(child: ListTile(leading: Icon(Icons.menu_book, color: Colors.blue), title: Text('HR Policy & Handbook 2026'))),
          SizedBox(height: 10),
          AppCard(child: ListTile(leading: Icon(Icons.menu_book, color: Colors.blue), title: Text('Expense Claim Guidelines'))),
        ],
      ),
    );
  }
}

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _msgController = TextEditingController();
  final List<String> _messages = ['Hello! I am your Etaprise AI HR Assistant. How can I help you today?'];

  void _sendMessage() {
    if (_msgController.text.trim().isEmpty) return;
    setState(() {
      _messages.add('You: ${_msgController.text}');
      _messages.add('AI: I understand your query regarding "${_msgController.text}". Let me assist you with that.');
      _msgController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI HR Assistant')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final isUser = _messages[index].startsWith('You:');
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_messages[index]),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: CustomTextField(label: '', hint: 'Ask me anything about HR...', controller: _msgController)),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.send, color: Colors.blue), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MySettingsScreen extends StatelessWidget {
  const MySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          AppCard(child: SwitchListTile(title: Text('Push Notifications'), value: true, onChanged: null)),
          SizedBox(height: 10),
          AppCard(child: SwitchListTile(title: Text('Dark Mode Preference'), value: false, onChanged: null)),
        ],
      ),
    );
  }
}
