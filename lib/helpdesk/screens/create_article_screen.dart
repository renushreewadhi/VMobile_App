import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/helpdesk_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../core/widgets/glass_scaffold.dart';

class CreateArticleScreen extends ConsumerStatefulWidget {
  const CreateArticleScreen({super.key});

  @override
  ConsumerState<CreateArticleScreen> createState() => _CreateArticleScreenState();
}

class _CreateArticleScreenState extends ConsumerState<CreateArticleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  String _category = 'GENERAL';

  List<dynamic> _categories = [];
  List<String> _parsedTags = [];
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final helpdeskSvc = ref.read(helpdeskServiceProvider);
      final categories = await helpdeskSvc.getCategories(isActive: true);
      if (mounted) {
        setState(() {
          _categories = categories;
          if (_categories.isNotEmpty) {
            _category = _categories[0]['code'] ?? 'GENERAL';
          }
          _isLoadingCategories = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  void _updateTagPreviews(String val) {
    if (val.trim().isEmpty) {
      setState(() => _parsedTags = []);
      return;
    }
    setState(() {
      _parsedTags = val
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
    });
  }

  void _insertFormatting(String prefix, String suffix) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    if (!selection.isValid) {
      _contentController.text = '$text$prefix$suffix';
      return;
    }
    final start = selection.start;
    final end = selection.end;
    final selectedText = text.substring(start, end);
    final replacement = '$prefix${selectedText.isEmpty ? 'text' : selectedText}$suffix';

    _contentController.text = text.replaceRange(start, end, replacement);
    _contentController.selection = TextSelection.collapsed(offset: start + prefix.length + (selectedText.isEmpty ? 4 : selectedText.length));
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    if (_titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final helpdeskSvc = ref.read(helpdeskServiceProvider);
      await helpdeskSvc.createKnowledgeBaseArticle({
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'category': _category,
        'tags': _tagsController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Article created successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Create Knowledge Base Article',
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Publish policy guides, SOPs, setup instructions, or FAQs for your organization.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Article Title *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Article title is required.' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _categories.any((c) => c['code'] == _category) ? _category : null,
                            decoration: const InputDecoration(
                              labelText: 'Category *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.folder),
                            ),
                            items: _categories.map<DropdownMenuItem<String>>((cat) {
                              return DropdownMenuItem<String>(
                                value: cat['code']?.toString() ?? 'GENERAL',
                                child: Text(cat['name']?.toString() ?? cat['code']?.toString() ?? ''),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => _category = v ?? 'GENERAL'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tagsController,
                      decoration: const InputDecoration(
                        labelText: 'Tags (Comma separated)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.tag),
                        hintText: 'policy, leave, rules, hr',
                      ),
                      onChanged: _updateTagPreviews,
                    ),
                    if (_parsedTags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: _parsedTags.map((tag) {
                          return Chip(
                            avatar: const Icon(Icons.tag, size: 14),
                            label: Text(tag, style: const TextStyle(fontSize: 12)),
                            backgroundColor: AppColors.lightAccent,
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Article Body Content *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.grey.shade100,
                          ),
                          child: Row(
                            children: [
                              IconButton(icon: const Icon(Icons.format_bold, size: 18), tooltip: 'Bold', onPressed: () => _insertFormatting('**', '**')),
                              IconButton(icon: const Icon(Icons.format_italic, size: 18), tooltip: 'Italic', onPressed: () => _insertFormatting('*', '*')),
                              IconButton(icon: const Icon(Icons.title, size: 18), tooltip: 'Heading', onPressed: () => _insertFormatting('### ', '')),
                              IconButton(icon: const Icon(Icons.format_list_bulleted, size: 18), tooltip: 'List', onPressed: () => _insertFormatting('- ', '')),
                              IconButton(icon: const Icon(Icons.code, size: 18), tooltip: 'Code', onPressed: () => _insertFormatting('`', '`')),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _contentController,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                        hintText: 'Write your article content here... Markdown formatting is supported.',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Article content is required.' : null,
                    ),
                    if (_submitted && _contentController.text.trim().isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Article content is required.', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Publish Article', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('💡 Publishing Guidelines', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 8),
                          Text('• Clear & Concise Title: Use descriptive titles that clearly explain the topic or process.'),
                          Text('• Select Right Category: File under IT, HR, or Finance so employees can easily search.'),
                          Text('• Use Formatting Tools: Utilize headings, bold text, and bullet points to organize long guides.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
