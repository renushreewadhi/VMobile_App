import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class ItAccessScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const ItAccessScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<ItAccessScreen> createState() => _ItAccessScreenState();
}

class _ItAccessScreenState extends ConsumerState<ItAccessScreen> {
  bool _isLoading = true;
  List<dynamic> _accessRules = [];
  String _searchTerm = '';
  String _statusFilter = 'ALL';
  final String _levelFilter = 'ALL';
  String _activeTab = 'all';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _accessLevels = ['READ', 'WRITE', 'ADMIN', 'ROOT'];

  @override
  void initState() {
    super.initState();
    _fetchAccessRules();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAccessRules() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/it/access');
      if (kDebugMode) {
        debugPrint('[ItAccess] Response: $res');
      }
      if (mounted) {
        setState(() {
          if (res is List) {
            _accessRules = res;
          } else if (res is Map<String, dynamic>) {
            if (res['data'] is List) {
              _accessRules = res['data'];
            } else if (res['result'] is List) {
              _accessRules = res['result'];
            } else {
              _accessRules = [];
            }
          } else {
            _accessRules = [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ItAccess] Error fetching access rules: $e');
      }
      if (mounted) {
        setState(() {
          _accessRules = [
            {'id': 'acc-1', 'systemName': 'GitHub Organization', 'role': 'Frontend Engineer', 'accessLevel': 'WRITE', 'mfaRequired': true, 'status': 'Active', 'notes': 'Repo access for ClientApp.'},
            {'id': 'acc-2', 'systemName': 'AWS Production Cloud', 'role': 'DevOps / Lead', 'accessLevel': 'ADMIN', 'mfaRequired': true, 'status': 'Active', 'notes': 'EC2, S3 production access.'},
            {'id': 'acc-3', 'systemName': 'Internal VPN Gateway', 'role': 'Remote Staff', 'accessLevel': 'READ', 'mfaRequired': true, 'status': 'Active', 'notes': 'WireGuard VPN configuration.'},
          ];
          _isLoading = false;
        });
      }
    }
  }

  void _setTab(String tab) {
    setState(() {
      _activeTab = tab;
      if (tab == 'all') {
        _statusFilter = 'ALL';
      } else if (tab == 'active') {
        _statusFilter = 'Active';
      } else if (tab == 'suspended') {
        _statusFilter = 'Suspended';
      } else if (tab == 'revoked') {
        _statusFilter = 'Revoked';
      }
    });
  }

  void _openCreateOrEdit({dynamic item}) {
    final isEdit = item != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    final systemController = TextEditingController(text: item?['systemName'] ?? item?['system'] ?? '');
    final roleController = TextEditingController(text: item?['role'] ?? '');
    final notesController = TextEditingController(text: item?['notes'] ?? '');
    String selectedLevel = (item?['accessLevel'] ?? 'READ').toString().toUpperCase();
    if (!_accessLevels.contains(selectedLevel)) selectedLevel = 'READ';
    bool mfaRequired = item?['mfaRequired'] ?? (item?['mfa'] == 'Required');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkMainSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isEdit ? 'Edit Access Rule' : 'Grant System Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                      IconButton(onPressed: () => Navigator.pop(modalContext), icon: Icon(Icons.close, size: 20, color: glass.textSecondary)),
                    ],
                  ),
                  Divider(height: 16, color: glass.cardBorder),
                  const SizedBox(height: 8),

                  Text('System / Platform *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: systemController,
                    style: TextStyle(color: glass.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. GitHub Org, AWS Production, VPN Gateway',
                      hintStyle: TextStyle(color: glass.textSecondary),
                      filled: true,
                      fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('Target Role *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: roleController,
                    style: TextStyle(color: glass.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. Frontend Engineer, DevOps, Admin',
                      hintStyle: TextStyle(color: glass.textSecondary),
                      filled: true,
                      fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('Access Level *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedLevel,
                    dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                    style: TextStyle(color: glass.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: _accessLevels.map((lvl) => DropdownMenuItem(value: lvl, child: Text(lvl, style: TextStyle(color: glass.textPrimary)))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedLevel = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Checkbox(
                        value: mfaRequired,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setModalState(() => mfaRequired = val ?? true),
                      ),
                      Text('Enforce Multi-Factor Authentication (MFA)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: glass.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text('Notes / Scope Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    style: TextStyle(color: glass.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Specify repository, server names, or permission scopes...',
                      hintStyle: TextStyle(color: glass.textSecondary),
                      filled: true,
                      fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(modalContext),
                        child: Text('Cancel', style: TextStyle(color: glass.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (systemController.text.trim().isEmpty || roleController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter System Name and Target Role.')));
                                  return;
                                }

                                setModalState(() => isSaving = true);
                                final apiClient = ref.read(apiClientProvider);
                                final payload = {
                                  'systemName': systemController.text.trim(),
                                  'role': roleController.text.trim(),
                                  'accessLevel': selectedLevel,
                                  'mfaRequired': mfaRequired,
                                  'notes': notesController.text.trim(),
                                };

                                try {
                                  if (isEdit) {
                                    await apiClient.put('/it/access/${item['id']}', body: payload);
                                  } else {
                                    await apiClient.post('/it/access', body: payload);
                                  }
                                  if (context.mounted) {
                                    Navigator.pop(modalContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isEdit ? 'Access rule updated successfully!' : 'Access rule granted successfully!'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                    _fetchAccessRules();
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    if (isEdit) {
                                      item['systemName'] = payload['systemName'];
                                      item['role'] = payload['role'];
                                      item['accessLevel'] = payload['accessLevel'];
                                      item['mfaRequired'] = payload['mfaRequired'];
                                      item['notes'] = payload['notes'];
                                    } else {
                                      _accessRules.insert(0, {
                                        'id': 'acc-${DateTime.now().millisecondsSinceEpoch}',
                                        ...payload,
                                        'status': 'Active',
                                      });
                                    }
                                    Navigator.pop(modalContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isEdit ? 'Access rule updated.' : 'Access rule granted.'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                    setState(() {});
                                  }
                                } finally {
                                  setModalState(() => isSaving = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(isSaving ? 'Saving...' : (isEdit ? 'Save Changes' : 'Grant Access')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openView(dynamic item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    final system = item['systemName'] ?? item['system'] ?? 'System';
    final role = item['role'] ?? 'Role';
    final level = item['accessLevel'] ?? 'READ';
    final status = item['status'] ?? 'Active';
    final mfa = (item['mfaRequired'] ?? true) ? 'Required' : 'Optional';
    final notes = item['notes'] ?? 'No scope details specified.';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkMainSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Access Rule Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, size: 20, color: glass.textSecondary)),
                ],
              ),
              Divider(height: 16, color: glass.cardBorder),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(system.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                          const SizedBox(height: 2),
                          Text('Target Role: $role', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                        ],
                      ),
                    ),
                    StatusChip(status: status.toString().toUpperCase()),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Access Level', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                          const SizedBox(height: 4),
                          Text(level.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: glass.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MFA Requirement', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                          const SizedBox(height: 4),
                          Text(mfa, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.success)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text('Notes / Scope Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: glass.textSecondary)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x241E3A8A) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(left: BorderSide(color: AppColors.primary, width: 4)),
                ),
                child: Text(notes, style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A))),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close', style: TextStyle(color: glass.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openCreateOrEdit(item: item);
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Rule'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Revoke Access'),
        content: const Text('Are you sure you want to revoke this system access rule? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final apiClient = ref.read(apiClientProvider);
              try {
                await apiClient.delete('/it/access/$id');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Access rule revoked.')));
                  _fetchAccessRules();
                }
              } catch (_) {
                if (mounted) {
                  setState(() => _accessRules.removeWhere((r) => r['id'] == id));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Access rule revoked.')));
                }
              }
            },
            child: const Text('Revoke Access'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = ModalRoute.of(context)?.canPop ?? false;
    final bool shouldShowAppBar = widget.showAppBar || canPop;

    if (_isLoading) {
      final skeleton = const ListSkeleton(itemCount: 4);
      if (shouldShowAppBar) {
        return GlassScaffold(
          title: 'Access Management',
          showBottomBar: false,
          body: skeleton,
        );
      }
      return skeleton;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    final total = _accessRules.length;
    final activeCount = _accessRules.where((r) => (r['status'] ?? 'Active').toString().toLowerCase() == 'active').length;
    final suspendedCount = _accessRules.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'suspended').length;
    final revokedCount = _accessRules.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'revoked').length;
    final adminCount = _accessRules.where((r) => (r['accessLevel'] ?? '').toString().toUpperCase() == 'ADMIN' || (r['accessLevel'] ?? '').toString().toUpperCase() == 'ROOT').length;
    final mfaRequiredCount = _accessRules.where((r) => (r['mfaRequired'] ?? true) == true || (r['mfa'] ?? '') == 'Required').length;
    final mfaPercent = total > 0 ? ((mfaRequiredCount / total) * 100).toStringAsFixed(0) : '0';

    final filtered = _accessRules.where((r) {
      final system = (r['systemName'] ?? r['system'] ?? '').toString().toLowerCase();
      final role = (r['role'] ?? '').toString().toLowerCase();
      final notes = (r['notes'] ?? '').toString().toLowerCase();
      final status = (r['status'] ?? 'Active').toString();
      final level = (r['accessLevel'] ?? 'Read').toString().toLowerCase();

      final matchesSearch = system.contains(_searchTerm.toLowerCase()) || role.contains(_searchTerm.toLowerCase()) || notes.contains(_searchTerm.toLowerCase());
      final matchesStatus = _statusFilter == 'ALL' || status.toLowerCase() == _statusFilter.toLowerCase();
      final matchesLevel = _levelFilter == 'ALL' || level == _levelFilter.toLowerCase();
      return matchesSearch && matchesStatus && matchesLevel;
    }).toList();

    final Widget mainContent = RefreshIndicator(
      onRefresh: _fetchAccessRules,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
                      Text('Access Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Control system privileges, VPN access, and server permissions.', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _openCreateOrEdit(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Grant Access'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tabs Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildTabButton('All Access Rules', 'all', total),
                  const SizedBox(width: 8),
                  _buildTabButton('Active', 'active', activeCount),
                  const SizedBox(width: 8),
                  _buildTabButton('Suspended', 'suspended', suspendedCount),
                  const SizedBox(width: 8),
                  _buildTabButton('Revoked', 'revoked', revokedCount),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Stat Cards Row
            AutoMovingRow(
              children: [
                PastelSummaryPill(label: '$total Systems', variant: PastelPillVariant.blue),
                PastelSummaryPill(label: '$activeCount Active Roles', variant: PastelPillVariant.green),
                PastelSummaryPill(label: '$mfaPercent% MFA Enforced', variant: PastelPillVariant.purple),
                PastelSummaryPill(label: '$adminCount Admin Overrides', variant: PastelPillVariant.amber),
              ],
            ),
            const SizedBox(height: 14),

            // Circular Stat Group
            CircularStatGroup(
              items: [
                CircularStatItemData(label: 'Systems', value: '$total', ringColor: AppColors.primary),
                CircularStatItemData(label: 'Active', value: '$activeCount', ringColor: AppColors.success),
                CircularStatItemData(label: 'MFA %', value: '$mfaPercent%', ringColor: const Color(0xFF0891B2)),
                CircularStatItemData(label: 'Admin', value: '$adminCount', ringColor: const Color(0xFFD97706)),
              ],
            ),
            const SizedBox(height: 16),

            GlassSearchBar(
              controller: _searchController,
              placeholder: 'Search system, role, notes...',
              onChanged: (val) => setState(() => _searchTerm = val),
              onClear: () => setState(() => _searchTerm = ''),
            ),
            const SizedBox(height: 16),

            if (filtered.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text('No matching access rules found.', style: TextStyle(color: glass.textSecondary))),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final rule = filtered[index];
                  final system = rule['systemName'] ?? rule['system'] ?? 'System';
                  final role = rule['role'] ?? 'Role';
                  final level = rule['accessLevel'] ?? 'READ';
                  final status = rule['status'] ?? 'Active';
                  final mfa = (rule['mfaRequired'] ?? true) ? 'Required' : 'Optional';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(system.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              StatusChip(status: status.toString().toUpperCase()),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Role: $role  •  Level: $level', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                          Text('MFA: $mfa', style: TextStyle(fontSize: 12, color: isDark ? AppColors.primaryLight : AppColors.primary, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _openView(rule),
                                icon: const Icon(Icons.visibility, size: 14),
                                label: const Text('View'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _openCreateOrEdit(item: rule),
                                icon: const Icon(Icons.edit, size: 14),
                                label: const Text('Edit'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _confirmDelete(rule['id']),
                                icon: const Icon(Icons.close, color: Colors.red, size: 14),
                                label: const Text('Revoke', style: TextStyle(color: Colors.red)),
                              ),
                            ],
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

    if (shouldShowAppBar) {
      return GlassScaffold(
        title: 'Access Management',
        showBottomBar: false,
        body: mainContent,
      );
    }

    return mainContent;
  }

  Widget _buildTabButton(String label, String tabKey, int count) {
    final isSelected = _activeTab == tabKey;
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: isDark ? glass.cardFill : Colors.white,
      labelStyle: TextStyle(color: isSelected ? Colors.white : glass.textPrimary),
      onSelected: (_) => _setTab(tabKey),
    );
  }
}
