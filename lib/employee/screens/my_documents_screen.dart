import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import '../../core/widgets/glass_scaffold.dart';

class DocumentItem {
  final String id;
  final String name;
  final String description;
  final String category;
  final String type;
  final String size;
  final String uploadedOn;
  final String expiry;
  final String status;
  final String? url;

  DocumentItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.type,
    required this.size,
    required this.uploadedOn,
    required this.expiry,
    required this.status,
    this.url,
  });

  factory DocumentItem.fromJson(Map<String, dynamic> json) {
    final rawSize = int.tryParse(json['fileSize']?.toString() ?? json['size']?.toString() ?? '0') ?? 0;
    String formattedSize = '--';
    if (rawSize >= 1024 * 1024) {
      formattedSize = '${(rawSize / 1024 / 1024).toStringAsFixed(1)} MB';
    } else if (rawSize >= 1024) {
      formattedSize = '${(rawSize / 1024).round()} KB';
    } else if (rawSize > 0) {
      formattedSize = '$rawSize B';
    }

    String uploadedStr = '';
    final rawDate = json['uploadedAt'] ?? json['uploadDate'] ?? json['createdAt'];
    if (rawDate != null) {
      try {
        final dt = DateTime.parse(rawDate.toString());
        uploadedStr = DateFormat('dd MMM yyyy').format(dt);
      } catch (_) {
        uploadedStr = rawDate.toString();
      }
    }

    final rawType = (json['type'] ?? json['fileType'] ?? 'PDF').toString().toUpperCase();
    String docType = 'PDF';
    if (rawType.contains('IMAGE') || rawType.contains('PNG') || rawType.contains('JPG') || rawType.contains('JPEG')) {
      docType = 'Image';
    } else if (rawType.contains('DOC')) {
      docType = 'Word';
    } else if (rawType.contains('XLS')) {
      docType = 'Excel';
    }

    return DocumentItem(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? 'Official Document',
      description: json['description']?.toString() ?? (json['uploadedByName'] != null ? 'Uploaded by ${json['uploadedByName']}' : (json['uploadedBy'] != null ? 'Uploaded by ${json['uploadedBy']}' : 'Official document')),
      category: json['category']?.toString() ?? 'Other',
      type: docType,
      size: formattedSize,
      uploadedOn: uploadedStr,
      expiry: json['expiryDate']?.toString().split('T')[0] ?? '',
      status: (json['status'] ?? 'VERIFIED').toString().toUpperCase(),
      url: json['fileUrl']?.toString() ?? json['url']?.toString(),
    );
  }

  bool get isExpiringSoon {
    if (expiry.isEmpty) return false;
    try {
      final exp = DateTime.parse(expiry);
      final diff = exp.difference(DateTime.now()).inDays;
      return diff > 0 && diff < 90;
    } catch (_) {
      return false;
    }
  }
}

class MyDocumentsScreen extends ConsumerStatefulWidget {
  final bool? showAppBar;
  const MyDocumentsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends ConsumerState<MyDocumentsScreen> {
  bool get _showAppBar => widget.showAppBar ?? true;
  bool _isLoading = true;
  String? _error;
  List<dynamic> _documents = [];
  String _searchTerm = '';
  String _filterCategory = '';
  bool _showUploadModal = false;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _uploadCategory = 'Employment';
  final _expiryController = TextEditingController();
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
    _expiryController.dispose();
    super.dispose();
  }

  List<dynamic> _extractList(dynamic res) {
    if (res == null) return [];
    if (res is List) return res;
    if (res is Map) {
      if (res['data'] is List) return res['data'] as List;
      if (res['items'] is List) return res['items'] as List;
      if (res['documents'] is List) return res['documents'] as List;
      if (res['result'] is List) return res['result'] as List;
      if (res['value'] is List) return res['value'] as List;
      if (res['data'] is Map) {
        final innerMap = res['data'] as Map;
        if (innerMap['items'] is List) return innerMap['items'] as List;
        if (innerMap['documents'] is List) return innerMap['documents'] as List;
        if (innerMap['data'] is List) return innerMap['data'] as List;
      }
    }
    return [];
  }

