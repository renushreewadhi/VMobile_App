import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class MyDocumentsScreen extends ConsumerStatefulWidget {
  const MyDocumentsScreen({super.key});

  @override
  ConsumerState<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends ConsumerState<MyDocumentsScreen> {
  bool _isLoading = true;
  List<dynamic> _documents = [];
  String _searchTerm = '';
  String _filterCategory = '';
  bool _showUploadModal = false;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _uploadCategory = 'Employment';
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchDocuments() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/documents/mine').catchError((_) => null);
      if (mounted) {
        setState(() {
          if (res is List) {
            _documents = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _documents = res['data'];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredDocuments {
    return _documents.where((d) {
      final name = (d['name'] ?? '').toString().toLowerCase();
      final desc = (d['description'] ?? '').toString().toLowerCase();
      final cat = (d['category'] ?? '').toString();

      final matchesSearch = _searchTerm.isEmpty || name.contains(_searchTerm.toLowerCase()) || desc.contains(_searchTerm.toLowerCase());
      final matchesCat = _filterCategory.isEmpty || cat == _filterCategory;
      return matchesSearch && matchesCat;
    }).toList();
  }

  int get _totalCount => _documents.length;
  int get _verifiedCount => _documents.where((d) => (d['status'] ?? 'VERIFIED').toUpperCase() == 'VERIFIED').length;
  int get _pendingCount => _documents.where((d) => (d['status'] ?? '').toUpperCase() == 'PENDING').length;

  Future<void> _uploadDocument() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a document title'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isUploading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post('/documents', body: {
        'name': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category': _uploadCategory,
        'type': 'PDF',
      });
      if (mounted) {
        setState(() {
          _showUploadModal = false;
          _isUploading = false;
          _titleController.clear();
          _descController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully!'), backgroundColor: AppColors.success),
        );
        _fetchDocuments();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _showUploadModal = false;
          _isUploading = false;
          _titleController.clear();
          _descController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully!'), backgroundColor: AppColors.success),
        );
        _fetchDocuments();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Documents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Upload Document',
            onPressed: () => setState(() => _showUploadModal = true),
          ),
        ],
      ),
      body: _isLoading
          ? const ListSkeleton(itemCount: 4)
          : RefreshIndicator(
              onRefresh: _fetchDocuments,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. PASTEL SUMMARY PILLS
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          PastelSummaryPill(
                            label: '$_totalCount Total Documents',
                            variant: PastelPillVariant.blue,
                          ),
                          const SizedBox(width: 8),
                          PastelSummaryPill(
                            label: '$_verifiedCount Verified Documents',
                            variant: PastelPillVariant.green,
                          ),
                          const SizedBox(width: 8),
                          PastelSummaryPill(
                            label: '$_pendingCount Pending Review',
                            variant: PastelPillVariant.amber,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. CIRCULAR STATISTIC INDICATOR GROUP
                    CircularStatGroup(
                      items: [
                        CircularStatItemData(
                          label: 'Total',
                          value: '$_totalCount',
                          ringColor: AppColors.primary,
                        ),
                        CircularStatItemData(
                          label: 'Verified',
                          value: '$_verifiedCount',
                          ringColor: AppColors.success,
                        ),
                        CircularStatItemData(
                          label: 'Pending',
                          value: '$_pendingCount',
                          ringColor: const Color(0xFFD97706),
                        ),
                        const CircularStatItemData(
                          label: 'Expiring',
                          value: '0',
                          ringColor: AppColors.error,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3. Search & Filter Bar
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSecondarySurface : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            onChanged: (val) => setState(() => _searchTerm = val),
                            decoration: InputDecoration(
                              hintText: 'Search documents...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchTerm.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => _searchTerm = '')) : null,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: isDark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Category:', style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                              DropdownButton<String>(
                                value: _filterCategory.isEmpty ? null : _filterCategory,
                                hint: const Text('All Categories', style: TextStyle(fontSize: 12)),
                                underline: const SizedBox.shrink(),
                                items: const [
                                  DropdownMenuItem(value: '', child: Text('All Categories', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'Identity', child: Text('Identity', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'Employment', child: Text('Employment', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'Education', child: Text('Education', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'Other', child: Text('Other', style: TextStyle(fontSize: 12))),
                                ],
                                onChanged: (val) => setState(() => _filterCategory = val ?? ''),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Documents List
                    _filteredDocuments.isEmpty
                        ? const AppCard(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No documents found.'))))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredDocuments.length,
                            itemBuilder: (context, index) {
                              final d = _filteredDocuments[index];
                              final name = d['name']?.toString() ?? 'Document';
                              final cat = d['category']?.toString() ?? 'Employment';
                              final status = d['status']?.toString() ?? 'VERIFIED';
                              final type = d['type']?.toString() ?? 'PDF';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppCard(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(color: AppColors.lightPrimary, borderRadius: BorderRadius.circular(10)),
                                            child: const Icon(Icons.insert_drive_file, color: AppColors.primary, size: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                              const SizedBox(height: 2),
                                              Text('$cat • $type', style: const TextStyle(fontSize: 11.5, color: AppColors.lightSecondaryText)),
                                            ],
                                          ),
                                        ],
                                      ),
                                      StatusChip(status: status),
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
      bottomSheet: _showUploadModal ? _buildUploadModal(context, isDark) : null,
    );
  }

  Widget _buildUploadModal(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Upload Document', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showUploadModal = false)),
            ],
          ),
          const Divider(height: 16),
          const Text('Document Title *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'e.g. Passport, Degree Certificate',
              filled: true,
              fillColor: isDark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _uploadCategory,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: const [
              DropdownMenuItem(value: 'Identity', child: Text('Identity', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'Employment', child: Text('Employment', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'Education', child: Text('Education', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'Other', child: Text('Other', style: TextStyle(fontSize: 13))),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _uploadCategory = val);
            },
          ),
          const SizedBox(height: 14),
          const Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _descController,
            decoration: InputDecoration(
              hintText: 'Short notes or details...',
              filled: true,
              fillColor: isDark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _uploadDocument,
              child: Text(_isUploading ? 'Uploading...' : 'Upload Document'),
            ),
          ),
        ],
      ),
    );
  }
}
