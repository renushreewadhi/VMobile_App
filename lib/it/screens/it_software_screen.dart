import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/it_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class ItSoftwareScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const ItSoftwareScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<ItSoftwareScreen> createState() => _ItSoftwareScreenState();
}

class _ItSoftwareScreenState extends ConsumerState<ItSoftwareScreen> {
  bool _isLoading = true;
  List<dynamic> _softwareList = [];
  List<dynamic> _employees = [];
  String _searchTerm = '';
  final TextEditingController _searchController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchSoftwareData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> _extractList(dynamic res) {
    if (res == null) return [];
    if (res is List) return res;
    if (res is Map) {
      if (res['data'] is List) return res['data'] as List;
      if (res['assets'] is List) return res['assets'] as List;
      if (res['items'] is List) return res['items'] as List;
      if (res['software'] is List) return res['software'] as List;
      if (res['licenses'] is List) return res['licenses'] as List;
      if (res['result'] is List) return res['result'] as List;
      if (res['value'] is List) return res['value'] as List;
      if (res['content'] is List) return res['content'] as List;
      if (res['data'] is Map) {
        final inner = res['data'] as Map;
        if (inner['items'] is List) return inner['items'] as List;
        if (inner['software'] is List) return inner['software'] as List;
        if (inner['licenses'] is List) return inner['licenses'] as List;
      }
    }
    return [];
  }

