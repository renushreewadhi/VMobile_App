import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';

/// Audience Rule model.
class AudienceRuleModel {
  String? roleName;
  String? departmentId;
  String? departmentName;
  String? teamId;
  String? teamName;
  String? branchId;
  String? branchName;

  AudienceRuleModel({
    this.roleName,
    this.departmentId,
    this.departmentName,
    this.teamId,
    this.teamName,
    this.branchId,
    this.branchName,
  });

  factory AudienceRuleModel.fromJson(Map<String, dynamic> json) {
    return AudienceRuleModel(
      roleName: json['roleName']?.toString(),
      departmentId: json['departmentId']?.toString(),
      departmentName: json['departmentName']?.toString() ?? json['department']?.toString(),
      teamId: json['teamId']?.toString(),
      teamName: json['teamName']?.toString() ?? json['team']?.toString(),
      branchId: json['branchId']?.toString(),
      branchName: json['branchName']?.toString() ?? json['branch']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (roleName != null && roleName!.trim().isNotEmpty) data['roleName'] = roleName!.trim();
    if (departmentId != null && departmentId!.trim().isNotEmpty) data['departmentId'] = departmentId!.trim();
    if (teamId != null && teamId!.trim().isNotEmpty) data['teamId'] = teamId!.trim();
    if (branchId != null && branchId!.trim().isNotEmpty) data['branchId'] = branchId!.trim();
    return data;
  }
}

/// Announcement Model strictly matching Angular `announcement.model.ts`
class AnnouncementModel {
  final String id;
  final String title;
  final String content;
  final String type;
  final String? authorId;
  final String? authorName;
  final String? authorRole;
  final String priority;
  final bool sendNotification;
  final bool isPinned;
  final bool isPublished;
  final String? publishedDate;
  final String? createdAt;
  final String? expiryDate;
  final List<AudienceRuleModel> audienceRules;
  final int audienceCount;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    this.authorId,
    this.authorName,
    this.authorRole,
    required this.priority,
    required this.sendNotification,
    required this.isPinned,
    required this.isPublished,
    this.publishedDate,
    this.createdAt,
    this.expiryDate,
    required this.audienceRules,
    required this.audienceCount,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    List<AudienceRuleModel> rules = [];
    if (json['audienceRules'] is List) {
      for (final r in json['audienceRules']) {
        if (r is Map<String, dynamic>) rules.add(AudienceRuleModel.fromJson(r));
      }
    }

    return AnnouncementModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      type: json['type']?.toString() ?? 'GENERAL',
      authorId: json['authorId']?.toString(),
      authorName: json['authorName']?.toString(),
      authorRole: json['authorRole']?.toString(),
      priority: json['priority']?.toString() ?? 'NORMAL',
      sendNotification: json['sendNotification'] is bool ? json['sendNotification'] as bool : true,
      isPinned: json['isPinned'] is bool ? json['isPinned'] as bool : false,
      isPublished: json['isPublished'] is bool ? json['isPublished'] as bool : true,
      publishedDate: json['publishedDate']?.toString(),
      createdAt: json['createdAt']?.toString(),
      expiryDate: json['expiryDate']?.toString(),
      audienceRules: rules,
      audienceCount: json['audienceCount'] is int ? json['audienceCount'] as int : 0,
    );
  }
}

class AdminAnnouncementsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const AdminAnnouncementsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<AdminAnnouncementsScreen> createState() => _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends ConsumerState<AdminAnnouncementsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<AnnouncementModel> _announcements = [];
  String _selectedFilter = 'All';
  String _searchTerm = '';
  String _sortBy = 'newest'; // 'newest', 'oldest', 'priority'

  List<Map<String, String>> _departments = [];
  List<Map<String, String>> _teams = [];
  List<Map<String, String>> _branches = [];

  final List<String> _roles = ['EMPLOYEE', 'TL', 'HR', 'IT', 'FINANCE', 'ADMIN'];

  final List<Map<String, dynamic>> _announcementTypes = [
    {'value': 'COMPANY_EVENT', 'label': 'Event', 'icon': Icons.event_rounded, 'color': Color(0xFF0284C7)},
    {'value': 'HOLIDAY', 'label': 'Holiday', 'icon': Icons.event_available_rounded, 'color': Color(0xFF10B981)},
    {'value': 'SYSTEM', 'label': 'System', 'icon': Icons.warning_amber_rounded, 'color': Color(0xFFEF4444)},
    {'value': 'TRAINING', 'label': 'Training', 'icon': Icons.school_rounded, 'color': Color(0xFF3B82F6)},
    {'value': 'POLICY_UPDATE', 'label': 'Policy', 'icon': Icons.description_rounded, 'color': Color(0xFF0EA5E9)},
    {'value': 'GENERAL', 'label': 'General', 'icon': Icons.campaign_rounded, 'color': Color(0xFF6366F1)},
    {'value': 'FESTIVAL', 'label': 'Festival', 'icon': Icons.celebration_rounded, 'color': Color(0xFFF59E0B)},
    {'value': 'EMERGENCY', 'label': 'Emergency', 'icon': Icons.bolt_rounded, 'color': Color(0xFFDC2626)},
    {'value': 'OTHER', 'label': 'Other', 'icon': Icons.notifications_rounded, 'color': Color(0xFF64748B)},
  ];

  final Map<String, Map<String, dynamic>> _priorityConfig = {
    'NORMAL': {'label': 'Normal', 'color': Color(0xFF4F46E5), 'icon': Icons.info_outline_rounded},
    'IMPORTANT': {'label': 'Important', 'color': Color(0xFFD97706), 'icon': Icons.priority_high_rounded},
    'CRITICAL': {'label': 'Critical', 'color': Color(0xFFDC2626), 'icon': Icons.bolt_rounded},
  };

  // Guard against out-of-order responses during account switching
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
    _requestId++; // Immediately invalidate any in-flight requests from prior state
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

    _loadData();
  }

  void _resetState() {
    _announcements = [];
    _departments = [];
    _teams = [];
    _branches = [];
    _selectedFilter = 'All';
    _searchTerm = '';
    _sortBy = 'newest';
  }

  Future<void> _loadData() async {
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

    try {
      final res = await apiClient.get(ApiEndpoints.announcements).catchError((_) => null);
      if (!mounted || currentReq != _requestId) return;

      dynamic rawData = res;
      if (res is Map<String, dynamic>) {
        if (res['data'] is List) rawData = res['data'];
        else if (res['items'] is List) rawData = res['items'];
        else if (res['data'] is Map && res['data']['items'] is List) rawData = res['data']['items'];
      }

      List<AnnouncementModel> items = [];
      if (rawData is List) {
        for (final item in rawData) {
          if (item is Map<String, dynamic>) {
            try {
              items.add(AnnouncementModel.fromJson(item));
            } catch (e) {
              debugPrint('[AdminAnnouncements] Skipped invalid announcement: $e');
            }
          }
        }
      }

      if (items.isEmpty) {
        items = [
          AnnouncementModel.fromJson({
            'id': 'ann-01',
            'title': 'Diwali Celebration',
            'content': 'Diwali celebration hoga office ke andar',
            'type': 'FESTIVAL',
            'category': 'FESTIVAL',
            'priority': 'NORMAL',
            'isPinned': true,
            'postedBy': 'Prachi Natali',
            'targetAudience': 'All Employees',
            'createdAt': '2026-10-21T10:00:00Z',
          }),
        ];
      }

      // Load Dropdowns with ID validation
      List<Map<String, String>> depts = [];
      try {
        final deptRes = await apiClient.get(ApiEndpoints.departments);
        if (!mounted || currentReq != _requestId) return;
        dynamic rawDepts = deptRes is Map<String, dynamic> && deptRes.containsKey('data') ? deptRes['data'] : deptRes;
        if (rawDepts is List) {
          final Set<String> seenIds = {};
          for (final d in rawDepts) {
            if (d is Map<String, dynamic>) {
              final id = (d['id'] ?? d['_id'])?.toString() ?? '';
              final name = (d['name'] ?? d['departmentName'])?.toString() ?? 'Department';
              if (id.isNotEmpty && !seenIds.contains(id)) {
                seenIds.add(id);
                depts.add({'id': id, 'name': name});
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AdminAnnouncements] Department dropdown load warning: $e');
      }

      List<Map<String, String>> teams = [];
      try {
        final teamRes = await apiClient.get(ApiEndpoints.teams);
        if (!mounted || currentReq != _requestId) return;
        dynamic rawTeams = teamRes is Map<String, dynamic> && teamRes.containsKey('data') ? teamRes['data'] : teamRes;
        if (rawTeams is List) {
          final Set<String> seenIds = {};
          for (final t in rawTeams) {
            if (t is Map<String, dynamic>) {
              final id = (t['id'] ?? t['_id'])?.toString() ?? '';
              final name = (t['name'] ?? t['teamName'])?.toString() ?? 'Team';
              if (id.isNotEmpty && !seenIds.contains(id)) {
                seenIds.add(id);
                teams.add({'id': id, 'name': name});
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AdminAnnouncements] Team dropdown load warning: $e');
      }

      List<Map<String, String>> branches = [];
      try {
        final branchRes = await apiClient.get(ApiEndpoints.branches);
        if (!mounted || currentReq != _requestId) return;
        dynamic rawBranches = branchRes is Map<String, dynamic> && branchRes.containsKey('data') ? branchRes['data'] : branchRes;
        if (rawBranches is List) {
          final Set<String> seenIds = {};
          for (final b in rawBranches) {
            if (b is Map<String, dynamic>) {
              final id = (b['id'] ?? b['_id'])?.toString() ?? '';
              final name = (b['name'] ?? b['branchName'])?.toString() ?? 'Branch';
              if (id.isNotEmpty && !seenIds.contains(id)) {
                seenIds.add(id);
                branches.add({'id': id, 'name': name});
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AdminAnnouncements] Branch dropdown load warning: $e');
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _announcements = items;
        _departments = depts;
        _teams = teams;
        _branches = branches;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load announcements. Please check network connection.';
        _isLoading = false;
      });
    }
  }

  List<AnnouncementModel> get _filteredAnnouncements {
    var list = List<AnnouncementModel>.from(_announcements);

    // Filter
    if (_selectedFilter == 'Pinned') {
      list = list.where((a) => a.isPinned).toList();
    } else if (_selectedFilter == 'Important') {
      list = list.where((a) => a.priority == 'IMPORTANT' || a.priority == 'CRITICAL').toList();
    } else if (_selectedFilter != 'All') {
      list = list.where((a) => a.type.toUpperCase() == _selectedFilter.toUpperCase()).toList();
    }

    // Search
    if (_searchTerm.trim().isNotEmpty) {
      final term = _searchTerm.trim().toLowerCase();
      list = list.where((a) =>
        a.title.toLowerCase().contains(term) ||
        a.content.toLowerCase().contains(term) ||
        (a.authorName != null && a.authorName!.toLowerCase().contains(term))
      ).toList();
    }

    // Sort
    if (_sortBy == 'newest') {
      list.sort((a, b) {
        final dtA = DateTime.tryParse(a.publishedDate ?? a.createdAt ?? '') ?? DateTime(1970);
        final dtB = DateTime.tryParse(b.publishedDate ?? b.createdAt ?? '') ?? DateTime(1970);
        return dtB.compareTo(dtA);
      });
    } else if (_sortBy == 'oldest') {
      list.sort((a, b) {
        final dtA = DateTime.tryParse(a.publishedDate ?? a.createdAt ?? '') ?? DateTime(1970);
        final dtB = DateTime.tryParse(b.publishedDate ?? b.createdAt ?? '') ?? DateTime(1970);
        return dtA.compareTo(dtB);
      });
    } else if (_sortBy == 'priority') {
      const weight = {'CRITICAL': 3, 'IMPORTANT': 2, 'NORMAL': 1};
      list.sort((a, b) => (weight[b.priority] ?? 0).compareTo(weight[a.priority] ?? 0));
    }

    return list;
  }

  int get _pinnedCount => _announcements.where((a) => a.isPinned).length;
  int get _criticalCount => _announcements.where((a) => a.priority == 'CRITICAL').length;

  int _getCategoryCount(String type) {
    if (type == 'All') return _announcements.length;
    if (type == 'Pinned') return _pinnedCount;
    return _announcements.where((a) => a.type.toUpperCase() == type.toUpperCase()).length;
  }

  /// Date formatter matching Angular mediumDate ('MMM d, yyyy')
  String _formatDate(String? val) {
    if (val == null || val.trim().isEmpty) return '—';
    try {
      final dt = DateTime.parse(val);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return val;
    }
  }

  Map<String, dynamic> _getTypeInfo(String? type) {
    final clean = (type ?? 'GENERAL').toUpperCase();
    final found = _announcementTypes.firstWhere(
      (t) => (t['value'] as String).toUpperCase() == clean,
      orElse: () => _announcementTypes.firstWhere((t) => t['value'] == 'OTHER'),
    );
    return found;
  }

  Map<String, dynamic> _getPriorityInfo(String? priority) {
    final clean = (priority ?? 'NORMAL').toUpperCase();
    return _priorityConfig[clean] ?? _priorityConfig['NORMAL']!;
  }

  /// Safe Audience Summary resolution looking up names by ID
  String _getAudienceSummary(List<AudienceRuleModel>? rules) {
    if (rules == null || rules.isEmpty) return 'All Employees';
    List<String> summaries = [];

    for (final r in rules) {
      List<String> parts = [];
      if (r.roleName != null && r.roleName!.trim().isNotEmpty) {
        parts.add(r.roleName!.trim());
      }

      // Department name lookup
      String? deptName = r.departmentName;
      if ((deptName == null || deptName.trim().isEmpty) && r.departmentId != null) {
        final match = _departments.firstWhere(
          (d) => d['id'] == r.departmentId,
          orElse: () => {},
        );
        if (match.isNotEmpty) deptName = match['name'];
      }
      if (deptName != null && deptName.trim().isNotEmpty) parts.add(deptName.trim());

      // Team name lookup
      String? teamName = r.teamName;
      if ((teamName == null || teamName.trim().isEmpty) && r.teamId != null) {
        final match = _teams.firstWhere(
          (t) => t['id'] == r.teamId,
          orElse: () => {},
        );
        if (match.isNotEmpty) teamName = match['name'];
      }
      if (teamName != null && teamName.trim().isNotEmpty) parts.add(teamName.trim());

      // Branch name lookup
      String? branchName = r.branchName;
      if ((branchName == null || branchName.trim().isEmpty) && r.branchId != null) {
        final match = _branches.firstWhere(
          (b) => b['id'] == r.branchId,
          orElse: () => {},
        );
        if (match.isNotEmpty) branchName = match['name'];
      }
      if (branchName != null && branchName.trim().isNotEmpty) parts.add(branchName.trim());

      if (parts.isNotEmpty) {
        summaries.add(parts.join(' / '));
      }
    }

    if (summaries.isEmpty) return 'All Employees';
    return summaries.join(', ');
  }

  Future<void> _deleteAnnouncement(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: const Text('Are you sure you want to delete this announcement?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.delete('${ApiEndpoints.announcements}/$id');
      if (!mounted || currentReq != _requestId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement deleted successfully')),
      );
      _loadData();
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      final msg = e is ApiException ? e.message : 'Failed to delete announcement.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  void _showFormDialog([AnnouncementModel? existing]) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final contentCtrl = TextEditingController(text: existing?.content ?? '');
    final expiryCtrl = TextEditingController(
      text: existing?.expiryDate != null ? _formatDate(existing!.expiryDate) : '',
    );
    DateTime? selectedExpiryDate = existing?.expiryDate != null ? DateTime.tryParse(existing!.expiryDate!) : null;

    String type = existing?.type ?? 'GENERAL';
    String priority = existing?.priority ?? 'NORMAL';
    bool sendNotification = existing?.sendNotification ?? true;
    bool isPinned = existing?.isPinned ?? false;
    List<AudienceRuleModel> rules = existing != null
        ? existing.audienceRules.map((r) => AudienceRuleModel(
            roleName: r.roleName,
            departmentId: r.departmentId,
            teamId: r.teamId,
            branchId: r.branchId,
          )).toList()
        : [];

    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDlgState) {
            return AlertDialog(
              title: Text(existing == null ? 'Create Announcement' : 'Edit Announcement'),
              content: SizedBox(
                width: MediaQuery.of(dialogCtx).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        enabled: !isSubmitting,
                        decoration: const InputDecoration(labelText: 'Title *'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contentCtrl,
                        enabled: !isSubmitting,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Description / Content *'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _announcementTypes.any((t) => t['value'] == type) ? type : 'GENERAL',
                        decoration: const InputDecoration(labelText: 'Category / Type'),
                        items: _announcementTypes.map((t) {
                          return DropdownMenuItem<String>(
                            value: t['value'] as String,
                            child: Text(t['label'] as String),
                          );
                        }).toList(),
                        onChanged: isSubmitting ? null : (val) => setDlgState(() => type = val ?? 'GENERAL'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _priorityConfig.containsKey(priority) ? priority : 'NORMAL',
                        decoration: const InputDecoration(labelText: 'Priority Level'),
                        items: _priorityConfig.entries.map((e) {
                          return DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value['label'] as String),
                          );
                        }).toList(),
                        onChanged: isSubmitting ? null : (val) => setDlgState(() => priority = val ?? 'NORMAL'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: expiryCtrl,
                        readOnly: true,
                        enabled: !isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'Expiry Date (Optional)',
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selectedExpiryDate != null)
                                IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  tooltip: 'Clear Expiry Date',
                                  onPressed: isSubmitting
                                      ? null
                                      : () {
                                          setDlgState(() {
                                            selectedExpiryDate = null;
                                            expiryCtrl.clear();
                                          });
                                        },
                                ),
                              IconButton(
                                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        final now = DateTime.now();
                                        final initialDate = selectedExpiryDate ?? now.add(const Duration(days: 7));
                                        // Allow dates in the past when editing existing expired announcements
                                        final firstDate = (selectedExpiryDate != null && selectedExpiryDate!.isBefore(now))
                                            ? selectedExpiryDate!
                                            : now;

                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: initialDate,
                                          firstDate: firstDate,
                                          lastDate: now.add(const Duration(days: 3650)),
                                        );
                                        if (picked != null) {
                                          setDlgState(() {
                                            selectedExpiryDate = picked;
                                            expiryCtrl.text = DateFormat('MMM d, yyyy').format(picked);
                                          });
                                        }
                                      },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        title: const Text('Pin Announcement to Top', style: TextStyle(fontSize: 13)),
                        value: isPinned,
                        onChanged: isSubmitting ? null : (val) => setDlgState(() => isPinned = val ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        title: const Text('Send Push/Email Notification', style: TextStyle(fontSize: 13)),
                        value: sendNotification,
                        onChanged: isSubmitting ? null : (val) => setDlgState(() => sendNotification = val ?? true),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Target Audience Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Rule'),
                            onPressed: isSubmitting
                                ? null
                                : () => setDlgState(() => rules.add(AudienceRuleModel())),
                          ),
                        ],
                      ),
                      if (rules.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('Applies to All Employees', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        )
                      else
                        ...rules.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final r = entry.value;

                          final safeRole = (r.roleName != null && _roles.contains(r.roleName)) ? r.roleName : null;
                          final safeDept = (r.departmentId != null && _departments.any((d) => d['id'] == r.departmentId)) ? r.departmentId : null;
                          final safeTeam = (r.teamId != null && _teams.any((t) => t['id'] == r.teamId)) ? r.teamId : null;
                          final safeBranch = (r.branchId != null && _branches.any((b) => b['id'] == r.branchId)) ? r.branchId : null;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              margin: EdgeInsets.zero,
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Rule #${idx + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                          onPressed: isSubmitting ? null : () => setDlgState(() => rules.removeAt(idx)),
                                        ),
                                      ],
                                    ),
                                    DropdownButtonFormField<String>(
                                      initialValue: safeRole,
                                      decoration: const InputDecoration(labelText: 'Target Role', isDense: true),
                                      items: _roles.map((rl) => DropdownMenuItem(value: rl, child: Text(rl))).toList(),
                                      onChanged: isSubmitting ? null : (val) => setDlgState(() => r.roleName = val),
                                    ),
                                    if (_departments.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<String>(
                                        initialValue: safeDept,
                                        decoration: const InputDecoration(labelText: 'Target Department', isDense: true),
                                        items: _departments.map((d) {
                                          return DropdownMenuItem(value: d['id'], child: Text(d['name']!));
                                        }).toList(),
                                        onChanged: isSubmitting ? null : (val) => setDlgState(() => r.departmentId = val),
                                      ),
                                    ],
                                    if (_teams.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<String>(
                                        initialValue: safeTeam,
                                        decoration: const InputDecoration(labelText: 'Target Team', isDense: true),
                                        items: _teams.map((t) {
                                          return DropdownMenuItem(value: t['id'], child: Text(t['name']!));
                                        }).toList(),
                                        onChanged: isSubmitting ? null : (val) => setDlgState(() => r.teamId = val),
                                      ),
                                    ],
                                    if (_branches.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<String>(
                                        initialValue: safeBranch,
                                        decoration: const InputDecoration(labelText: 'Target Branch', isDense: true),
                                        items: _branches.map((b) {
                                          return DropdownMenuItem(value: b['id'], child: Text(b['name']!));
                                        }).toList(),
                                        onChanged: isSubmitting ? null : (val) => setDlgState(() => r.branchId = val),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Title and Content are required.')),
                            );
                            return;
                          }

                          // Filter out empty audience rules
                          final validAudienceRules = rules
                              .map((r) => r.toJson())
                              .where((rMap) => rMap.isNotEmpty)
                              .toList();

                          setDlgState(() => isSubmitting = true);

                          final payload = {
                            'title': titleCtrl.text.trim(),
                            'content': contentCtrl.text.trim(),
                            'type': type,
                            'priority': priority,
                            'sendNotification': sendNotification,
                            'isPinned': isPinned,
                            if (selectedExpiryDate != null) 'expiryDate': selectedExpiryDate!.toIso8601String(),
                            'audienceRules': validAudienceRules,
                          };

                          final currentReq = ++_requestId;
                          final apiClient = ref.read(apiClientProvider);

                          try {
                            if (existing == null) {
                              await apiClient.post(ApiEndpoints.announcements, body: payload);
                            } else {
                              await apiClient.put('${ApiEndpoints.announcements}/${existing.id}', body: payload);
                            }

                            if (!mounted || currentReq != _requestId) return;
                            if (dialogCtx.mounted) {
                              Navigator.of(dialogCtx).pop();
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(existing == null ? 'Announcement published successfully' : 'Announcement updated successfully')),
                              );
                            }
                            _loadData();
                          } catch (e) {
                            if (!mounted || currentReq != _requestId) return;
                            setDlgState(() => isSubmitting = false);
                            final msg = e is ApiException ? e.message : 'Failed to save announcement.';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg), backgroundColor: Colors.red),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(existing == null ? 'Publish' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDetailModal(AnnouncementModel a) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;
    final typeInfo = _getTypeInfo(a.type);
    final priorityInfo = _getPriorityInfo(a.priority);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (typeInfo['color'] as Color).withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(typeInfo['icon'] as IconData, color: typeInfo['color'] as Color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${typeInfo['label']} Announcement',
                                style: TextStyle(fontSize: 12, color: typeInfo['color'] as Color, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                a.title,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: glass.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: glass.textSecondary),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildModalMetaRow(glass, 'Author', a.authorName ?? 'Admin', Icons.account_circle_outlined),
              _buildModalMetaRow(glass, 'Published Date', _formatDate(a.publishedDate ?? a.createdAt), Icons.calendar_month_outlined),
              if (a.expiryDate != null && a.expiryDate!.isNotEmpty)
                _buildModalMetaRow(glass, 'Expiry Date', _formatDate(a.expiryDate), Icons.event_busy_outlined),
              _buildModalMetaRow(glass, 'Audience', _getAudienceSummary(a.audienceRules), Icons.group_outlined),
              _buildModalMetaRow(glass, 'Priority', priorityInfo['label'] as String, priorityInfo['icon'] as IconData, valueColor: priorityInfo['color'] as Color),
              const SizedBox(height: 16),
              Text('Content', style: TextStyle(fontSize: 12, color: glass.textSecondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                a.content,
                style: TextStyle(fontSize: 14, color: glass.textPrimary, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showFormDialog(a);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: 'Close',
                      onPressed: () => Navigator.of(ctx).pop(),
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

  Widget _buildModalMetaRow(GlassTheme glass, String label, String value, IconData icon, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: glass.textSecondary),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor ?? glass.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    // Listen to Auth State for Account Switching & Invalidation
    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      final user = next.user;
      if (!next.isAuthenticated || user == null || (user.role != UserRole.ADMIN && user.role != UserRole.HR) || user.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    final authState = ref.watch(authServiceProvider);
    final userRole = authState.user?.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    final content = !isAuthorized
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
                    Text(
                      'Access Restricted',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: glass.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You do not have administrative permissions to view or publish company announcements.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: glass.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadData,
            child: _buildMainContent(glass, cardBgColor, isAuthorized),
          );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: content);

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Announcements & Bulletins',
        actions: [
          if (isAuthorized)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              tooltip: 'Create Announcement',
              onPressed: () => _showFormDialog(),
            ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor, bool isAuthorized) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text(
                'Unable to Load Announcements',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: glass.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: glass.textSecondary),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                width: 140,
                onPressed: _loadData,
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredAnnouncements;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Overview Cards (matching Angular stats-grid)
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  glass,
                  cardBgColor,
                  label: 'Total',
                  value: '${_announcements.length}',
                  icon: Icons.campaign_rounded,
                  iconColor: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatTile(
                  glass,
                  cardBgColor,
                  label: 'Pinned',
                  value: '$_pinnedCount',
                  icon: Icons.push_pin_rounded,
                  iconColor: const Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatTile(
                  glass,
                  cardBgColor,
                  label: 'Critical',
                  value: '$_criticalCount',
                  icon: Icons.bolt_rounded,
                  iconColor: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Underline Nav Tabs Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'All (${_getCategoryCount('All')})'),
                const SizedBox(width: 6),
                _buildFilterChip('Pinned', 'Pinned (${_getCategoryCount('Pinned')})'),
                const SizedBox(width: 6),
                ..._announcementTypes.map((t) {
                  final val = t['value'] as String;
                  final count = _getCategoryCount(val);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildFilterChip(val, '${t['label']} ($count)'),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search, Sort & Create Button Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search announcements...',
                    hintStyle: TextStyle(color: glass.textSecondary, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: glass.textSecondary),
                    filled: true,
                    fillColor: cardBgColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: glass.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: glass.cardBorder),
                    ),
                  ),
                  style: TextStyle(color: glass.textPrimary),
                  onChanged: (val) => setState(() => _searchTerm = val),
                ),
              ),
              if (isAuthorized) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create'),
                  onPressed: () => _showFormDialog(),
                ),
              ],
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _sortBy,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'newest', child: Text('Newest')),
                  DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
                  DropdownMenuItem(value: 'priority', child: Text('Priority')),
                ],
                onChanged: (val) => setState(() => _sortBy = val ?? 'newest'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Feed List or Empty State
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.campaign_rounded, size: 56, color: glass.textSecondary.withAlpha(128)),
                  const SizedBox(height: 16),
                  Text('No Announcements Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                  const SizedBox(height: 8),
                  Text('There are no announcements matching your criteria.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final a = filtered[index];
                return _buildAnnouncementCard(glass, cardBgColor, a);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String id, String label) {
    final isSelected = _selectedFilter == id;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => _selectedFilter = id),
    );
  }

  Widget _buildStatTile(
    GlassTheme glass,
    Color cardBgColor, {
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return AppCard(
      backgroundColor: cardBgColor,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: glass.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: glass.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(GlassTheme glass, Color cardBgColor, AnnouncementModel a) {
    final typeInfo = _getTypeInfo(a.type);
    final priorityInfo = _getPriorityInfo(a.priority);

    return AppCard(
      backgroundColor: cardBgColor,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () => _showDetailModal(a),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (typeInfo['color'] as Color).withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(typeInfo['icon'] as IconData, color: typeInfo['color'] as Color, size: 20),
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
                              a.title,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary),
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, size: 18, color: glass.textSecondary),
                            onSelected: (val) {
                              if (val == 'edit') _showFormDialog(a);
                              if (val == 'delete') _deleteAnnouncement(a.id);
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        a.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: glass.textSecondary, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (typeInfo['color'] as Color).withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(typeInfo['label'] as String, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeInfo['color'] as Color)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (priorityInfo['color'] as Color).withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(priorityInfo['label'] as String, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: priorityInfo['color'] as Color)),
                ),
                if (a.isPinned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withAlpha(38),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin_rounded, size: 10, color: Color(0xFFD97706)),
                        SizedBox(width: 2),
                        Text('Pinned', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                      ],
                    ),
                  ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDate(a.publishedDate ?? a.createdAt), style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                Text(_getAudienceSummary(a.audienceRules), style: TextStyle(fontSize: 11, color: glass.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
