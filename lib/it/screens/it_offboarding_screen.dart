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

class ItOffboardingScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const ItOffboardingScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<ItOffboardingScreen> createState() => _ItOffboardingScreenState();
}

class _ItOffboardingScreenState extends ConsumerState<ItOffboardingScreen> {
  bool _isLoading = true;
  List<dynamic> _offboardings = [];
  List<dynamic> _employees = [];
  String _searchTerm = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _checklistStates = ['PENDING', 'SCHEDULED', 'COMPLETED'];
  final List<String> _overallStatuses = ['IN_PROGRESS', 'COMPLETED', 'PENDING'];

  final Map<String, String> _statusMap = {
    'PENDING': 'Pending',
    'SCHEDULED': 'Scheduled',
    'IN_PROGRESS': 'In Progress',
    'COMPLETED': 'Completed',
    'RETURNED': 'Completed',
    'WIPED': 'Completed',
    'NOT_STARTED': 'Pending'
  };

  @override
  void initState() {
    super.initState();
    _fetchOffboardings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchOffboardings() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/it/offboarding').catchError((_) => null);
      dynamic empRes = await apiClient.get('/employees/all').catchError((_) => null);
      if (empRes == null) {
        empRes = await apiClient.get(ApiEndpoints.employees).catchError((_) => null);
      }

      if (mounted) {
        setState(() {
          List<dynamic> tasks = [];
          if (res is List) {
            tasks = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            tasks = res['data'];
          } else {
            tasks = [
              {'id': 'off-1', 'employeeName': 'Mansi Borase', 'employeeCode': 'EMP-26-0009', 'exitDate': '2026-10-27T00:00:00Z', 'accountDisabled': 'PENDING', 'assetReturned': 'PENDING', 'dataWiped': 'PENDING', 'status': 'IN_PROGRESS', 'notes': ''},
              {'id': 'off-2', 'employeeName': 'Employee One', 'employeeCode': 'EMP-24-0004', 'exitDate': '2026-09-17T00:00:00Z', 'accountDisabled': 'COMPLETED', 'assetReturned': 'COMPLETED', 'dataWiped': 'COMPLETED', 'status': 'COMPLETED', 'notes': ''}
            ];
          }

          _offboardings = tasks.map((t) {
            String rawDate = '';
            if (t['exitDate'] != null) {
              try {
                rawDate = DateTime.parse(t['exitDate'].toString()).toIso8601String().split('T')[0];
              } catch (_) {}
            }
            return {
              'id': t['id'],
              'employeeId': t['employeeId'],
              'empId': t['employeeCode'] ?? t['empId'] ?? 'EMP',
              'empName': t['employeeName'] ?? t['empName'] ?? 'Unknown Employee',
              'rawExitDate': rawDate,
              'exitDate': t['exitDate'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(t['exitDate'].toString())) : 'N/A',
              'rawAccountDisabled': t['accountDisabled'],
              'accountDisabled': _statusMap[(t['accountDisabled'] ?? '').toString().toUpperCase()] ?? t['accountDisabled'] ?? 'Pending',
              'rawAssetReturned': t['assetReturned'],
              'assetReturned': _statusMap[(t['assetReturned'] ?? '').toString().toUpperCase()] ?? t['assetReturned'] ?? 'Pending',
              'rawDataWiped': t['dataWiped'],
              'dataWiped': _statusMap[(t['dataWiped'] ?? '').toString().toUpperCase()] ?? t['dataWiped'] ?? 'Pending',
              'rawStatus': t['status'],
              'status': _statusMap[(t['status'] ?? '').toString().toUpperCase()] ?? t['status'] ?? 'In Progress',
              'notes': t['notes'] ?? ''
            };
          }).toList();

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
      if (kDebugMode) debugPrint('[ItOffboarding] Error: $e');
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
    final dateController = TextEditingController(text: item?['rawExitDate'] ?? (item?['exitDate'] != null ? item!['exitDate'].toString().split('T')[0] : DateTime.now().toIso8601String().split('T')[0]));
    final notesController = TextEditingController(text: item?['notes'] ?? '');

    String accountDisabled = item?['rawAccountDisabled'] ?? 'PENDING';
    String assetReturned = item?['rawAssetReturned'] ?? 'PENDING';
    String dataWiped = item?['rawDataWiped'] ?? 'PENDING';
    String overallStatus = item?['rawStatus'] ?? 'IN_PROGRESS';
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
        builder: (ctx, setModalState) {
          if (_employees.isEmpty) {
            final apiClient = ref.read(apiClientProvider);
            apiClient.get(ApiEndpoints.employees).then((res) {
              if (res is List && ctx.mounted) {
                setModalState(() => _employees = res);
              } else if (res is Map<String, dynamic> && res['data'] is List && ctx.mounted) {
                setModalState(() => _employees = res['data']);
              }
            }).catchError((_) {});
          }

          return Padding(
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
                        Text(isEdit ? 'Edit Offboarding Task' : 'Initiate Offboarding', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                        IconButton(onPressed: () => Navigator.pop(modalContext), icon: Icon(Icons.close, size: 20, color: glass.textSecondary)),
                      ],
                    ),
                    Divider(height: 16, color: glass.cardBorder),
                    const SizedBox(height: 8),

                    if (!isEdit) ...[
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
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Employee Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: codeController,
                                readOnly: true,
                                style: TextStyle(color: glass.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Auto-filled',
                                  hintStyle: TextStyle(color: glass.textSecondary),
                                  filled: true,
                                  fillColor: isDark ? const Color(0x0AFFFFFF) : Colors.grey.shade100,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Exit Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
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
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (isEdit) ...[
                      Text('SSO / Account Deactivation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _checklistStates.contains(accountDisabled.toUpperCase()) ? accountDisabled.toUpperCase() : 'PENDING',
                        dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                        style: TextStyle(color: glass.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        items: _checklistStates.map((st) => DropdownMenuItem(value: st, child: Text(st, style: TextStyle(color: glass.textPrimary)))).toList(),
                        onChanged: (val) => setModalState(() => accountDisabled = val ?? 'PENDING'),
                      ),
                      const SizedBox(height: 14),

                      Text('Asset Recovery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _checklistStates.contains(assetReturned.toUpperCase()) ? assetReturned.toUpperCase() : 'PENDING',
                        dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                        style: TextStyle(color: glass.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        items: _checklistStates.map((st) => DropdownMenuItem(value: st, child: Text(st, style: TextStyle(color: glass.textPrimary)))).toList(),
                        onChanged: (val) => setModalState(() => assetReturned = val ?? 'PENDING'),
                      ),
                      const SizedBox(height: 14),

                      Text('Data Backup & Wipe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _checklistStates.contains(dataWiped.toUpperCase()) ? dataWiped.toUpperCase() : 'PENDING',
                        dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                        style: TextStyle(color: glass.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        items: _checklistStates.map((st) => DropdownMenuItem(value: st, child: Text(st, style: TextStyle(color: glass.textPrimary)))).toList(),
                        onChanged: (val) => setModalState(() => dataWiped = val ?? 'PENDING'),
                      ),
                      const SizedBox(height: 14),

                      Text('Overall Offboarding Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _overallStatuses.contains(overallStatus.toUpperCase()) ? overallStatus.toUpperCase() : 'IN_PROGRESS',
                        dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                        style: TextStyle(color: glass.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        items: _overallStatuses.map((st) => DropdownMenuItem(value: st, child: Text(st, style: TextStyle(color: glass.textPrimary)))).toList(),
                        onChanged: (val) => setModalState(() => overallStatus = val ?? 'IN_PROGRESS'),
                      ),
                      const SizedBox(height: 14),
                    ],

                    Text('Offboarding Remarks & Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      style: TextStyle(color: glass.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Specify hardware collection details, credentials wipe info...',
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

                                  String formattedDate = dateController.text.trim();
                                  if (formattedDate.isNotEmpty && !formattedDate.contains('T')) {
                                    try {
                                      final dt = DateTime.parse(formattedDate);
                                      formattedDate = dt.toIso8601String();
                                    } catch (_) {
                                      formattedDate = '${dateController.text.trim()}T00:00:00Z';
                                    }
                                  }

                                  final payload = {
                                    'employeeId': selectedEmpId,
                                    'employeeCode': codeController.text.trim(),
                                    'employeeName': nameController.text.trim(),
                                    'exitDate': formattedDate,
                                    'accountDisabled': accountDisabled,
                                    'assetReturned': assetReturned,
                                    'dataWiped': dataWiped,
                                    'status': overallStatus,
                                    'notes': notesController.text.trim(),
                                  };

                                  try {
                                    if (isEdit) {
                                      final id = item['id'];
                                      if (id != null && !id.toString().startsWith('off-')) {
                                        await apiClient.put('/it/offboarding/$id', body: payload);
                                      } else {
                                        // Update local mock item
                                        item['employeeName'] = payload['employeeName'];
                                        item['employeeCode'] = payload['employeeCode'];
                                        item['exitDate'] = payload['exitDate'];
                                        item['rawExitDate'] = dateController.text.trim();
                                        item['accountDisabled'] = _statusMap[accountDisabled.toUpperCase()] ?? accountDisabled;
                                        item['rawAccountDisabled'] = accountDisabled;
                                        item['assetReturned'] = _statusMap[assetReturned.toUpperCase()] ?? assetReturned;
                                        item['rawAssetReturned'] = assetReturned;
                                        item['dataWiped'] = _statusMap[dataWiped.toUpperCase()] ?? dataWiped;
                                        item['rawDataWiped'] = dataWiped;
                                        item['status'] = _statusMap[overallStatus.toUpperCase()] ?? overallStatus;
                                        item['rawStatus'] = overallStatus;
                                        item['notes'] = payload['notes'];
                                      }
                                    } else {
                                      await apiClient.post('/it/offboarding', body: payload);
                                    }
                                    if (context.mounted) {
                                      Navigator.pop(modalContext);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(isEdit ? 'Offboarding updated successfully.' : 'Offboarding initiated successfully.'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                      _fetchOffboardings();
                                    }
                                  } catch (e) {
                                    if (kDebugMode) debugPrint('[ItOffboarding] Save error: $e');
                                    if (context.mounted) {
                                      if (isEdit) {
                                        item['employeeName'] = payload['employeeName'];
                                        item['employeeCode'] = payload['employeeCode'];
                                        item['exitDate'] = payload['exitDate'];
                                        item['accountDisabled'] = _statusMap[accountDisabled.toUpperCase()] ?? accountDisabled;
                                        item['assetReturned'] = _statusMap[assetReturned.toUpperCase()] ?? assetReturned;
                                        item['dataWiped'] = _statusMap[dataWiped.toUpperCase()] ?? dataWiped;
                                        item['status'] = _statusMap[overallStatus.toUpperCase()] ?? overallStatus;
                                        item['notes'] = payload['notes'];
                                      } else {
                                        _offboardings.insert(0, {
                                          'id': 'off-${DateTime.now().millisecondsSinceEpoch}',
                                          ...payload,
                                          'accountDisabled': _statusMap[accountDisabled.toUpperCase()] ?? accountDisabled,
                                          'assetReturned': _statusMap[assetReturned.toUpperCase()] ?? assetReturned,
                                          'dataWiped': _statusMap[dataWiped.toUpperCase()] ?? dataWiped,
                                          'status': _statusMap[overallStatus.toUpperCase()] ?? overallStatus,
                                        });
                                      }
                                      Navigator.pop(modalContext);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(isEdit ? 'Offboarding updated.' : 'Offboarding initiated.'),
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
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(isSaving ? 'Saving...' : (isEdit ? 'Save Changes' : 'Initiate Task')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _revokeNow(dynamic item) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.put('/it/offboarding/${item['id']}', body: {
        'accountDisabled': 'COMPLETED',
        'assetReturned': 'COMPLETED',
        'dataWiped': 'COMPLETED',
        'status': 'COMPLETED'
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('All accounts & access revoked for ${item['employeeName'] ?? item['empName']}'), backgroundColor: AppColors.success));
        _fetchOffboardings();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          item['accountDisabled'] = 'Completed';
          item['assetReturned'] = 'Completed';
          item['dataWiped'] = 'Completed';
          item['status'] = 'Completed';
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Access revoked successfully.'), backgroundColor: AppColors.success));
      }
    }
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this offboarding record? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final apiClient = ref.read(apiClientProvider);
              try {
                await apiClient.delete('/it/offboarding/$id');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offboarding record deleted.')));
                  _fetchOffboardings();
                }
              } catch (_) {
                if (mounted) {
                  setState(() => _offboardings.removeWhere((o) => o['id'] == id));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offboarding record deleted.')));
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
          title: 'IT Offboarding',
          showBottomBar: false,
          body: skeleton,
        );
      }
      return skeleton;
    }

    final glass = context.glass;

    final total = _offboardings.length;
    final pendingAsset = _offboardings.where((o) {
      final acc = (o['accountDisabled'] ?? '').toString();
      final ast = (o['assetReturned'] ?? '').toString();
      return acc != 'Completed' || ast != 'Completed';
    }).length;
    final ssoDisabled = _offboardings.where((o) {
      final acc = (o['accountDisabled'] ?? '').toString();
      final rawAcc = (o['rawAccountDisabled'] ?? '').toString();
      return acc == 'Completed' || rawAcc.toUpperCase() == 'COMPLETED';
    }).length;
    final completed = _offboardings.where((o) {
      final st = (o['status'] ?? '').toString();
      final rawSt = (o['rawStatus'] ?? '').toString();
      return st == 'Completed' || rawSt.toUpperCase() == 'COMPLETED';
    }).length;

    final filtered = _offboardings.where((o) {
      final name = (o['employeeName'] ?? o['empName'] ?? '').toString().toLowerCase();
      final code = (o['employeeCode'] ?? o['empId'] ?? '').toString().toLowerCase();
      return name.contains(_searchTerm.toLowerCase()) || code.contains(_searchTerm.toLowerCase());
    }).toList();

    final Widget mainContent = RefreshIndicator(
      onRefresh: _fetchOffboardings,
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
                      Text('IT Offboarding & Asset Recovery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Revoke access, disable SSO and recover hardware upon employee exit.', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showCreateEditModal(),
                  icon: const Icon(Icons.person_remove, size: 16),
                  label: const Text('Initiate Offboarding'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
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
                  label: '$total Exiting Employees',
                  variant: PastelPillVariant.blue,
                ),
                PastelSummaryPill(
                  label: '$pendingAsset Pending Asset Return',
                  variant: PastelPillVariant.amber,
                ),
                PastelSummaryPill(
                  label: '$ssoDisabled SSO Accounts Disabled',
                  variant: PastelPillVariant.purple,
                ),
                PastelSummaryPill(
                  label: '$completed Offboarding Completed',
                  variant: PastelPillVariant.green,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. CIRCULAR STATISTIC INDICATOR GROUP
            CircularStatGroup(
              items: [
                CircularStatItemData(
                  label: 'Exiting',
                  value: '$total',
                  ringColor: Colors.red.shade600,
                ),
                CircularStatItemData(
                  label: 'Asset Return',
                  value: '$pendingAsset',
                  ringColor: const Color(0xFFD97706),
                ),
                CircularStatItemData(
                  label: 'SSO Disabled',
                  value: '$ssoDisabled',
                  ringColor: const Color(0xFF9333EA),
                ),
                CircularStatItemData(
                  label: 'Completed',
                  value: '$completed',
                  ringColor: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 16),

            GlassSearchBar(
              controller: _searchController,
              placeholder: 'Search exiting employee...',
              onChanged: (val) => setState(() => _searchTerm = val),
              onClear: () => setState(() => _searchTerm = ''),
            ),
            const SizedBox(height: 16),

            if (filtered.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text('No offboarding records found.', style: TextStyle(color: glass.textSecondary))),
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
                  final name = item['employeeName'] ?? item['empName'] ?? 'Exiting Employee';
                  final code = item['employeeCode'] ?? item['empId'] ?? 'EMP';
                  final exitDate = _formatDate(item['exitDate']);
                  final accountDisabled = item['accountDisabled'] ?? 'Pending';
                  final assetReturned = item['assetReturned'] ?? 'Pending';
                  final dataWiped = item['dataWiped'] ?? 'Pending';
                  final status = item['status'] ?? 'In Progress';

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
                                  color: isDark ? const Color(0x24FFFFFF) : const Color(0xFFFFF1F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFFECACA)),
                                ),
                                alignment: Alignment.center,
                                child: Text(name.toString().isNotEmpty ? name.toString()[0].toUpperCase() : 'E', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red.shade600)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text('$code • Exit Date: $exitDate', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                                  ],
                                ),
                              ),
                              StatusChip(status: status.toString().toUpperCase().replaceAll(' ', '_')),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Checklist Status badges
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _buildChecklistBadge('Account: $accountDisabled', accountDisabled == 'Completed'),
                              _buildChecklistBadge('Asset: $assetReturned', assetReturned == 'Completed'),
                              _buildChecklistBadge('Data Wipe: $dataWiped', dataWiped == 'Completed'),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _revokeNow(item),
                                icon: const Icon(Icons.power_off, color: Colors.red, size: 14),
                                label: const Text('Revoke Now', style: TextStyle(color: Colors.red)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  side: const BorderSide(color: Colors.redAccent),
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
        title: 'IT Offboarding',
        showBottomBar: false,
        body: mainContent,
      );
    }

    return mainContent;
  }

  Widget _buildChecklistBadge(String text, bool isCompleted) {
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
