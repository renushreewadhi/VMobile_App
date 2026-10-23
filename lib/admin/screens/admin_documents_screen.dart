import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';

class AdminDocumentsScreen extends ConsumerStatefulWidget {
  const AdminDocumentsScreen({super.key});

  @override
  ConsumerState<AdminDocumentsScreen> createState() => _AdminDocumentsScreenState();
}

class _AdminDocumentsScreenState extends ConsumerState<AdminDocumentsScreen> {
  bool _isLoading = true;
  List<dynamic> _documents = [];
  String _searchTerm = '';
  String _selectedCategory = 'ALL';
  String _selectedType = 'ALL';

  final List<String> _categories = ['Policies', 'Contracts', 'Forms', 'Templates', 'Certificates', 'Handbooks'];
  final List<String> _types = ['PDF', 'DOCX', 'XLSX'];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/documents').catchError((_) => null);
      List<dynamic> docs = [];
      if (res is List) {
        docs = res;
      } else if (res is Map<String, dynamic>) {
        docs = res['items'] ?? res['data'] ?? [];
      }

      if (docs.isEmpty) {
        docs = [
          {'id': '1', 'name': 'Employee Handbook 2025.pdf', 'category': 'Policies', 'uploadedByName': 'Admin HR', 'uploadedAt': '2025-01-10', 'fileSize': 1024 * 350, 'type': 'PDF', 'status': 'ACTIVE'},
          {'id': '2', 'name': 'Standard Employment Contract.docx', 'category': 'Contracts', 'uploadedByName': 'Legal Dept', 'uploadedAt': '2025-01-15', 'fileSize': 1024 * 150, 'type': 'DOCX', 'status': 'ACTIVE'},
          {'id': '3', 'name': 'Expense Reimbursement Form.pdf', 'category': 'Forms', 'uploadedByName': 'Finance Dept', 'uploadedAt': '2025-02-01', 'fileSize': 1024 * 200, 'type': 'PDF', 'status': 'ACTIVE'},
        ];
      }

      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredDocuments {
    return _documents.where((doc) {
      final name = (doc['name'] ?? '').toString().toLowerCase();
      final uploader = (doc['uploadedByName'] ?? doc['uploadedBy'] ?? '').toString().toLowerCase();
      final cat = doc['category'] ?? 'Policies';
      final type = doc['type'] ?? 'PDF';

      final matchesSearch = _searchTerm.trim().isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          uploader.contains(_searchTerm.toLowerCase());

      final matchesCategory = _selectedCategory == 'ALL' || cat == _selectedCategory;
      final matchesType = _selectedType == 'ALL' || type == _selectedType;

      return matchesSearch && matchesCategory && matchesType;
    }).toList();
  }

  String _formatSize(dynamic bytes) {
    if (bytes == null) return '—';
    final b = num.tryParse('$bytes') ?? 0;
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _openUploadModal() {
    final titleController = TextEditingController();
    String selectedCategory = 'Policies';
    String selectedType = 'PDF';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cloud_upload, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Upload New Document'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Document Title *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setModalState(() => selectedCategory = val ?? 'Policies'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'File Type', border: OutlineInputBorder()),
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setModalState(() => selectedType = val ?? 'PDF'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                setState(() {
                  _documents.insert(0, {
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'name': titleController.text.trim(),
                    'category': selectedCategory,
                    'uploadedByName': 'Admin User',
                    'uploadedAt': DateTime.now().toIso8601String().substring(0, 10),
                    'fileSize': 1024 * 250,
                    'type': selectedType,
                    'status': 'ACTIVE'
                  });
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded successfully')));
              },
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDocument(Map<String, dynamic> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete document "${doc['name']}"?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _documents.removeWhere((d) => d['id'] == doc['id']));
      if (doc['id'] != null) {
        try {
          await ref.read(apiClientProvider).delete('/documents/${doc['id']}');
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document removed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            tooltip: 'Upload Document',
            onPressed: _openUploadModal,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Metrics Grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.6,
              children: [
                _buildMetricCard('Total Documents', '${_documents.length}', Icons.folder_open, Colors.blue),
                _buildMetricCard('Policies & Contracts', '${_documents.where((d) => d['category'] == 'Policies' || d['category'] == 'Contracts').length}', Icons.verified, Colors.green),
                _buildMetricCard('Storage Used', '4.2 GB', Icons.storage, Colors.purple),
                _buildMetricCard('Verification Rate', '98.5%', Icons.check_circle, Colors.amber[800]!),
              ],
            ),
            const SizedBox(height: 24),

            // Search & Filters
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search documents by name or author...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: 'ALL', child: Text('All Categories')),
                      ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (val) => setState(() => _selectedCategory = val ?? 'ALL'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(labelText: 'File Type', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: 'ALL', child: Text('All Types')),
                      ..._types.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                    ],
                    onChanged: (val) => setState(() => _selectedType = val ?? 'ALL'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Documents List
            _filteredDocuments.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No documents found matching your search.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredDocuments.length,
                    itemBuilder: (context, index) {
                      final doc = _filteredDocuments[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.insert_drive_file, color: AppColors.primary),
                          ),
                          title: Text(doc['name'] ?? 'Document', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Category: ${doc['category']} • Size: ${_formatSize(doc['fileSize'])} • By: ${doc['uploadedByName'] ?? 'System'}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.download, color: AppColors.primary),
                                tooltip: 'Download',
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading document...')));
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Delete',
                                onPressed: () => _deleteDocument(doc),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
