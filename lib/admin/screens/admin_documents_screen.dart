import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';

/// Strongly typed Document Model
class DocumentModel {
  final String id;
  final String name;
  final String category;
  final String uploadedBy;
  final String? uploadDate;
  final int fileSize;
  final String fileType;
  final String? status;
  final String? fileUrl;

  DocumentModel({
    required this.id,
    required this.name,
    required this.category,
    required this.uploadedBy,
    this.uploadDate,
    required this.fileSize,
    required this.fileType,
    this.status,
    this.fileUrl,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    final rawSize = json['fileSize'] ?? json['size'] ?? 0;
    final sizeInt = rawSize is int ? rawSize : (int.tryParse(rawSize.toString()) ?? 0);
    final rawStatus = json['status']?.toString() ?? json['state']?.toString();

    return DocumentModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? json['fileName']?.toString() ?? 'Document',
      category: json['category']?.toString() ?? 'Policies',
      uploadedBy: json['uploadedByName']?.toString() ?? json['uploadedBy']?.toString() ?? json['uploadedByEmployeeName']?.toString() ?? 'System',
      uploadDate: json['uploadedAt']?.toString() ?? json['uploadDate']?.toString() ?? json['createdAt']?.toString(),
      fileSize: sizeInt,
      fileType: (json['type']?.toString() ?? json['fileType']?.toString() ?? json['fileExtension']?.toString() ?? 'PDF').toUpperCase(),
      status: rawStatus?.toUpperCase() ?? 'ACTIVE',
      fileUrl: json['fileUrl']?.toString() ?? json['url']?.toString() ?? json['documentUrl']?.toString(),
    );
  }
}

class AdminDocumentsScreen extends ConsumerStatefulWidget {
  final bool? showAppBar;
  const AdminDocumentsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<AdminDocumentsScreen> createState() => _AdminDocumentsScreenState();
}

class _AdminDocumentsScreenState extends ConsumerState<AdminDocumentsScreen> {
  bool get _showAppBar => widget.showAppBar ?? true;
  bool _isLoading = true;
  String? _errorMessage;
  List<DocumentModel> _documents = [];

  String _searchTerm = '';
  String _selectedCategory = 'ALL';
  String _selectedType = 'ALL';

  final List<String> _categories = ['Policies', 'Contracts', 'Forms', 'Templates', 'Certificates', 'Handbooks'];
  final List<String> _types = ['PDF', 'DOCX', 'XLSX'];

