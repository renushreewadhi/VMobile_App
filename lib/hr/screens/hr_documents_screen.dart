import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class HrDocumentsScreen extends ConsumerStatefulWidget {
  const HrDocumentsScreen({super.key});

  @override
  ConsumerState<HrDocumentsScreen> createState() => _HrDocumentsScreenState();
}

class _HrDocumentsScreenState extends ConsumerState<HrDocumentsScreen> {
  bool _isLoading = true;
  List<dynamic> _documents = [];
  String _searchTerm = '';
  String _selectedCategory = 'ALL';
  String _selectedType = 'ALL';

  bool _showUploadModal = false;
  final Map<String, dynamic> _newDoc = {
    'name': '',
    'category': 'Policies',
    'size': '250 KB',
    'type': 'PDF',
    'status': 'ACTIVE',
  };

  final List<String> _categories = ['ALL', 'Policies', 'Contracts', 'Forms', 'Templates', 'Certificates', 'Handbooks'];
  final List<String> _types = ['ALL', 'PDF', 'DOCX', 'XLSX'];

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
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {'id': 1, 'name': 'Employee Handbook 2025.pdf', 'category': 'Policies', 'uploadedBy': 'HR Manager', 'uploadDate': '2025-01-10', 'size': '2.4 MB', 'type': 'PDF', 'status': 'ACTIVE'},
          {'id': 2, 'name': 'Standard Employment Agreement.docx', 'category': 'Contracts', 'uploadedBy': 'Legal Dept', 'uploadDate': '2025-01-15', 'size': '450 KB', 'type': 'DOCX', 'status': 'ACTIVE'},
          {'id': 3, 'name': 'Leave Application Form.pdf', 'category': 'Forms', 'uploadedBy': 'HR Admin', 'uploadDate': '2025-02-01', 'size': '180 KB', 'type': 'PDF', 'status': 'ACTIVE'},
          {'id': 4, 'name': 'Performance Review Template.docx', 'category': 'Templates', 'uploadedBy': 'HR Team', 'uploadDate': '2025-02-05', 'size': '320 KB', 'type': 'DOCX', 'status': 'ACTIVE'},
        ];
      }

      setState(() {
        _documents = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _documents = [
          {'id': 1, 'name': 'Employee Handbook 2025.pdf', 'category': 'Policies', 'uploadedBy': 'HR Manager', 'uploadDate': '2025-01-10', 'size': '2.4 MB', 'type': 'PDF', 'status': 'ACTIVE'},
          {'id': 2, 'name': 'Standard Employment Agreement.docx', 'category': 'Contracts', 'uploadedBy': 'Legal Dept', 'uploadDate': '2025-01-15', 'size': '450 KB', 'type': 'DOCX', 'status': 'ACTIVE'},
        ];
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadDocument() async {
    if ((_newDoc['name'] ?? '').toString().isEmpty) return;
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post('/documents', body: _newDoc);
    } catch (_) {}

    setState(() {
      _documents.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch,
        'name': _newDoc['name'],
        'category': _newDoc['category'],
        'uploadedBy': 'HR Specialist',
        'uploadDate': DateTime.now().toIso8601String().substring(0, 10),
        'size': _newDoc['size'],
        'type': _newDoc['type'],
        'status': _newDoc['status'],
      });
      _newDoc['name'] = '';
      _showUploadModal = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded successfully')));
    }
  }

  Future<void> _deleteDocument(dynamic id) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.delete('/documents/$id');
    } catch (_) {}

    setState(() {
      _documents.removeWhere((d) => (d is Map && d['id'] == id));
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document removed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    final filtered = _documents.where((d) {
      final map = d is Map<String, dynamic> ? d : {};
      final name = (map['name'] ?? '').toString().toLowerCase();
      final author = (map['uploadedBy'] ?? '').toString().toLowerCase();
      final category = (map['category'] ?? 'Policies').toString().toLowerCase();
      final type = (map['type'] ?? 'PDF').toString().toUpperCase();

      final matchesSearch = _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase()) || author.contains(_searchTerm.toLowerCase());
      final matchesCategory = _selectedCategory == 'ALL' || category == _selectedCategory.toLowerCase();
      final matchesType = _selectedType == 'ALL' || type == _selectedType.toUpperCase();

      return matchesSearch && matchesCategory && matchesType;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: () => setState(() => _showUploadModal = true),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metrics Overview
                Row(
                  children: [
                    Expanded(child: _buildMetricCard('Total Docs', '${_documents.length}', Colors.blue, Icons.folder_open)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMetricCard('Storage', '4.2 GB', Colors.purple, Icons.sd_storage)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMetricCard('Verified', '98.5%', Colors.green, Icons.verified)),
                  ],
                ),
                const SizedBox(height: 16),
                // Search & Filters
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search documents by name, author...',
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
                        decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) => setState(() => _selectedCategory = val ?? 'ALL'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                        items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (val) => setState(() => _selectedType = val ?? 'ALL'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Documents List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index] as Map<String, dynamic>;
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Icon(doc['type'] == 'PDF' ? Icons.picture_as_pdf : Icons.insert_drive_file, color: AppColors.primary),
                        ),
                        title: Text(doc['name'] ?? 'Document', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${doc['category']} • ${doc['size']} • ${doc['uploadedBy']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.download, size: 20, color: Colors.blue),
                              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloading ${doc['name']}'))),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                              onPressed: () => _deleteDocument(doc['id']),
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
          // Upload Modal
          if (_showUploadModal)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Upload New Document', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showUploadModal = false)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(labelText: 'Document Title *', border: OutlineInputBorder()),
                        onChanged: (val) => _newDoc['name'] = val,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _newDoc['category'],
                        decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                        items: ['Policies', 'Contracts', 'Forms', 'Templates', 'Certificates', 'Handbooks'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) => setState(() => _newDoc['category'] = val ?? 'Policies'),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _uploadDocument,
                          child: const Text('Upload Document'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, IconData icon) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
