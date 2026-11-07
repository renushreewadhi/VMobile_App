import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/app_card.dart';
import '../../core/theme/app_colors.dart';
import 'create_ticket_screen.dart';
import 'create_article_screen.dart';
import 'helpdesk_chatbot_screen.dart';

class HelpdeskMoreScreen extends ConsumerWidget {
  const HelpdeskMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      {'title': 'Create Support Ticket', 'icon': Icons.add_circle_outline, 'screen': const CreateTicketScreen()},
      {'title': 'Create KB Article', 'icon': Icons.note_add, 'screen': const CreateArticleScreen()},
      {'title': 'HR AI Chatbot Assistant', 'icon': Icons.support_agent, 'screen': const HelpdeskChatbotScreen()},
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Helpdesk Tools & AI Assistant',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => item['screen'] as Widget));
            },
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item['icon'] as IconData, color: AppColors.primary),
              ),
              title: Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            ),
          ),
        )),
      ],
    );
  }
}