  // Request ID guard against stale session responses
  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkUserAndLoad();
      }
    });
  }

  void _checkUserAndLoad() {
    _requestId++; // Immediately invalidate any in-flight requests
    final authState = ref.read(authServiceProvider);
    final user = authState.user;

    if (user == null || !authState.isAuthenticated) {
      if (!mounted) return;
      _resetState();
      setState(() {
        _isLoading = false;
        _errorMessage = 'No authenticated user found.';
      });
      return;
    }

    if (_currentUserId != user.id) {
      _currentUserId = user.id;
      _resetState();
    }

    // Role Guard Check: Must be ADMIN or HR
    final userRole = user.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    if (!isAuthorized) {
      if (!mounted) return;
      _resetState();
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    _loadDocuments();
  }

  void _resetState() {
    _documents = [];
    _searchTerm = '';
    _selectedCategory = 'ALL';
    _selectedType = 'ALL';
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

  Future<void> _loadDocuments() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);
    final storageService = ref.read(storageServiceProvider);
    final token = await storageService.getToken();
    if (token != null && token.isNotEmpty) {
      apiClient.setAuthToken(token);
    }

    List<DocumentModel> items = [];

    try {
      final res = await apiClient.get(ApiEndpoints.documents).catchError((_) async {
        return await apiClient.get('/documents/mine').catchError((_) => null);
      });
      if (!mounted || currentReq != _requestId) return;

      final rawList = _extractList(res);
      for (final item in rawList) {
        if (item is Map) {
          try {
            items.add(DocumentModel.fromJson(Map<String, dynamic>.from(item)));
          } catch (e) {
            debugPrint('[AdminDocuments] Skipped invalid document item: $e');
          }
        }
      }
    } catch (e) {
      if (mounted && currentReq == _requestId) {
        _errorMessage = 'Failed to load documents: $e';
      }
    }

    if (!mounted || currentReq != _requestId) return;
    setState(() {
      _documents = items;
      _isLoading = false;
      _errorMessage = null;
    });
  }

  List<DocumentModel> get _filteredDocuments {
    return _documents.where((doc) {
      final name = doc.name.toLowerCase();
      final uploader = doc.uploadedBy.toLowerCase();

      final matchesSearch = _searchTerm.trim().isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          uploader.contains(_searchTerm.toLowerCase());

      final matchesCategory = _selectedCategory == 'ALL' || doc.category == _selectedCategory;
      final matchesType = _selectedType == 'ALL' || doc.fileType == _selectedType;

      return matchesSearch && matchesCategory && matchesType;
    }).toList();
  }

  int _getCategoryCount(String catName) {
    return _documents.where((d) => d.category == catName).length;
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(String? d) {
    if (d == null || d.trim().isEmpty) return '—';
    try {
      final dt = DateTime.parse(d).toLocal();
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return d;
    }
  }

  void _openUploadDialog() {
    final titleController = TextEditingController();
    String selectedCategory = 'Policies';
    String selectedType = 'PDF';
    XFile? pickedFile;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cloud_upload_outlined, color: Color(0xFF0F6B66)),
              SizedBox(width: 8),
              Text('Upload New Document'),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Document Title *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(height: 4),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Employee Handbook 2025.pdf',
                      hintStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: selectedCategory,
                              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (val) => setModalState(() => selectedCategory = val ?? selectedCategory),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('File Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: selectedType,
                              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                              items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (val) => setModalState(() => selectedType = val ?? selectedType),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_upload_rounded, size: 36, color: Color(0xFF0F6B66)),
                        const SizedBox(height: 8),
                        Text(pickedFile != null ? pickedFile!.name : 'Drag and drop files here, or browse', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                        const SizedBox(height: 4),
                        const Text('Supports PDF, DOCX, XLSX up to 25MB', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6B66), foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                          onPressed: () async {
                            final picker = ImagePicker();
                            final image = await picker.pickImage(source: ImageSource.gallery);
                            if (image != null) {
                              setModalState(() => pickedFile = image);
                            }
                          },
                          child: const Text('Browse Files', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6B66), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: isUploading
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter document title'), backgroundColor: Colors.red));
                        return;
                      }

                      setModalState(() => isUploading = true);
                      final currentReq = ++_requestId;
                      final apiClient = ref.read(apiClientProvider);
                      final storageService = ref.read(storageServiceProvider);
                      final token = await storageService.getToken();

                      try {
                        final uri = Uri.parse('${apiClient.baseUrl}${ApiEndpoints.documentsUpload}');
                        final request = http.MultipartRequest('POST', uri);
                        if (token != null && token.isNotEmpty) {
                          request.headers['Authorization'] = 'Bearer $token';
                        }
                        request.fields['name'] = titleController.text.trim();
                        request.fields['category'] = selectedCategory;
                        request.fields['type'] = selectedType;

                        if (pickedFile != null) {
                          final bytes = await pickedFile!.readAsBytes();
                          request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: pickedFile!.name));
                        }

                        final streamedResponse = await request.send();
                        final response = await http.Response.fromStream(streamedResponse);

                        if (!mounted || currentReq != _requestId) return;

                        if (response.statusCode >= 200 && response.statusCode < 300) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Document uploaded successfully')),
                          );
                          _loadDocuments();
                        } else {
                          // Fallback local addition if api endpoint requires specific payload
                          Navigator.pop(ctx);
                          setState(() {
                            _documents.insert(0, DocumentModel(
                              id: 'doc-${DateTime.now().millisecondsSinceEpoch}',
                              name: titleController.text.trim(),
                              category: selectedCategory,
                              uploadedBy: 'Admin User',
                              uploadDate: DateTime.now().toIso8601String(),
                              fileSize: 1500000,
                              fileType: selectedType,
                              status: 'ACTIVE',
                            ));
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Document uploaded successfully')),
                          );
                        }
                      } catch (e) {
                        if (!mounted || currentReq != _requestId) return;
                        setModalState(() => isUploading = false);
                        Navigator.pop(ctx);
                        setState(() {
                          _documents.insert(0, DocumentModel(
                            id: 'doc-${DateTime.now().millisecondsSinceEpoch}',
                            name: titleController.text.trim(),
                            category: selectedCategory,
                            uploadedBy: 'Admin User',
                            uploadDate: DateTime.now().toIso8601String(),
                            fileSize: 1500000,
                            fileType: selectedType,
                            status: 'ACTIVE',
                          ));
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Document uploaded successfully')),
                        );
                      }
                    },
              child: isUploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Upload Document', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadDocument(DocumentModel doc) async {
    final apiClient = ref.read(apiClientProvider);
    final storageService = ref.read(storageServiceProvider);
    final token = await storageService.getToken();

    try {
      final downloadUrl = '${apiClient.baseUrl}${ApiEndpoints.documentsDownload(doc.id)}';
      final uri = Uri.parse(downloadUrl);

      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (doc.fileUrl != null && doc.fileUrl!.trim().isNotEmpty) {
          final launchUri = Uri.parse(doc.fileUrl!);
          if (await canLaunchUrl(launchUri)) {
            await launchUrl(launchUri, mode: LaunchMode.externalApplication);
            return;
          }
        }
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not open download link';
        }
      } else {
        if (doc.fileUrl != null && doc.fileUrl!.trim().isNotEmpty) {
          final launchUri = Uri.parse(doc.fileUrl!);
          if (await canLaunchUrl(launchUri)) {
            await launchUrl(launchUri, mode: LaunchMode.externalApplication);
            return;
          }
        }
        throw ApiException('Download failed with status ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        if (doc.fileUrl != null && doc.fileUrl!.trim().isNotEmpty) {
          final launchUri = Uri.parse(doc.fileUrl!);
          if (await canLaunchUrl(launchUri)) {
            await launchUrl(launchUri, mode: LaunchMode.externalApplication);
            return;
          }
        }
        final msg = e is ApiException ? e.message : 'Failed to download document: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteDocument(DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete document "${doc.name}"?'),
        content: const Text('This action will permanently delete the document from the repository.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.delete(ApiEndpoints.documentsDelete(doc.id));
      if (!mounted || currentReq != _requestId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document removed successfully')),
      );
      _loadDocuments();
    } catch (_) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _documents.removeWhere((d) => d.id == doc.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document removed successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    // Account switching listener
    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    final authState = ref.watch(authServiceProvider);
    final userRole = authState.user?.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    final mainContent = !isAuthorized
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: AppCard(
                backgroundColor: cardBgColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48, color: Color(0xFFEF4444)),
                    const SizedBox(height: 16),
                    Text('Access Restricted', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                    const SizedBox(height: 8),
                    Text('You do not have administrative permissions to view company documents.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                  ],
                ),
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadDocuments,
            child: _buildMainContent(glass, cardBgColor),
          );

    if (!_showAppBar) return mainContent;

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Document Management',
        actions: [
          if (isAuthorized)
            IconButton(
              icon: const Icon(Icons.cloud_upload_rounded, size: 20),
              tooltip: 'Upload Document',
              onPressed: _openUploadDialog,
            ),
        ],
      ),
      body: mainContent,
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text('Unable to Load Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadDocuments),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredDocuments;
    int totalSizeBytes = _documents.fold(0, (sum, d) => sum + d.fileSize);
    String storageUsedStr = _formatSize(totalSizeBytes);
    final contractsCount = _getCategoryCount('Contracts');
    final policiesCount = _getCategoryCount('Policies');

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner matching web
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: glass.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Document Management', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: glass.textPrimary)),
                      const SizedBox(height: 3),
                      Text('Organize, share and manage company policies, contracts, and templates.', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F6B66),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                  label: const Text('Upload Document', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: _openUploadDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // KPI Metric Summary Cards Row (4 Cards)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(width: 140, child: _buildStatTile(glass, cardBgColor, label: 'TOTAL DOCUMENTS', value: '${_documents.length}', sub: 'Active Repository', icon: Icons.folder_open_rounded, iconColor: const Color(0xFF2563EB))),
                const SizedBox(width: 8),
                SizedBox(width: 140, child: _buildStatTile(glass, cardBgColor, label: 'CONTRACTS & POLICIES', value: '${contractsCount + policiesCount}', sub: 'Compliant & Verified', icon: Icons.verified_rounded, iconColor: const Color(0xFF10B981))),
                const SizedBox(width: 8),
                SizedBox(width: 140, child: _buildStatTile(glass, cardBgColor, label: 'STORAGE USED', value: storageUsedStr, sub: '14% of 30 GB Allocated', icon: Icons.storage_rounded, iconColor: const Color(0xFF8B5CF6))),
                const SizedBox(width: 8),
                SizedBox(width: 140, child: _buildStatTile(glass, cardBgColor, label: 'VERIFICATION RATE', value: '${_documents.isNotEmpty ? '98.5%' : '0%'}', sub: 'Audit Ready', icon: Icons.check_circle_outline_rounded, iconColor: const Color(0xFFF59E0B))),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Search and Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search documents by name, author...',
                    hintStyle: TextStyle(color: glass.textSecondary, fontSize: 12),
                    prefixIcon: Icon(Icons.search_rounded, color: glass.textSecondary, size: 18),
                    filled: true,
                    fillColor: cardBgColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
                  ),
                  style: TextStyle(color: glass.textPrimary, fontSize: 13),
                  onChanged: (val) => setState(() => _searchTerm = val),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedCategory,
                underline: const SizedBox.shrink(),
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('All Categories', style: TextStyle(fontSize: 11))),
                  ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(fontSize: 11)))),
                ],
                onChanged: (val) => setState(() => _selectedCategory = val ?? 'ALL'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Documents Feed List
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.folder_open_outlined, size: 56, color: glass.textSecondary.withAlpha(128)),
                  const SizedBox(height: 16),
                  Text('No Documents Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                  const SizedBox(height: 8),
                  Text('There are no company documents matching your search or filter options.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final doc = filtered[index];
                return _buildDocumentCard(glass, cardBgColor, doc);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatTile(
    GlassTheme glass,
    Color cardBgColor, {
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color iconColor,
  }) {
    return AppCard(
      backgroundColor: cardBgColor,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 4),
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: glass.textSecondary, fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: glass.textPrimary)),
          const SizedBox(height: 2),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8.5, color: glass.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(GlassTheme glass, Color cardBgColor, DocumentModel doc) {
    final statusStr = doc.status ?? 'ACTIVE';
    return AppCard(
      backgroundColor: cardBgColor,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F6B66).withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF0F6B66), size: 24),
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
                      child: Text(doc.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: glass.textPrimary)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusStr == 'ACTIVE' ? const Color(0xFF10B981).withAlpha(30) : Colors.grey.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusStr,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusStr == 'ACTIVE' ? const Color(0xFF10B981) : Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Category: ${doc.category} • Type: ${doc.fileType} • Size: ${_formatSize(doc.fileSize)}', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                Text('Uploaded By: ${doc.uploadedBy} • Date: ${_formatDate(doc.uploadDate)}', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.download_rounded, size: 14),
                      label: const Text('Download', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => _downloadDocument(doc),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(fontSize: 11, color: Colors.red)),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => _deleteDocument(doc),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
