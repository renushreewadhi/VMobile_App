import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/helpdesk_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../core/widgets/glass_scaffold.dart';
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
  String _selectedCategory = 'All Articles';
  String _sortBy = 'Newest First';

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
        category: _selectedCategory == 'All Articles' ? null : _selectedCategory,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
      if (mounted) {
        setState(() {
          _articles = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _articles = [];
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToCreateArticle() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateArticleScreen()),
    ).then((created) {
      if (created == true) _fetchArticles();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    if (_isLoading) {
      const skeleton = ListSkeleton(itemCount: 4);
      if (!widget.showAppBar) return skeleton;
      return const GlassScaffold(title: 'Knowledge Base', body: ListSkeleton(itemCount: 4));
    }

    final totalArticles = _articles.length;

    final body = RefreshIndicator(
      onRefresh: _fetchArticles,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Knowledge Base', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                      const SizedBox(height: 2),
                      Text('IT support guides, software setup, network troubleshooting, and access policies.', style: TextStyle(fontSize: 11.5, color: glass.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _navigateToCreateArticle,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Article', style: TextStyle(fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Top Metric Cards (Articles, Total Views, Helpful)
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.5,
              children: [
                _kpiCard('Articles', '$totalArticles', Icons.menu_book_rounded, AppColors.primary),
                _kpiCard('Total Views', '0', Icons.visibility_rounded, Colors.purple),
                _kpiCard('Helpful', '0', Icons.thumb_up_rounded, Colors.green),
              ],
            ),
            const SizedBox(height: 12),

            // Category Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  'All Articles (0)',
                  'Leave (0)',
                  'Attendance (0)',
                  'Payroll (0)',
                  'Benefits (0)',
                  'Onboarding (0)',
                  'Laptop / Hardware (0)'
                ].map((cat) {
                  final isSelected = _selectedCategory == cat || (_selectedCategory.isEmpty && cat.startsWith('All'));
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(cat, style: TextStyle(fontSize: 11.5, color: isSelected ? Colors.white : glass.textPrimary)),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar & Sort Dropdown
            AppCard(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search articles by title, content, or tags...',
                      hintStyle: TextStyle(color: glass.textSecondary, fontSize: 12),
                      prefixIcon: Icon(Icons.search, color: glass.textSecondary, size: 18),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1A2632) : AppColors.lightInputBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                      _fetchArticles();
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sort by:', style: TextStyle(fontSize: 11.5, color: AppColors.lightSecondaryText)),
                      DropdownButton<String>(
                        value: _sortBy,
                        underline: const SizedBox.shrink(),
                        isDense: true,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: glass.textPrimary),
                        items: const [
                          DropdownMenuItem(value: 'Newest First', child: Text('Newest First')),
                          DropdownMenuItem(value: 'Most Helpful', child: Text('Most Helpful')),
                          DropdownMenuItem(value: 'Most Viewed', child: Text('Most Viewed')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _sortBy = val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Articles List / Empty State
            _articles.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(36),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book_outlined, size: 40, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text('No articles found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                            const SizedBox(height: 4),
                            Text('Try adjusting your search or create the first article!', style: TextStyle(fontSize: 12, color: glass.textSecondary), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _articles.length,
                    itemBuilder: (context, index) {
                      final article = _articles[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          child: ListTile(
                            title: Text(article['title'] ?? 'Article', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(article['summary'] ?? article['category'] ?? ''),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: body);

    return GlassScaffold(
      title: 'Knowledge Base',
      body: body,
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    final glass = context.glass;
    return AppCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: glass.textSecondary), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
