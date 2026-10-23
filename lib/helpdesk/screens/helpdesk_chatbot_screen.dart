import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/helpdesk_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';

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
        text: 'Hello! I am your Helpdesk AI Assistant. How can I help you today with HR, IT, or Finance queries?',
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

      String botReply = 'I have processed your request.';
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: 'Sorry, I encountered an error connecting to the chatbot service: $e',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Helpdesk AI Assistant'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue.shade50,
            child: Row(
              children: const [
                Icon(Icons.smart_toy, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text('Ask questions or select quick topics below', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: _quickActions.map((action) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(action['label']!, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _sendMessage(action['message']!),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: msg.isUser ? AppColors.primary : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: TextStyle(color: msg.isUser ? Colors.white : Colors.black87, fontSize: 14),
                        ),
                        if (msg.kbArticles != null && msg.kbArticles!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Related Articles:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ...msg.kbArticles!.map((art) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('• ${art['title'] ?? art['name']}', style: const TextStyle(fontSize: 12, color: Colors.blueAccent)),
                              )),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
