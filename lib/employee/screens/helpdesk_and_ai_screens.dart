import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/helpdesk_service.dart';
import '../../core/auth/auth_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import '../../core/widgets/glass_scaffold.dart';

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
    final helpdeskService = ref.read(helpdeskServiceProvider);
    try {
      final res = await helpdeskService.getTickets();
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
    return GlassScaffold(
      title: 'Helpdesk Dashboard',
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
    return GlassScaffold(
      title: 'Helpdesk Tickets',
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
    return GlassScaffold(
      title: 'Knowledge Base',
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
  final List<Map<String, String>> _messages = [
    {'role': 'ai', 'text': 'Hello! I am your Etaprise AI HR Assistant. How can I help you today?'}
  ];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get(ApiEndpoints.aiHistory).catchError((_) => null);
      if (res != null && mounted) {
        final data = res is Map && res.containsKey('data') ? res['data'] : res;
        if (data is List && data.isNotEmpty) {
          final historyList = <Map<String, String>>[];
          for (final item in data) {
            if (item is Map) {
              if (item['question'] != null) {
                historyList.add({'role': 'user', 'text': item['question'].toString()});
              }
              if (item['answer'] != null) {
                historyList.add({'role': 'ai', 'text': item['answer'].toString()});
              }
            }
          }
          if (historyList.isNotEmpty) {
            setState(() {
              _messages.clear();
              _messages.addAll(historyList);
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final prompt = _msgController.text.trim();
    if (prompt.isEmpty || _sending) return;

    setState(() {
      _messages.add({'role': 'user', 'text': prompt});
      _msgController.clear();
      _sending = true;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.post(ApiEndpoints.aiAsk, body: {'question': prompt});
      if (!mounted) return;

      String aiAnswer = 'I understand your query. How else may I help you?';
      if (res != null) {
        final data = res is Map && res.containsKey('data') ? res['data'] : res;
        if (data is String && data.isNotEmpty) {
          aiAnswer = data;
        } else if (data is Map && data['answer'] != null) {
          aiAnswer = data['answer'].toString();
        }
      }

      setState(() {
        _messages.add({'role': 'ai', 'text': aiAnswer});
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      final err = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      setState(() {
        _messages.add({'role': 'ai', 'text': 'Sorry, I encountered an error: $err'});
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'AI HR Assistant',
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final isUser = _messages[index]['role'] == 'user';
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Colors.blue.shade600
                          : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _messages[index]['text'] ?? '',
                      style: TextStyle(
                        color: isUser
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_sending)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('AI Assistant is thinking...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: CustomTextField(label: '', hint: 'Ask me anything about HR...', controller: _msgController)),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: _sending ? Colors.grey : Colors.blue),
                  onPressed: _sending ? null : _sendMessage,
                ),
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
    return GlassScaffold(
      title: 'My Settings',
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
