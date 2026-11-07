import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/helpdesk_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_scaffold.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<dynamic>? kbArticles;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.kbArticles,
  });
}

class HelpdeskChatbotScreen extends ConsumerStatefulWidget {
  const HelpdeskChatbotScreen({super.key});

  @override
  ConsumerState<HelpdeskChatbotScreen> createState() => _HelpdeskChatbotScreenState();
}

class _HelpdeskChatbotScreenState extends ConsumerState<HelpdeskChatbotScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  final List<Map<String, String>> _quickActions = [
    {'label': 'Leave Policy', 'message': 'Tell me about the leave policy'},
    {'label': 'Salary Query', 'message': 'I have a salary query'},
    {'label': 'IT Support', 'message': 'I need IT support for my laptop'},
    {'label': 'Create Ticket', 'message': 'I want to create a support ticket'},
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        text: 'Hello! I am your IT Helpdesk AI Assistant. I can help you with laptop requests, software issues, email access, network problems, and IT support tickets.\n\n📊 Ticket Overview: 1 total | 1 open | 0 in progress | 0 escalated',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessage(text: text.trim(), isUser: true, timestamp: DateTime.now());
    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final helpdeskSvc = ref.read(helpdeskServiceProvider);
      final res = await helpdeskSvc.chatbot(text);

      String botReply = 'I can help you with leave, salary, IT issues, expenses, benefits, or check your ticket status. You can also type your issue and I\'ll help create a ticket for you.';
      List<dynamic>? articles;

      if (res is Map<String, dynamic>) {
        botReply = res['reply'] ?? res['message'] ?? res['answer'] ?? botReply;
        articles = res['articles'] ?? res['kbArticles'];
      } else if (res is String) {
        botReply = res;
      }

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: botReply,
              isUser: false,
              timestamp: DateTime.now(),
              kbArticles: articles,
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: 'I can help you with leave, salary, IT issues, expenses, benefits, or check your ticket status. You can also type your issue and I\'ll help create a ticket for you.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(
        ChatMessage(
          text: 'Hello! I am your IT Helpdesk AI Assistant. I can help you with laptop requests, software issues, email access, network problems, and IT support tickets.\n\n📊 Ticket Overview: 1 total | 1 open | 0 in progress | 0 escalated',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    return GlassScaffold(
      title: 'IT Helpdesk AI Assistant',
      body: Column(
        children: [
          // Sub-header info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSecondarySurface : Colors.white,
              border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('Online & Ready • IT • 1 recent', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: glass.textSecondary)),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.flash_on, size: 18, color: AppColors.primary),
                      onPressed: () {
                        _sendMessage('Overview of my open support tickets');
                      },
                      tooltip: 'Quick Overview',
                    ),
                    OutlinedButton.icon(
                      onPressed: _clearChat,
                      icon: const Icon(Icons.delete_outline, size: 14),
                      label: const Text('Clear', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(14),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final timeStr = DateFormat('h:mm a').format(msg.timestamp);

                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? AppColors.primary
                          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: TextStyle(
                            fontSize: 13,
                            color: msg.isUser ? Colors.white : glass.textPrimary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: msg.isUser ? Colors.white70 : glass.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ),

          // Quick Action Pills
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: _quickActions.map((action) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(action['label']!, style: const TextStyle(fontSize: 11)),
                    backgroundColor: isDark ? AppColors.darkSecondarySurface : Colors.grey.shade100,
                    onPressed: () => _sendMessage(action['message']!),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),

          // Input Bar & Subtitle
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkMainSurface : Colors.white,
              border: Border(top: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(fontSize: 13, color: glass.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Ask about laptop, software, email, network...',
                          hintStyle: TextStyle(fontSize: 12, color: glass.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : AppColors.lightInputBackground,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                      onPressed: () => _sendMessage(_controller.text),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text('🛡️ HRM Core Intelligence AI Assistant & Support Hub', style: TextStyle(fontSize: 9.5, color: AppColors.lightSecondaryText)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
