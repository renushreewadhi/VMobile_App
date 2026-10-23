import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/helpdesk_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import 'create_article_screen.dart';

class HelpdeskKnowledgeBaseScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const HelpdeskKnowledgeBaseScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<HelpdeskKnowledgeBaseScreen> createState() => _HelpdeskKnowledgeBaseScreenState();
}

class _HelpdeskKnowledgeBaseScreenState extends ConsumerState<HelpdeskKnowledgeBaseScreen> {
  bool _isLoading = true;
  List<dynamic> _articles = [];
  String _searchQuery = '';
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    _fetchArticles();
  }

  Future<void> _fetchArticles() async {
    setState(() => _isLoading = true);
    try {
      final helpdeskSvc = ref.read(helpdeskServiceProvider);
      final res = await helpdeskSvc.getKnowledgeBaseArticles(
        category: _selectedCategory.isEmpty ? null : _selectedCategory,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
      if (mounted) {
        setState(() {
          _articles = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _fetchArticles();
  }

  void _navigateToCreateArticle() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateArticleScreen()),
    ).then((created) {
      if (created == true) _fetchArticles();
    });
  }

  void _showArticleDetail(Map<String, dynamic> article) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(article['title'] ?? 'Article'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Category: ${article['category'] ?? 'GENERAL'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
              const SizedBox(height: 12),
              Text(article['content'] ?? article['description'] ?? 'No content available.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                final helpdeskSvc = ref.read(helpdeskServiceProvider);
                await helpdeskSvc.markArticleHelpful(article['id'].toString());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as helpful!')));
                }
              } catch (_) {}
            },
            child: const Text('Mark Helpful'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final skeleton = const ListSkeleton(itemCount: 4);
      if (!widget.showAppBar) return skeleton;
      return Scaffold(
        appBar: AppBar(title: const Text('Knowledge Base')),
        body: skeleton,
      );
    }

    final body = RefreshIndicator(
      onRefresh: _fetchArticles,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Knowledge Base & Guides', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ElevatedButton.icon(
                  onPressed: _navigateToCreateArticle,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Article'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search articles, policies...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 16),
            if (_articles.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('No articles found.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _articles.length,
                itemBuilder: (context, index) {
                  final article = _articles[index];
                  final title = article['title'] ?? 'Untitled';
                  final category = article['category'] ?? 'GENERAL';
                  final summary = article['summary'] ?? article['description'] ?? '';

                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    onTap: () => _showArticleDetail(article),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(category.toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        if (summary.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );

    if (!widget.showAppBar) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Knowledge Base')),
      body: body,
    );
  }
}