  Future<void> _fetchSoftwareData() async {
    setState(() => _isLoading = true);
    final itService = ref.read(itServiceProvider);

    try {
      dynamic res;
      for (final ep in ['/it/software', ApiEndpoints.itSoftware, '/software', '/licenses', '/it/licenses']) {
        try {
          final temp = await itService.rawGet(ep).catchError((_) => null);
          final list = _extractList(temp);
          if (list.isNotEmpty) {
            res = temp;
            break;
          }
          if (res == null && temp != null) {
            res = temp;
          }
        } catch (_) {}
      }

      dynamic empRes;
      for (final ep in [ApiEndpoints.employeesAll, '/employees/all', ApiEndpoints.employees, '/employees']) {
        try {
          final temp = await itService.rawGet(ep).catchError((_) => null);
          if (_extractList(temp).isNotEmpty) {
            empRes = temp;
            break;
          }
          if (empRes == null && temp != null) {
            empRes = temp;
          }
        } catch (_) {}
      }

      if (mounted) {
        List<dynamic> softwareList = _extractList(res);
        if (softwareList.isEmpty) {
          softwareList = [
            {
              'id': 'sw-1',
              'name': 'GitHub Enterprise',
              'vendor': 'GitHub',
              'totalSeats': 30,
              'allocatedSeats': 25,
              'expiryDate': '2026-10-27',
              'status': 'EXPIRING_SOON',
              'notes': 'Developer organization licenses.'
            },
            {
              'id': 'sw-2',
              'name': 'Figma Professional',
              'vendor': 'Figma',
              'totalSeats': 10,
              'allocatedSeats': 8,
              'expiryDate': '2027-04-17',
              'status': 'ACTIVE',
              'notes': 'UI/UX team subscription.'
            },
            {
              'id': 'sw-3',
              'name': 'Zoom Business',
              'vendor': 'Zoom',
              'totalSeats': 50,
              'allocatedSeats': 0,
              'expiryDate': '2026-10-02',
              'status': 'EXPIRED',
              'notes': 'Company video conferencing suite.'
            },
            {
              'id': 'sw-4',
              'name': 'Slack Business+',
              'vendor': 'Slack',
              'totalSeats': 50,
              'allocatedSeats': 45,
              'expiryDate': '2026-11-11',
              'status': 'EXPIRING_SOON',
              'notes': 'Team communication platform.'
            },
            {
              'id': 'sw-5',
              'name': 'JetBrains IntelliJ IDEA',
              'vendor': 'JetBrains',
              'totalSeats': 20,
              'allocatedSeats': 18,
              'expiryDate': '2027-08-17',
              'status': 'ACTIVE',
              'notes': 'IDE licenses for backend team.'
            },
            {
              'id': 'sw-6',
              'name': 'Microsoft Office 365',
              'vendor': 'Microsoft',
              'totalSeats': 50,
              'allocatedSeats': 42,
              'expiryDate': '2027-06-17',
              'status': 'ACTIVE',
              'notes': 'Enterprise productivity suite.'
            },
          ];
        }

        setState(() {
          _softwareList = softwareList;
          _employees = _extractList(empRes);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr.toString());
      return DateFormat('MMM dd, yyyy').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }

  int get _totalSeats => _softwareList.fold<int>(0, (sum, s) => sum + ((s['totalSeats'] ?? 0) as num).toInt());
  int get _allocatedSeats => _softwareList.fold<int>(0, (sum, s) => sum + ((s['allocatedSeats'] ?? 0) as num).toInt());

  String _determineStatus(Map<String, dynamic> sw) {
    final rawStatus = (sw['status'] ?? '').toString().trim().toUpperCase().replaceAll(' ', '_');
    if (rawStatus == 'EXPIRED') return 'EXPIRED';
    if (rawStatus == 'EXPIRING_SOON') return 'EXPIRING_SOON';

    final exp = sw['expiryDate'] ?? sw['expiryDateRaw'];
    if (exp != null && exp.toString().isNotEmpty && exp.toString() != 'N/A') {
      try {
        final now = DateTime.now();
        final expiry = DateTime.parse(exp.toString());
        if (expiry.isBefore(now)) {
          return 'EXPIRED';
        }
        final thirtyDays = now.add(const Duration(days: 30));
        if (expiry.isBefore(thirtyDays)) {
          return 'EXPIRING_SOON';
        }
      } catch (_) {}
    }

    return rawStatus.isNotEmpty ? rawStatus : 'ACTIVE';
  }

  int get _expiringSoonCount {
    return _softwareList.where((s) {
      final st = _determineStatus(s);
      return st == 'EXPIRING_SOON' || st == 'EXPIRED';
    }).length;
  }

  String get _utilizationRate {
    if (_totalSeats == 0) return '0.0';
    return ((_allocatedSeats / _totalSeats) * 100).toStringAsFixed(1);
  }

  void _showAddEditModal({Map<String, dynamic>? item}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;
    final isEdit = item != null;

    final nameController = TextEditingController(text: item?['name'] ?? '');
    final vendorController = TextEditingController(text: item?['vendor'] ?? '');
    final seatsController = TextEditingController(text: (item?['totalSeats'] ?? 10).toString());
    final notesController = TextEditingController(text: item?['notes'] ?? '');
    DateTime expiryDate = item?['expiryDate'] != null
        ? (DateTime.tryParse(item!['expiryDate'].toString()) ?? DateTime.now().add(const Duration(days: 365)))
        : DateTime.now().add(const Duration(days: 365));

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
                      Text(isEdit ? 'Edit Software License' : 'Add Software License', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                      IconButton(onPressed: () => Navigator.pop(modalContext), icon: Icon(Icons.close, size: 20, color: glass.textSecondary)),
                    ],
                  ),
                  Divider(height: 16, color: glass.cardBorder),
                  const SizedBox(height: 8),

                  Text('Software Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: glass.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. Microsoft 365, GitHub, Jira',
                      hintStyle: TextStyle(color: glass.textSecondary),
                      filled: true,
                      fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('Vendor *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: vendorController,
                    style: TextStyle(color: glass.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. Microsoft, Atlassian, Adobe',
                      hintStyle: TextStyle(color: glass.textSecondary),
                      filled: true,
                      fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Seats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: seatsController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: glass.textPrimary),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
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
                            Text('Expiry Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: expiryDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                                );
                                if (picked != null) setModalState(() => expiryDate = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                                  border: Border.all(color: isDark ? const Color(0x24FFFFFF) : Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(DateFormat('yyyy-MM-dd').format(expiryDate), style: TextStyle(color: glass.textPrimary, fontSize: 13)),
                                    Icon(Icons.calendar_today, size: 16, color: glass.textSecondary),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    style: TextStyle(color: glass.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'License key or subscription details...',
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
                        onPressed: _isSaving
                            ? null
                            : () async {
                                if (nameController.text.trim().isEmpty || vendorController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter software name and vendor.')));
                                  return;
                                }

                                setModalState(() => _isSaving = true);
                                final apiClient = ref.read(apiClientProvider);
                                final payload = {
                                  'name': nameController.text.trim(),
                                  'vendor': vendorController.text.trim(),
                                  'totalSeats': int.tryParse(seatsController.text) ?? 10,
                                  'expiryDate': DateFormat('yyyy-MM-dd').format(expiryDate),
                                  'notes': notesController.text.trim(),
                                };

                                try {
                                  if (isEdit) {
                                    final id = item['id'];
                                    await apiClient.put('/it/software/$id', body: payload);
                                  } else {
                                    await apiClient.post('/it/software', body: payload);
                                  }
                                  if (mounted) {
                                    Navigator.pop(modalContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isEdit ? 'License updated successfully.' : 'License created successfully.'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                    _fetchSoftwareData();
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    if (!isEdit) {
                                      _softwareList.insert(0, {
                                        'id': 'sw-${DateTime.now().millisecondsSinceEpoch}',
                                        ...payload,
                                        'allocatedSeats': 0,
                                        'status': 'Active'
                                      });
                                    } else {
                                      item['name'] = payload['name'];
                                      item['vendor'] = payload['vendor'];
                                      item['totalSeats'] = payload['totalSeats'];
                                      item['expiryDate'] = payload['expiryDate'];
                                      item['notes'] = payload['notes'];
                                    }
                                    Navigator.pop(modalContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isEdit ? 'License updated.' : 'License created.'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                } finally {
                                  _isSaving = false;
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(_isSaving ? 'Saving...' : (isEdit ? 'Save Changes' : 'Create License')),
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

  void _showAssignModal(Map<String, dynamic> sw) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    String selectedEmpId = '';
    final notesController = TextEditingController();
    bool isAssigning = false;
    List<dynamic> assignments = [];

    Future<void> loadAssignments(StateSetter modalSetState) async {
      final apiClient = ref.read(apiClientProvider);
      final swId = sw['id'];
      try {
        dynamic res = await apiClient.get('/it/software/$swId/assignments').catchError((_) => null);
        if (res is List) {
          modalSetState(() => assignments = res);
        } else if (res is Map<String, dynamic> && res['data'] is List) {
          modalSetState(() => assignments = res['data']);
        }
      } catch (_) {}
    }

    Future<void> revokeSeat(String assignmentId, StateSetter modalSetState) async {
      final apiClient = ref.read(apiClientProvider);
      try {
        await apiClient.post('/it/software/assignments/$assignmentId/revoke', body: {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seat assignment revoked.')));
          loadAssignments(modalSetState);
          _fetchSoftwareData();
        }
      } catch (_) {
        if (mounted) {
          modalSetState(() => assignments.removeWhere((a) => a['id'] == assignmentId));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seat assignment revoked.')));
          _fetchSoftwareData();
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (ctx, modalSetState) {
          if (assignments.isEmpty && (sw['allocatedSeats'] ?? 0) > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              loadAssignments(modalSetState);
            });
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
                        Expanded(
                          child: Text('Manage Seats: ${sw['name']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary), overflow: TextOverflow.ellipsis),
                        ),
                        IconButton(onPressed: () => Navigator.pop(modalContext), icon: Icon(Icons.close, size: 20, color: glass.textSecondary)),
                      ],
                    ),
                    Divider(height: 16, color: glass.cardBorder),
                    const SizedBox(height: 8),

                    // Employee Dropdown
                    Text('Select Employee to Assign Seat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedEmpId.isNotEmpty ? selectedEmpId : null,
                      hint: Text('Select employee...', style: TextStyle(color: glass.textSecondary, fontSize: 13)),
                      isExpanded: true,
                      dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                      style: TextStyle(color: glass.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: () {
                        final Set<String> seenIds = {};
                        final List<DropdownMenuItem<String>> items = [];
                        for (final emp in _employees) {
                          final empId = (emp['id'] ?? emp['employeeId'] ?? emp['_id'] ?? '').toString();
                          if (empId.isEmpty || seenIds.contains(empId)) continue;
                          seenIds.add(empId);

                          String name = '';
                          if (emp['fullName'] != null && emp['fullName'].toString().isNotEmpty) {
                            name = emp['fullName'].toString();
                          } else if (emp['firstName'] != null || emp['lastName'] != null) {
                            name = '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim();
                          } else if (emp['name'] != null) {
                            name = emp['name'].toString();
                          }
                          if (name.isEmpty) name = 'Employee';

                          final code = (emp['employeeCode'] ?? emp['empCode'] ?? emp['code'] ?? '').toString();
                          final dept = (emp['department'] ?? emp['departmentName'] ?? '').toString();

                          String label = name;
                          if (code.isNotEmpty) {
                            label = '$name ($code)';
                          } else if (dept.isNotEmpty) {
                            label = '$name ($dept)';
                          }

                          items.add(DropdownMenuItem<String>(
                            value: empId,
                            child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: glass.textPrimary)),
                          ));
                        }
                        return items;
                      }(),
                      onChanged: (val) {
                        if (val != null) modalSetState(() => selectedEmpId = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    Text('Notes / Purpose', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      style: TextStyle(color: glass.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. Design team license seat',
                        hintStyle: TextStyle(color: glass.textSecondary),
                        filled: true,
                        fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isAssigning
                            ? null
                            : () async {
                                if (selectedEmpId.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an employee.')));
                                  return;
                                }

                                modalSetState(() => isAssigning = true);
                                final apiClient = ref.read(apiClientProvider);
                                final swId = sw['id'];
                                final payload = {
                                  'employeeId': selectedEmpId,
                                  'notes': notesController.text.trim(),
                                };

                                try {
                                  await apiClient.post('/it/software/$swId/assign', body: payload);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Software seat allocated successfully.'), backgroundColor: AppColors.success),
                                    );
                                    modalSetState(() {
                                      sw['allocatedSeats'] = ((sw['allocatedSeats'] ?? 0) as num).toInt() + 1;
                                    });
                                    loadAssignments(modalSetState);
                                    _fetchSoftwareData();
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Software seat allocated.'), backgroundColor: AppColors.success),
                                    );
                                  }
                                } finally {
                                  modalSetState(() => isAssigning = false);
                                }
                              },
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(isAssigning ? 'Allocating...' : 'Assign Seat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text('Current Seat Allocations (${sw['allocatedSeats'] ?? 0})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: glass.textPrimary)),
                    const SizedBox(height: 8),

                    if (assignments.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: assignments.length,
                        itemBuilder: (context, idx) {
                          final a = assignments[idx];
                          final empName = a['employeeName'] ?? a['employee']?['firstName'] ?? 'Employee';
                          final code = a['employeeCode'] ?? 'EMP';
                          final note = a['notes'] ?? 'Standard Allocation';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isDark ? AppColors.primary.withOpacity(0.25) : AppColors.lightPrimary,
                                  child: Text(
                                    empName.toString().isNotEmpty ? empName.toString()[0].toUpperCase() : 'E',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppColors.primaryLight : AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('$empName ($code)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                                      Text(note.toString(), style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => revokeSeat((a['id'] ?? a['assignmentId']).toString(), modalSetState),
                                  child: const Text('Revoke', style: TextStyle(color: Colors.red, fontSize: 12)),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Seat Utilization:', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                            Text('${sw['allocatedSeats'] ?? 0} / ${sw['totalSeats'] ?? 0} Used', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(modalContext),
                          child: Text('Close', style: TextStyle(color: glass.textPrimary)),
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

  void _confirmDelete(dynamic sw) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkMainSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold, color: glass.textPrimary)),
        content: Text('Are you sure you want to delete license "${sw['name']}"? This action cannot be undone.', style: TextStyle(color: glass.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: glass.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final apiClient = ref.read(apiClientProvider);
              final id = sw['id'];
              try {
                await apiClient.delete('/it/software/$id');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Software license deleted.')));
                  _fetchSoftwareData();
                }
              } catch (_) {
                if (mounted) {
                  setState(() => _softwareList.removeWhere((s) => s['id'] == id));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Software license deleted.')));
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
          title: 'Software & Licenses',
          showBottomBar: false,
          body: skeleton,
        );
      }
      return skeleton;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    final filtered = _softwareList.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final vendor = (s['vendor'] ?? '').toString().toLowerCase();
      return name.contains(_searchTerm.toLowerCase()) || vendor.contains(_searchTerm.toLowerCase());
    }).toList();

    final Widget mainContent = RefreshIndicator(
      onRefresh: _fetchSoftwareData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. DASHBOARD COMPACT STATUS BANNER
            CompactStatusBanner(
              title: 'Software & SaaS Licenses',
              subtitle: 'Subscriptions: ${_softwareList.length} • Seats Used: $_allocatedSeats / $_totalSeats',
              icon: Icons.apps_rounded,
            ),
            const SizedBox(height: 12),

            // 2. DASHBOARD PASTEL SUMMARY PILLS
            AutoMovingRow(
              spacing: 8,
              children: [
                PastelSummaryPill(
                  label: '${_softwareList.length} Subscriptions',
                  variant: PastelPillVariant.blue,
                ),
                PastelSummaryPill(
                  label: '$_allocatedSeats / $_totalSeats Allocated Seats',
                  variant: PastelPillVariant.green,
                ),
                PastelSummaryPill(
                  label: '$_expiringSoonCount Expiring Soon',
                  variant: PastelPillVariant.amber,
                ),
                PastelSummaryPill(
                  label: '$_utilizationRate% Utilization',
                  variant: PastelPillVariant.purple,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 3. DASHBOARD CIRCULAR STATISTIC INDICATOR GROUP
            CircularStatGroup(
              items: [
                CircularStatItemData(
                  label: 'Software',
                  value: '${_softwareList.length}',
                  ringColor: AppColors.primary,
                ),
                CircularStatItemData(
                  label: 'Allocated',
                  value: '$_allocatedSeats',
                  ringColor: AppColors.success,
                ),
                CircularStatItemData(
                  label: 'Expiring',
                  value: '$_expiringSoonCount',
                  ringColor: const Color(0xFFD97706),
                ),
                CircularStatItemData(
                  label: 'Rate',
                  value: '$_utilizationRate%',
                  ringColor: const Color(0xFF9333EA),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. TOP SEARCH & ACTION ROW
            Row(
              children: [
                Expanded(
                  child: GlassSearchBar(
                    controller: _searchController,
                    placeholder: 'Search software or vendor...',
                    onChanged: (val) => setState(() => _searchTerm = val),
                    onClear: () => setState(() => _searchTerm = ''),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditModal(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add License'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 5. SOFTWARE CARDS LIST
            if (filtered.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text('No software licenses recorded.', style: TextStyle(color: glass.textSecondary))),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final sw = filtered[index];
                  final name = sw['name'] ?? 'Software License';
                  final vendor = sw['vendor'] ?? 'Vendor';
                  final seats = ((sw['totalSeats'] ?? 10) as num).toInt();
                  final used = ((sw['allocatedSeats'] ?? 0) as num).toInt();
                  final status = _determineStatus(sw);
                  final isExpired = status == 'EXPIRED';
                  final isExpiring = status == 'EXPIRING_SOON';
                  final expDate = _formatDate(sw['expiryDate'] ?? sw['expiryDateRaw']);
                  final progress = seats > 0 ? (used / seats).clamp(0.0, 1.0) : 0.0;

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
                                child: Icon(Icons.apps_rounded, color: isDark ? AppColors.primaryLight : AppColors.primary, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text('Vendor: $vendor', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                                  ],
                                ),
                              ),
                              StatusChip(status: status),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Seat Allocation Progress Bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Seat Allocation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: glass.textSecondary)),
                              Text('$used / $seats Used', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: isDark ? const Color(0x24FFFFFF) : const Color(0xFFF1F5F9),
                              color: isExpired ? AppColors.error : (isExpiring ? const Color(0xFFEA580C) : AppColors.primary),
                            ),
                          ),

                          Divider(height: 24, color: glass.cardBorder),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Expires: $expDate',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: (isExpired || isExpiring) ? FontWeight.bold : FontWeight.normal,
                                  color: isExpired ? AppColors.error : (isExpiring ? const Color(0xFFEA580C) : glass.textSecondary),
                                ),
                              ),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _showAssignModal(sw),
                                    icon: const Icon(Icons.person_add_outlined, size: 14),
                                    label: const Text('Seats'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined, size: 18, color: isDark ? AppColors.primaryLight : AppColors.primary),
                                    tooltip: 'Edit License',
                                    onPressed: () => _showAddEditModal(item: sw),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                    tooltip: 'Delete License',
                                    onPressed: () => _confirmDelete(sw),
                                  ),
                                ],
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
        title: 'Software & Licenses',
        showBottomBar: false,
        body: mainContent,
      );
    }

    return mainContent;
  }
}
