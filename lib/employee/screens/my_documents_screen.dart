import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
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
      return diff >= 0 && diff <= 30;
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
  String _activeTab = 'documents'; // 'documents' or 'upload'

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _uploadCategory = 'Employment';
  final _expiryController = TextEditingController();
  bool _isUploading = false;

  XFile? _pickedFile;
  String? _selectedFileName;
  String? _selectedFileSize;
  String? _titleError;

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
      final res = await apiClient.get(ApiEndpoints.myDocuments);
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

  Future<void> _pickFile(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        String sizeStr = '${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB';
        if (bytes.length < 1024 * 1024) {
          sizeStr = '${(bytes.length / 1024).round()} KB';
        }
        setState(() {
          _pickedFile = pickedFile;
          _selectedFileName = pickedFile.name;
          _selectedFileSize = sizeStr;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadDocument() async {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _titleError = 'Document title is required');
      return;
    }

    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file to upload'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isUploading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final bytes = await _pickedFile!.readAsBytes();

      final fields = {
        'name': _titleController.text.trim(),
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category': _uploadCategory,
        'type': 'PDF',
        if (_expiryController.text.trim().isNotEmpty) 'expiryDate': _expiryController.text.trim(),
      };

      final files = [
        http.MultipartFile.fromBytes('file', bytes, filename: _pickedFile!.name),
      ];

      await apiClient.postMultipart(ApiEndpoints.documentsUpload, fields: fields, files: files);

      if (!mounted) return;
      setState(() {
        _activeTab = 'documents';
        _isUploading = false;
        _pickedFile = null;
        _selectedFileName = null;
        _selectedFileSize = null;
        _titleController.clear();
        _descController.clear();
        _expiryController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document uploaded successfully!'), backgroundColor: AppColors.success),
      );
      _fetchDocuments();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload document: $e'), backgroundColor: AppColors.error),
      );
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
      await apiClient.delete(ApiEndpoints.documentsDelete(doc.id));
      if (!mounted) return;
      setState(() => _documents.removeWhere((d) {
        final docItem = _toDoc(d);
        return docItem != null && docItem.id == doc.id;
      }));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document deleted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete document: $e'), backgroundColor: AppColors.error));
    }
  }

  void _previewDocument(DocumentItem d) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkMainSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
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
              const Divider(height: 24, color: Color(0xFFE5E7EB)),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTabBar(isDark),
                const SizedBox(height: 16),
                if (_activeTab == 'documents') ...[
                  _buildSlimStatsCard(isDark),
                  const SizedBox(height: 16),
                  _buildSearchFilterRow(isDark),
                  const SizedBox(height: 16),
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
                  else if (_filteredDocuments.isEmpty)
                    _buildEmptyState(isDark)
                  else ...[
                    if (_filteredDocuments.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_filteredDocuments.length} document${_filteredDocuments.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkSecondaryText : const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredDocuments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _buildDocumentCard(_filteredDocuments[index], isDark);
                      },
                    ),
                  ],
                ] else ...[
                  _buildUploadTabContent(isDark),
                ],
              ],
            ),
          ),
        ),
        if (_activeTab == 'upload') _buildStickyUploadBar(isDark),
      ],
    );

    if (!_showAppBar) return content;

    return GlassScaffold(
      title: 'My Documents',
      body: content,
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _tabItem('My Documents', 'documents', isDark, count: _documents.length),
          _tabItem('Upload', 'upload', isDark),
        ],
      ),
    );
  }

  Widget _tabItem(String label, String tabKey, bool isDark, {int? count}) {
    final isSelected = _activeTab == tabKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = tabKey),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : (isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B)),
                ),
              ),
              if (tabKey == 'documents' && count != null && count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withOpacity(0.25) : (isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : (isDark ? AppColors.darkPrimaryText : const Color(0xFF475569)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlimStatsCard(bool isDark) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          _statColumn('Total', '$_totalCount', Icons.folder_open, const Color(0xFF0066FF), _totalCount > 0, isDark),
          _verticalDivider(isDark),
          _statColumn('Verified', '$_verifiedCount', Icons.check_circle_rounded, const Color(0xFF16A34A), _verifiedCount > 0, isDark),
          _verticalDivider(isDark),
          _statColumn('Pending', '$_pendingCount', Icons.hourglass_bottom, const Color(0xFFD97706), _pendingCount > 0, isDark),
          _verticalDivider(isDark),
          _statColumn('Expiring', '$_expiringCount', Icons.warning_amber_rounded, const Color(0xFFDC2626), _expiringCount > 0, isDark),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value, IconData icon, Color color, bool hasValue, bool isDark) {
    final numColor = hasValue ? color : (isDark ? AppColors.darkSecondaryText : const Color(0xFF9CA3AF));
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: numColor),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: numColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkSecondaryText : const Color(0xFF4B5563),
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider(bool isDark) {
    return Container(
      height: 32,
      width: 1,
      color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB),
    );
  }

  Widget _buildSearchFilterRow(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: TextField(
                  onChanged: (val) => setState(() => _searchTerm = val),
                  style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                  decoration: InputDecoration(
                    hintText: 'Search documents',
                    hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _searchTerm.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => _searchTerm = ''))
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1A2632) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.primary)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2632) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
              ),
              child: IconButton(
                icon: Icon(Icons.tune, size: 20, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF4B5563)),
                onPressed: _openFilterBottomSheet,
                tooltip: 'Filter categories',
              ),
            ),
          ],
        ),
        if (_filterCategory.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              height: 32,
              padding: const EdgeInsets.only(left: 12, right: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _filterCategory,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => setState(() => _filterCategory = ''),
                    borderRadius: BorderRadius.circular(999),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 14, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _openFilterBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkMainSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        const categories = ['Identity', 'Employment', 'Education', 'Other'];
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filter by Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                  TextButton(
                    onPressed: () {
                      setState(() => _filterCategory = '');
                      Navigator.pop(context);
                    },
                    child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
              const Divider(height: 16, color: Color(0xFFE5E7EB)),
              ...categories.map((cat) => InkWell(
                    onTap: () {
                      setState(() => _filterCategory = cat);
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(cat, style: TextStyle(color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontSize: 14)),
                          if (_filterCategory == cat) const Icon(Icons.check, color: AppColors.primary, size: 20),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFileIconTile(String type) {
    Color color;
    IconData icon;
    switch (type.toLowerCase()) {
      case 'pdf':
        color = const Color(0xFFDC2626); // Red
        icon = Icons.picture_as_pdf;
        break;
      case 'word':
      case 'doc':
      case 'docx':
        color = const Color(0xFF2563EB); // Blue
        icon = Icons.description;
        break;
      case 'image':
      case 'png':
      case 'jpg':
      case 'jpeg':
        color = const Color(0xFF16A34A); // Green
        icon = Icons.image;
        break;
      default:
        color = AppColors.primary;
        icon = Icons.insert_drive_file;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildDocumentCard(DocumentItem d, bool isDark) {
    bool isExpiringSoon = false;
    int daysToExpiry = 0;
    if (d.expiry.isNotEmpty) {
      try {
        final expDate = DateTime.parse(d.expiry);
        daysToExpiry = expDate.difference(DateTime.now()).inDays;
        isExpiringSoon = daysToExpiry >= 0 && daysToExpiry <= 30;
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2632) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildFileIconTile(d.type),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        d.category.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Uploaded ${d.uploadedOn.isNotEmpty ? d.uploadedOn : 'recently'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (isExpiringSoon) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Expires in $daysToExpiry days',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.amber),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusChip(status: d.status),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 20, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B)),
                onSelected: (val) {
                  if (val == 'view') {
                    _previewDocument(d);
                  } else if (val == 'download') {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloading document ${d.name}...')));
                  } else if (val == 'delete') {
                    _deleteDocument(d);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'view', child: Text('View')),
                  const PopupMenuItem(value: 'download', child: Text('Download')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final hasFilter = _searchTerm.isNotEmpty || _filterCategory.isNotEmpty;
    final hasAnyDocs = _documents.isNotEmpty;

    if (!hasAnyDocs) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.folder_open, size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'No documents yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Upload your ID, contracts and certificates to keep them in one place.',
              style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => setState(() => _activeTab = 'upload'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Upload your first document', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off, size: 28, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'No documents match your filter',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Try a different search or category.',
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          if (hasFilter) ...[
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => setState(() {
                _searchTerm = '';
                _filterCategory = '';
              }),
              child: const Text('Clear filters', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadTabContent(bool isDark) {
    final hasFile = _selectedFileName != null && _selectedFileName!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasFile)
          InkWell(
            onTap: _openFileSourceBottomSheet,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.4)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 32, color: AppColors.primary),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to choose a file',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PDF, DOC, DOCX, PNG, JPG · up to 15MB',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2632) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.insert_drive_file, color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFileName!,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_selectedFileSize != null)
                            Text(
                              _selectedFileSize!,
                              style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B)),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                        _selectedFileName = null;
                        _selectedFileSize = null;
                      }),
                    ),
                  ],
                ),
                if (_isUploading) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(color: AppColors.primary),
                ],
              ],
            ),
          ),
        const SizedBox(height: 16),

        _buildFormFieldLabel('Document title *', isDark),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: TextField(
            controller: _titleController,
            onChanged: (_) => setState(() {
              if (_titleController.text.trim().isNotEmpty) _titleError = null;
            }),
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
            decoration: InputDecoration(
              hintText: 'e.g. Passport, Offer Letter',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF9CA3AF)),
              filled: true,
              fillColor: isDark ? const Color(0xFF1A2632) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        if (_titleError != null) ...[
          const SizedBox(height: 4),
          Text(_titleError!, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
        ],
        const SizedBox(height: 16),

        _buildFormFieldLabel('Category', isDark),
        const SizedBox(height: 6),
        InkWell(
          onTap: _openCategorySelectBottomSheet,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2632) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _uploadCategory,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                ),
                const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        _buildFormFieldLabel('Expiry date (optional)', isDark),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: TextField(
            controller: _expiryController,
            readOnly: true,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 365)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2040),
              );
              if (picked != null) {
                setState(() {
                  _expiryController.text = DateFormat('yyyy-MM-dd').format(picked);
                });
              }
            },
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
            decoration: InputDecoration(
              hintText: 'Select expiry date',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF9CA3AF)),
              suffixIcon: const Icon(Icons.calendar_today, size: 18, color: Color(0xFF64748B)),
              filled: true,
              fillColor: isDark ? const Color(0xFF1A2632) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Format: YYYY-MM-DD',
          style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),

        _buildFormFieldLabel('Description (optional)', isDark),
        const SizedBox(height: 6),
        TextField(
          controller: _descController,
          maxLines: 2,
          style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
          decoration: InputDecoration(
            hintText: 'Add notes about this document...',
            hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF9CA3AF)),
            filled: true,
            fillColor: isDark ? const Color(0xFF1A2632) : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 96),
      ],
    );
  }

  Widget _buildFormFieldLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: isDark ? AppColors.darkPrimaryText : const Color(0xFF374151),
      ),
    );
  }

  void _openFileSourceBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkMainSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select File Source', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
              const Divider(height: 16, color: Color(0xFFE5E7EB)),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _pickFile(ImageSource.camera);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.camera_alt, color: AppColors.primary, size: 22),
                      const SizedBox(width: 16),
                      Text('Camera', style: TextStyle(color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _pickFile(ImageSource.gallery);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.photo_library, color: AppColors.primary, size: 22),
                      const SizedBox(width: 16),
                      Text('Photo Library / Files', style: TextStyle(color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCategorySelectBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkMainSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        const categories = ['Identity', 'Employment', 'Education', 'Other'];
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
              const Divider(height: 16, color: Color(0xFFE5E7EB)),
              ...categories.map((cat) => InkWell(
                    onTap: () {
                      setState(() => _uploadCategory = cat);
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(cat, style: TextStyle(color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontSize: 14, fontWeight: FontWeight.w500)),
                          if (_uploadCategory == cat) const Icon(Icons.check, color: AppColors.primary, size: 20),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStickyUploadBar(bool isDark) {
    final hasFile = _selectedFileName != null && _selectedFileName!.isNotEmpty;
    final hasTitle = _titleController.text.trim().isNotEmpty;
    final canSubmit = hasFile && hasTitle && !_isUploading;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkMainSurface : Colors.white,
          border: Border(top: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB))),
        ),
        child: SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: canSubmit
                ? () {
                    if (_titleController.text.trim().isEmpty) {
                      setState(() => _titleError = 'Document title is required');
                      return;
                    }
                    _uploadDocument();
                  }
                : null,
            icon: _isUploading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload_outlined, size: 20),
            label: Text(
              _isUploading ? 'Uploading...' : 'Upload document',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDark ? AppColors.darkSecondarySurface : const Color(0xFFE2E8F0),
              disabledForegroundColor: isDark ? AppColors.darkSecondaryText : const Color(0xFF9CA3AF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}
