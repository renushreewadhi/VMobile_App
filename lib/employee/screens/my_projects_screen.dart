import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import '../../core/widgets/glass_scaffold.dart';

class ProjectItem {
  final String id;
  final String name;
  final String? projectCode;
  final String? description;
  final String? departmentName;
  final String? teamLeadName;
  final String status; // 'IN_PROGRESS' | 'ON_HOLD' | 'NOT_STARTED' | 'COMPLETED' | 'CANCELLED'
  final String? startDate;
  final String? endDate;
  final int memberCount;
  final int completedMemberCount;

  ProjectItem({
    required this.id,
    required this.name,
    this.projectCode,
    this.description,
    this.departmentName,
    this.teamLeadName,
    required this.status,
    this.startDate,
    this.endDate,
    required this.memberCount,
    required this.completedMemberCount,
  });

  factory ProjectItem.fromJson(Map<String, dynamic> json) {
    return ProjectItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Project',
      projectCode: json['projectCode']?.toString(),
      description: json['description']?.toString(),
      departmentName: json['departmentName']?.toString() ?? json['department']?.toString(),
      teamLeadName: json['teamLeadName']?.toString() ?? json['leadName']?.toString(),
      status: (json['status'] ?? 'IN_PROGRESS').toString().toUpperCase(),
      startDate: json['startDate']?.toString(),
      endDate: json['endDate']?.toString(),
      memberCount: int.tryParse(json['memberCount']?.toString() ?? '0') ?? 0,
      completedMemberCount: int.tryParse(json['completedMemberCount']?.toString() ?? '0') ?? 0,
    );
  }

  int get progressPercent {
    if (memberCount <= 0) return 0;
    final pct = ((completedMemberCount / memberCount) * 100).round();
    return pct.clamp(0, 100);
  }

  String get leadInitial {
    if (teamLeadName == null || teamLeadName!.trim().isEmpty) return 'T';
    return teamLeadName!.trim()[0].toUpperCase();
  }
}

class MyProjectsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const MyProjectsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<MyProjectsScreen> createState() => _MyProjectsScreenState();
}

class _MyProjectsScreenState extends ConsumerState<MyProjectsScreen> {
  bool _isLoading = true;
  String? _error;
  List<ProjectItem> _projects = <ProjectItem>[];
  String _searchQuery = '';
  String _selectedStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.myProjects);
      if (!mounted) return;

      final rawList = res is List
          ? res
          : (res is Map<String, dynamic> && res['data'] is List ? res['data'] as List : []);

      final items = <ProjectItem>[];
      for (final item in rawList) {
        if (item is Map) {
          items.add(ProjectItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }

      setState(() {
        _projects = List<ProjectItem>.from(items);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _projects = <ProjectItem>[];
          _isLoading = false;
          _error = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
        });
      }
    }
  }

  List<ProjectItem> get _filteredProjects {
    return _projects.where((p) {
      if (_selectedStatus != 'ALL' && p.status != _selectedStatus) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchName = p.name.toLowerCase().contains(q);
        final matchCode = (p.projectCode ?? '').toLowerCase().contains(q);
        final matchDesc = (p.description ?? '').toLowerCase().contains(q);
        final matchDept = (p.departmentName ?? '').toLowerCase().contains(q);
        final matchLead = (p.teamLeadName ?? '').toLowerCase().contains(q);
        if (!matchName && !matchCode && !matchDesc && !matchDept && !matchLead) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      final skeleton = const ListSkeleton(itemCount: 3);
      if (!widget.showAppBar) return skeleton;
      return GlassScaffold(title: 'My Projects', body: skeleton);
    }

    final content = RefreshIndicator(
      onRefresh: _fetchProjects,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filter Box
            _buildFilterBox(isDark),
            const SizedBox(height: 16),

            // Error State / Projects Grid / List
            if (_error != null)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, size: 36, color: Colors.redAccent),
                      const SizedBox(height: 8),
                      Text('Failed to load projects', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                      const SizedBox(height: 4),
                      Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _fetchProjects,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_filteredProjects.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: const [
                      Icon(Icons.folder_open, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No projects found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 4),
                      Text(
                        'Your Team Lead has not assigned any projects matching your search filter.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredProjects.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  return _buildProjectCard(isDark, _filteredProjects[index]);
                },
              ),
          ],
        ),
      ),
    );

    if (!widget.showAppBar) return content;

    return GlassScaffold(
      title: 'My Projects',
      body: content,
    );
  }

  Widget _buildFilterBox(bool isDark) {
    return AppCard(
      child: Column(
        children: [
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
            decoration: InputDecoration(
              hintText: 'Search projects by name, code, department...',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => _searchQuery = ''))
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF1A2632) : AppColors.lightInputBackground,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _statusPill('All', 'ALL'),
                const SizedBox(width: 6),
                _statusPill('Active', 'IN_PROGRESS'),
                const SizedBox(width: 6),
                _statusPill('On Hold', 'ON_HOLD'),
                const SizedBox(width: 6),
                _statusPill('Not Started', 'NOT_STARTED'),
                const SizedBox(width: 6),
                _statusPill('Completed', 'COMPLETED'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String label, String value) {
    final isSelected = _selectedStatus == value;
    return Material(
      color: Colors.transparent,
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) setState(() => _selectedStatus = value);
        },
      ),
    );
  }

  Widget _buildProjectCard(bool isDark, ProjectItem p) {
    final formattedStart = _formatDate(p.startDate);
    final formattedEnd = _formatDate(p.endDate);
    final dateRange = formattedStart.isNotEmpty && formattedEnd.isNotEmpty
        ? '$formattedStart - $formattedEnd'
        : (formattedStart.isNotEmpty ? formattedStart : (formattedEnd.isNotEmpty ? formattedEnd : 'No Dates'));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  p.name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(status: p.status == 'IN_PROGRESS' ? 'ACTIVE' : p.status),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            p.departmentName ?? 'General Project',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 6),
          Text(
            p.description ?? 'No description provided for this project.',
            style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const Divider(height: 20),

          // Meta Row: Lead & Dates
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: Text(
                      p.leadInitial,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    p.teamLeadName ?? 'Team Lead',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                  const SizedBox(width: 4),
                  Text(
                    dateRange,
                    style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Chips Row: Reports & Members
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${p.completedMemberCount} Reports', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.people, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('${p.memberCount} Members', style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Team Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Team progress',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                  ),
                  Text(
                    '${p.progressPercent}% (${p.completedMemberCount}/${p.memberCount} done)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: p.memberCount > 0 ? (p.completedMemberCount / p.memberCount).clamp(0.0, 1.0) : 0.0,
                  backgroundColor: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                  color: AppColors.primary,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