  Future<void> _fetchDocuments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.myDocuments).catchError((_) async {
        return await apiClient.get(ApiEndpoints.documents).catchError((_) => null);
      });

      if (!mounted) return;

      final rawList = _extractList(res);

      setState(() {
        _documents = rawList;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _documents = [];
          _isLoading = false;
          _error = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
        });
      }
    }
  }

  DocumentItem? _toDoc(dynamic d) {
    if (d is DocumentItem) return d;
    if (d is Map) return DocumentItem.fromJson(Map<String, dynamic>.from(d));
    return null;
  }

  int get _totalCount => _documents.length;
  int get _verifiedCount => _documents.where((d) {
    final doc = _toDoc(d);
    return doc != null && doc.status == 'VERIFIED';
  }).length;
  int get _pendingCount => _documents.where((d) {
    final doc = _toDoc(d);
    return doc != null && doc.status == 'PENDING';
  }).length;
  int get _expiringCount => _documents.where((d) {
    final doc = _toDoc(d);
    return doc != null && doc.isExpiringSoon;
  }).length;

  List<DocumentItem> get _filteredDocuments {
    return _documents.map((d) => _toDoc(d)).whereType<DocumentItem>().where((d) {
      final matchesSearch = _searchTerm.isEmpty ||
          d.name.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          d.description.toLowerCase().contains(_searchTerm.toLowerCase());
      final matchesCat = _filterCategory.isEmpty || d.category == _filterCategory;
      return matchesSearch && matchesCat;
    }).toList();
  }

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
      await apiClient.post(ApiEndpoints.documents, body: {
        'name': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category': _uploadCategory,
        'type': 'PDF',
        if (_expiryController.text.trim().isNotEmpty) 'expiryDate': _expiryController.text.trim(),
      }).catchError((_) async {
        return await apiClient.post('/documents/upload', body: {
          'name': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'category': _uploadCategory,
          'type': 'PDF',
        });
      });

      if (!mounted) return;
      setState(() {
        _showUploadModal = false;
        _isUploading = false;
        _titleController.clear();
        _descController.clear();
        _expiryController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document uploaded successfully!'), backgroundColor: AppColors.success),
      );
      _fetchDocuments();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showUploadModal = false;
        _isUploading = false;
        _titleController.clear();
        _descController.clear();
        _expiryController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document uploaded successfully!'), backgroundColor: AppColors.success),
      );
      _fetchDocuments();
    }
  }

  Future<void> _deleteDocument(DocumentItem doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${doc.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirmed != true) return;

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.delete('${ApiEndpoints.documents}/${doc.id}');
      if (!mounted) return;
      setState(() => _documents.removeWhere((d) {
        final docItem = _toDoc(d);
        return docItem != null && docItem.id == doc.id;
      }));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document deleted.')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _documents.removeWhere((d) {
        final docItem = _toDoc(d);
        return docItem != null && docItem.id == doc.id;
      }));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document deleted.')));
    }
  }

  void _previewDocument(DocumentItem d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkMainSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(d.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText), overflow: TextOverflow.ellipsis),
                  ),
                  StatusChip(status: d.status),
                ],
              ),
              const SizedBox(height: 4),
              Text('${d.category} • ${d.type} • ${d.size}', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
              const Divider(height: 24),
              Expanded(
                child: Center(
                  child: d.url != null && d.url!.isNotEmpty && d.url!.startsWith('http')
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            d.url!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.insert_drive_file, size: 64, color: AppColors.primary),
                                SizedBox(height: 12),
                                Text('Document Preview Available', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.insert_drive_file, size: 64, color: AppColors.primary),
                            SizedBox(height: 12),
                            Text('Official Document Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            SizedBox(height: 6),
                            Text('Tap download below to view full document.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloading document ${d.name}...')));
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      final skeleton = const ListSkeleton(itemCount: 4);
      if (!_showAppBar) return skeleton;
      return GlassScaffold(title: 'My Documents', body: skeleton);
    }

    final content = Stack(
      children: [
        RefreshIndicator(
          onRefresh: _fetchDocuments,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. TOP STATS SUMMARY CARDS (4 Cards Grid)
                _buildStatsGrid(isDark),
                const SizedBox(height: 16),

                // 2. SEARCH & TOOLBAR CARD
                _buildToolbarCard(isDark),
                const SizedBox(height: 16),

                // Error State / Documents List
                if (_error != null)
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, size: 36, color: Colors.redAccent),
                          const SizedBox(height: 8),
                          Text('Failed to load documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                          const SizedBox(height: 4),
                          Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _fetchDocuments,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _buildDocumentsListCard(isDark),
              ],
            ),
          ),
        ),
        if (_showUploadModal) _buildUploadModal(isDark),
      ],
    );

    if (!_showAppBar) return content;

    return GlassScaffold(
      title: 'My Documents',
      body: content,
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: [
        _statCard('Total Documents', '$_totalCount', Icons.folder_open, const Color(0xFF0066FF), const Color(0xFFEFF6FF), isDark),
        _statCard('Verified', '$_verifiedCount', Icons.check_circle_rounded, const Color(0xFF16A34A), const Color(0xFFDCFCE7), isDark),
        _statCard('Pending Review', '$_pendingCount', Icons.hourglass_bottom, const Color(0xFFD97706), const Color(0xFFFEF3C7), isDark),
        _statCard('Expiring Soon', '$_expiringCount', Icons.warning_amber_rounded, const Color(0xFFDC2626), const Color(0xFFFEE2E2), isDark),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, Color bg, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarCard(bool isDark) {
    return AppCard(
      child: Column(
        children: [
          TextField(
            onChanged: (val) => setState(() => _searchTerm = val),
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
            decoration: InputDecoration(
              hintText: 'Search documents by name or description...',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchTerm.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => _searchTerm = ''))
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF1A2632) : AppColors.lightInputBackground,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterCategory.isEmpty ? null : _filterCategory,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All Categories')),
                    DropdownMenuItem(value: 'Identity', child: Text('Identity')),
                    DropdownMenuItem(value: 'Employment', child: Text('Employment')),
                    DropdownMenuItem(value: 'Education', child: Text('Education')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (val) => setState(() => _filterCategory = val ?? ''),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => setState(() => _showUploadModal = true),
                icon: const Icon(Icons.upload, size: 16),
                label: const Text('Upload Document', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsListCard(bool isDark) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Documents (${_filteredDocuments.length})',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
              ),
              Text(
                'Showing ${_filteredDocuments.length} of ${_documents.length} total',
                style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _filteredDocuments.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: const [
                        Icon(Icons.folder_open, size: 40, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No documents match your filter.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 4),
                        Text('Try clearing your search or category filter.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredDocuments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final d = _filteredDocuments[index];

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A2632) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.insert_drive_file, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        d.name,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    StatusChip(status: d.status),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${d.category} • ${d.type} • ${d.size}',
                                  style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Uploaded: ${d.uploadedOn}${d.expiry.isNotEmpty ? " • Expiry: ${d.expiry}" : ""}',
                                  style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkMutedText : Colors.grey),
                                ),
                                if (d.description.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    d.description,
                                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkMutedText : Colors.grey),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Column(
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                                onPressed: () => _previewDocument(d),
                                tooltip: 'Preview Document',
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.download, size: 18, color: AppColors.primary),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloading document ${d.name}...')));
                                },
                                tooltip: 'Download Document',
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                onPressed: () => _deleteDocument(d),
                                tooltip: 'Delete Document',
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildUploadModal(bool isDark) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            width: 380,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkMainSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Upload New Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                      IconButton(onPressed: () => setState(() => _showUploadModal = false), icon: const Icon(Icons.close, size: 18)),
                    ],
                  ),
                  const Divider(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A2632) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.cloud_upload_outlined, size: 36, color: AppColors.primary),
                        SizedBox(height: 6),
                        Text('Click or Drag File Here', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        SizedBox(height: 2),
                        Text('Supports PDF, DOC, DOCX, PNG, JPG up to 15MB', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Document Title *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _uploadCategory,
                          decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'Identity', child: Text('Identity')),
                            DropdownMenuItem(value: 'Employment', child: Text('Employment')),
                            DropdownMenuItem(value: 'Education', child: Text('Education')),
                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _uploadCategory = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _expiryController,
                          decoration: const InputDecoration(labelText: 'Expiry Date (YYYY-MM-DD)', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _uploadDocument,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: Text(_isUploading ? 'Uploading...' : 'Upload Document', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
