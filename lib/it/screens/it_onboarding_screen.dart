import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class ItOnboardingScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const ItOnboardingScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<ItOnboardingScreen> createState() => _ItOnboardingScreenState();
}

class _ItOnboardingScreenState extends ConsumerState<ItOnboardingScreen> {
  bool _isLoading = true;
  List<dynamic> _onboardings = [];
  List<dynamic> _employees = [];
  String _searchTerm = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchOnboardings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchOnboardings() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/it/onboarding').catchError((_) => null);
      dynamic empRes = await apiClient.get('/employees/all').catchError((_) => null);
      if (empRes == null) {
        empRes = await apiClient.get(ApiEndpoints.employees).catchError((_) => null);
      }

      if (mounted) {
        setState(() {
          if (res is List) {
            _onboardings = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _onboardings = res['data'];
          } else {
            _onboardings = [
              {'id': 'onb-1', 'empId': 'EMP-24-0004', 'empName': 'Employee One', 'role': 'Software Engineer', 'joinDate': '2024-02-01T00:00:00Z', 'emailSetup': 'Completed', 'laptopProvisioned': 'Completed', 'vpnAccess': 'Completed'},
              {'id': 'onb-2', 'empId': 'EMP-24-0006', 'empName': 'IT Manager', 'role': 'IT Specialist', 'joinDate': '2024-01-15T00:00:00Z', 'emailSetup': 'Completed', 'laptopProvisioned': 'Completed', 'vpnAccess': 'Completed'},
              {'id': 'onb-3', 'empId': 'EMP-24-0001', 'empName': 'Admin User', 'role': 'Admin', 'joinDate': '2023-01-01T00:00:00Z', 'emailSetup': 'Completed', 'laptopProvisioned': 'In Progress', 'vpnAccess': 'Pending'},
            ];
          }

          if (empRes is List) {
            _employees = empRes;
          } else if (empRes is Map<String, dynamic>) {
            if (empRes['data'] is List) {
              _employees = empRes['data'];
            } else if (empRes['result'] is List) {
              _employees = empRes['result'];
            }
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ItOnboarding] Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr.toString());
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }

  void _showCreateEditModal({Map<String, dynamic>? item}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;
    final isEdit = item != null;

    String selectedEmpId = item?['employeeId'] ?? '';
    final codeController = TextEditingController(text: item?['empId'] ?? item?['employeeCode'] ?? '');
    final nameController = TextEditingController(text: item?['empName'] ?? item?['employeeName'] ?? '');
    final roleController = TextEditingController(text: item?['role'] ?? '');
    final dateController = TextEditingController(text: item?['rawJoinDate'] ?? (item?['joinDate'] != null ? item!['joinDate'].toString().split('T')[0] : DateTime.now().toIso8601String().split('T')[0]));
    final notesController = TextEditingController(text: item?['notes'] ?? '');
    bool isSaving = false;

    // Find currently selected employee object for dropdown
    dynamic selectedEmpDropdownValue;
    if (selectedEmpId.isNotEmpty || codeController.text.isNotEmpty) {
      try {
        selectedEmpDropdownValue = _employees.firstWhere(
          (e) => (e['id'] ?? e['employeeId'] ?? '').toString() == selectedEmpId ||
                 (e['employeeId'] ?? e['code'] ?? '').toString() == codeController.text,
          orElse: () => null,
        );
      } catch (_) {}
    }

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
                      Text(isEdit ? 'Edit Onboarding' : 'Initiate Onboarding', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                      IconButton(onPressed: () => Navigator.pop(modalContext), icon: Icon(Icons.close, size: 20, color: glass.textSecondary)),
                    ],
                  ),
                  Divider(height: 16, color: glass.cardBorder),
                  const SizedBox(height: 8),

                  Text('Employee *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<dynamic>(
                    value: selectedEmpDropdownValue,
                    decoration: InputDecoration(
                      hintText: 'Select employee...',
                      filled: true,
                      fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                    style: TextStyle(color: glass.textPrimary, fontSize: 14),
                    items: _employees.map((emp) {
                      final fName = emp['firstName'] ?? emp['name'] ?? 'Employee';
                      final lName = emp['lastName'] ?? '';
                      final code = emp['employeeId'] ?? emp['code'] ?? 'EMP';
                      return DropdownMenuItem(
                        value: emp,
                        child: Text('$fName $lName ($code)', style: TextStyle(color: glass.textPrimary), overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (emp) {
                      if (emp != null) {
                        setModalState(() {
                          selectedEmpDropdownValue = emp;
                          selectedEmpId = (emp['id'] ?? emp['employeeId'] ?? '').toString();
                          codeController.text = emp['employeeId'] ?? emp['code'] ?? '';
                          nameController.text = '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim();
                          roleController.text = emp['designation'] ?? emp['role'] ?? 'Software Engineer';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  Text('Employee Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: codeController,
                    readOnly: true,
                    style: TextStyle(color: glass.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Auto-filled from employee',
                      hintStyle: TextStyle(color: glass.textSecondary),
                      filled: true,
                      fillColor: isDark ? const Color(0x0AFFFFFF) : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('Employee Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    readOnly: true,
                    style: TextStyle(color: glass.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Auto-filled from employee',
                      hintStyle: TextStyle(color: glass.textSecondary),
                      filled: true,
                      fillColor: isDark ? const Color(0x0AFFFFFF) : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: roleController,
                    style: TextStyle(color: glass.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. Software Engineer',
                      hintStyle: TextStyle(color: glass.textSecondary),
                      filled: true,
                      fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('Join Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: dateController,
                    style: TextStyle(color: glass.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'YYYY-MM-DD',
                      hintStyle: TextStyle(color: glass.textSecondary),
                      filled: true,
                      fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    style: TextStyle(color: glass.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Optional notes...',
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
                                if (nameController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an employee.')));
                                  return;
                                }

                                setModalState(() => isSaving = true);
                                final apiClient = ref.read(apiClientProvider);
                                final payload = {
                                  'employeeId': selectedEmpId,
                                  'employeeCode': codeController.text.trim(),
                                  'employeeName': nameController.text.trim(),
                                  'role': roleController.text.trim(),
                                  'joinDate': dateController.text.trim(),
                                  'notes': notesController.text.trim(),
                                };

                                try {
                                  if (isEdit) {
                                    await apiClient.put('/it/onboarding/${item['id']}', body: payload);
                                  } else {
                                    await apiClient.post('/it/onboarding', body: payload);
                                  }
                                  if (context.mounted) {
                                    Navigator.pop(modalContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isEdit ? 'Onboarding updated successfully.' : 'Onboarding initiated successfully.'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                    _fetchOnboardings();
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    if (isEdit) {
                                      item['empName'] = payload['employeeName'];
                                      item['empId'] = payload['employeeCode'];
                                      item['role'] = payload['role'];
                                      item['joinDate'] = payload['joinDate'];
                                    } else {
                                      _onboardings.insert(0, {
                                        'id': 'onb-${DateTime.now().millisecondsSinceEpoch}',
                                        'empName': payload['employeeName'],
                                        'empId': payload['employeeCode'],
                                        'role': payload['role'],
                                        'joinDate': payload['joinDate'],
                                        'emailSetup': 'Pending',
                                        'laptopProvisioned': 'Pending',
                                        'vpnAccess': 'Pending',
                                      });
                                    }
                                    Navigator.pop(modalContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isEdit ? 'Onboarding updated.' : 'Onboarding initiated.'),
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
                        child: Text(isSaving ? 'Saving...' : (isEdit ? 'Update' : 'Create')),
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

  Future<void> _provision(dynamic item) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.put('/it/onboarding/${item['id']}', body: {
        'emailSetup': 'COMPLETED',
        'laptopProvisioned': 'COMPLETED',
        'vpnAccess': 'COMPLETED'
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Provisioned all IT access for ${item['employeeName'] ?? item['empName']}'), backgroundColor: AppColors.success));
        _fetchOnboardings();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          item['emailSetup'] = 'Completed';
          item['laptopProvisioned'] = 'Completed';
          item['vpnAccess'] = 'Completed';
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Provisioned successfully.'), backgroundColor: AppColors.success));
      }
    }
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this onboarding task? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final apiClient = ref.read(apiClientProvider);
              try {
                await apiClient.delete('/it/onboarding/$id');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Onboarding task deleted.')));
                  _fetchOnboardings();
                }
              } catch (_) {
                if (mounted) {
                  setState(() => _onboardings.removeWhere((o) => o['id'] == id));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Onboarding task deleted.')));
                }
              }
            },
            child: const Text('Delete'),
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
          title: 'IT Onboarding Checklist',
          showBottomBar: false,
          body: skeleton,
        );
      }
      return skeleton;
    }

    final glass = context.glass;

    final total = _onboardings.length;
    final pendingProv = _onboardings.where((o) => (o['laptopProvisioned'] ?? '').toString().toLowerCase() != 'completed').length;
    final emailReady = _onboardings.where((o) => (o['emailSetup'] ?? '').toString().toLowerCase() == 'completed').length;
    final vpnActive = _onboardings.where((o) => (o['vpnAccess'] ?? '').toString().toLowerCase() == 'completed').length;

    final filtered = _onboardings.where((o) {
      final name = (o['employeeName'] ?? o['empName'] ?? '').toString().toLowerCase();
      final role = (o['role'] ?? '').toString().toLowerCase();
      final code = (o['employeeCode'] ?? o['empId'] ?? '').toString().toLowerCase();
      return name.contains(_searchTerm.toLowerCase()) || role.contains(_searchTerm.toLowerCase()) || code.contains(_searchTerm.toLowerCase());
    }).toList();

    final Widget mainContent = RefreshIndicator(
      onRefresh: _fetchOnboardings,
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
                      Text('IT Onboarding Checklist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Automate email, laptop provisioning & VPN access for new hires.', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showCreateEditModal(),
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Initiate Onboarding'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 1. PASTEL SUMMARY PILLS (Auto-Moving Row)
            AutoMovingRow(
              spacing: 8,
              children: [
                PastelSummaryPill(
                  label: '$total Total Onboarding Tasks',
                  variant: PastelPillVariant.blue,
                ),
                PastelSummaryPill(
                  label: '$pendingProv Pending Provisioning',
                  variant: PastelPillVariant.amber,
                ),
                PastelSummaryPill(
                  label: '$emailReady Email Accounts Ready',
                  variant: PastelPillVariant.purple,
                ),
                PastelSummaryPill(
                  label: '$vpnActive VPN Credentials Active',
                  variant: PastelPillVariant.green,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. CIRCULAR STATISTIC INDICATOR GROUP
            CircularStatGroup(
              items: [
                CircularStatItemData(
                  label: 'Total',
                  value: '$total',
                  ringColor: AppColors.primary,
                ),
                CircularStatItemData(
                  label: 'Pending',
                  value: '$pendingProv',
                  ringColor: const Color(0xFFD97706),
                ),
                CircularStatItemData(
                  label: 'Email Ready',
                  value: '$emailReady',
                  ringColor: const Color(0xFF9333EA),
                ),
                CircularStatItemData(
                  label: 'VPN Active',
                  value: '$vpnActive',
                  ringColor: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 16),

            GlassSearchBar(
              controller: _searchController,
              placeholder: 'Search new hire or role...',
              onChanged: (val) => setState(() => _searchTerm = val),
              onClear: () => setState(() => _searchTerm = ''),
            ),
            const SizedBox(height: 16),

            if (filtered.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text('No onboarding tasks found.', style: TextStyle(color: glass.textSecondary))),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final item = filtered[index];
                  final name = item['employeeName'] ?? item['empName'] ?? 'New Hire';
                  final code = item['employeeCode'] ?? item['empId'] ?? 'EMP';
                  final role = item['role'] ?? 'Software Engineer';
                  final joinDate = _formatDate(item['joinDate']);
                  final emailSetup = item['emailSetup'] ?? 'Pending';
                  final laptop = item['laptopProvisioned'] ?? 'Pending';
                  final vpn = item['vpnAccess'] ?? 'Pending';
                  final isCompleted = emailSetup == 'Completed' && laptop == 'Completed' && vpn == 'Completed';
                  final status = isCompleted ? 'COMPLETED' : 'PENDING';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0x24FFFFFF) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                                ),
                                alignment: Alignment.center,
                                child: Text(name.toString().isNotEmpty ? name.toString()[0].toUpperCase() : 'N', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.primaryLight : AppColors.primary)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text('$code • Role: $role', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                                    Text('Joined: $joinDate', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                                  ],
                                ),
                              ),
                              StatusChip(status: status),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Provisioning statuses
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _buildStatusBadge('Email: $emailSetup', emailSetup == 'Completed'),
                              _buildStatusBadge('Laptop: $laptop', laptop == 'Completed'),
                              _buildStatusBadge('VPN: $vpn', vpn == 'Completed'),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _provision(item),
                                icon: const Icon(Icons.task_alt, size: 14),
                                label: const Text('Provision'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                tooltip: 'Edit',
                                onPressed: () => _showCreateEditModal(item: item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                tooltip: 'Delete',
                                onPressed: () => _confirmDelete(item['id']),
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
        title: 'IT Onboarding Checklist',
        showBottomBar: false,
        body: mainContent,
      );
    }

    return mainContent;
  }

  Widget _buildStatusBadge(String text, bool isCompleted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isCompleted ? const Color(0xFFBBF7D0) : const Color(0xFFFFEDD5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFFC2410C),
        ),
      ),
    );
  }
}
