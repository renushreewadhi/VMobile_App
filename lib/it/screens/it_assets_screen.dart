import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/asset_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import 'it_asset_form_screen.dart';

class ItAssetsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const ItAssetsScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<ItAssetsScreen> createState() => _ItAssetsScreenState();
}

class _ItAssetsScreenState extends ConsumerState<ItAssetsScreen> {
  bool _isLoading = true;
  List<dynamic> _assets = [];
  List<dynamic> _employees = [];
  Map<String, dynamic> _stats = {
    'total': 0,
    'assigned': 0,
    'available': 0,
    'underRepair': 0,
  };
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  String _categoryFilter = 'ALL';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAssetsData();
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
      if (res['requests'] is List) return res['requests'] as List;
      if (res['result'] is List) return res['result'] as List;
      if (res['value'] is List) return res['value'] as List;
      if (res['content'] is List) return res['content'] as List;
      if (res['data'] is Map) {
        final inner = res['data'] as Map;
        if (inner['items'] is List) return inner['items'] as List;
        if (inner['assets'] is List) return inner['assets'] as List;
        if (inner['requests'] is List) return inner['requests'] as List;
        if (inner['content'] is List) return inner['content'] as List;
        if (inner['result'] is List) return inner['result'] as List;
      }
    }
    return [];
  }

  Future<void> _fetchAssetsData() async {
    setState(() => _isLoading = true);
    final assetService = ref.read(assetServiceProvider);

    try {
      // 1. Assets (single endpoint, no guessing)
      final res = await assetService.getItAssets();

      // 2. Employees for the assignment dropdown (failure is non-fatal)
      dynamic empRes;
      try {
        empRes = await assetService.rawGet(ApiEndpoints.employeesAll);
      } catch (e) {
        debugPrint('[ItAssets] employees load failed: $e');
      }

      if (mounted) {
        List<dynamic> assetList = _extractList(res);
        setState(() {
          _assets = assetList;
          _employees = _extractList(empRes);

          _stats = {
            'total': _assets.length,
            'assigned': _assets.where((a) => (a['status'] ?? '').toString().toUpperCase() == 'ASSIGNED').length,
            'available': _assets.where((a) => (a['status'] ?? '').toString().toUpperCase() == 'AVAILABLE').length,
            'underRepair': _assets.where((a) => (a['status'] ?? '').toString().toUpperCase() == 'UNDER_REPAIR').length,
          };

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ItAssets] load failed: $e');
      if (mounted) {
        setState(() {
          _assets = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load assets: ${e.toString().replaceFirst("ApiException: ", "")}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _employeeName(Map<String, dynamic> asset) {
    final apiAssigneeName = (asset['currentAssigneeName'] ?? asset['assigneeName'] ?? asset['assignedToName'] ?? asset['employeeName'] ?? '').toString().trim();
    if (apiAssigneeName.isNotEmpty) {
      return apiAssigneeName;
    }

    if (asset['assignedTo'] is Map) {
      final map = asset['assignedTo'] as Map;
      final name = (map['name'] ?? '${map['firstName'] ?? ''} ${map['lastName'] ?? ''}').toString().trim();
      if (name.isNotEmpty) return name;
    }
    if (asset['employee'] is Map) {
      final map = asset['employee'] as Map;
      final name = (map['name'] ?? '${map['firstName'] ?? ''} ${map['lastName'] ?? ''}').toString().trim();
      if (name.isNotEmpty) return name;
    }

    final assigneeId = asset['currentAssigneeId'] ?? asset['assigneeId'] ?? asset['assignedToId'] ?? asset['employeeId'];
    if (assigneeId == null || assigneeId.toString().isEmpty) return 'Unassigned';
    final idStr = assigneeId.toString();
    final emp = _employees.firstWhere(
          (e) => (e['id'] ?? e['employeeId'] ?? e['_id'] ?? '').toString() == idStr,
      orElse: () => null,
    );
    if (emp == null) return 'Unassigned';
    final firstName = emp['firstName'] ?? emp['name'] ?? '';
    final lastName = emp['lastName'] ?? '';
    final name = '$firstName $lastName'.trim();
    return name.isNotEmpty ? name : 'Unassigned';
  }

  String _categoryLabel(String cat) {
    switch (cat.toUpperCase()) {
      case 'LAPTOP':
        return 'Laptop';
      case 'MONITOR':
        return 'Monitor';
      case 'DESKTOP':
        return 'Desktop';
      case 'MOBILE':
        return 'Mobile Phone';
      case 'TABLET':
        return 'Tablet';
      case 'ACCESSORY':
        return 'Accessory';
      case 'KEYBOARD_MOUSE':
        return 'Keyboard / Mouse';
      case 'NETWORK':
        return 'Networking';
      case 'PRINTER':
        return 'Printer';
      default:
        return cat.isEmpty ? 'General' : cat;
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

  String _formatMoney(dynamic amount) {
    if (amount == null) return '₹0';
    final numVal = num.tryParse(amount.toString()) ?? 0;
    return '₹${NumberFormat('#,##,###').format(numVal)}';
  }

  bool _canAssign(Map<String, dynamic> asset) {
    final status = (asset['status'] ?? '').toString().toUpperCase();
    return status == 'AVAILABLE' || status == 'RETURNED' || status == 'UNDER_REPAIR';
  }

  void _showViewDetailsModal(Map<String, dynamic> asset) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    final tag = asset['assetCode'] ?? asset['assetTag'] ?? 'N/A';
    final name = asset['name'] ?? asset['assetName'] ?? 'Asset';
    final category = (asset['category'] ?? '').toString();
    final serial = asset['serialNumber'] ?? 'N/A';
    final assigneeName = _employeeName(asset);
    final vendor = asset['vendor'] ?? 'N/A';
    final purchaseDate = _formatDate(asset['purchaseDate']);
    final cost = _formatMoney(asset['purchaseCost']);
    final condition = asset['condition'] ?? 'Good';
    final warranty = asset['warranty'] ?? 'N/A';
    final notes = asset['notes'] ?? asset['remarks'] ?? '';
    final status = (asset['status'] ?? 'AVAILABLE').toString();

    final processor = asset['processor']?.toString().trim() ?? '';
    final ram = asset['ram']?.toString().trim() ?? '';
    final systemType = asset['systemType']?.toString().trim() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                      Text('Asset Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      IconButton(
                        icon: Icon(Icons.close, color: glass.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Top Header Container
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.primary.withOpacity(0.25) : AppColors.lightPrimary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tag.toString(),
                                  style: TextStyle(
                                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                name.toString(),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary),
                              ),
                            ],
                          ),
                        ),
                        StatusChip(status: status),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Detail Items Grid
                  _buildDetailRow('Category', _categoryLabel(category), 'Serial Number', serial.toString()),
                  const SizedBox(height: 12),
                  _buildDetailRow('Current Assignee', assigneeName, 'Vendor', vendor.toString()),
                  const SizedBox(height: 12),
                  _buildDetailRow('Purchase Date', purchaseDate, 'Purchase Cost', cost),
                  const SizedBox(height: 12),
                  _buildDetailRow('Condition', condition.toString(), 'Warranty', warranty.toString()),

                  if (processor.isNotEmpty || ram.isNotEmpty || systemType.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Hardware Specifications', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: glass.textSecondary)),
                    const SizedBox(height: 6),
                    if (processor.isNotEmpty) _buildSpecTile('Processor', processor),
                    if (ram.isNotEmpty) _buildSpecTile('RAM', ram),
                    if (systemType.isNotEmpty) _buildSpecTile('System Type', systemType),
                  ],

                  if (notes.toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Notes / Remarks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: glass.textSecondary)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x241E3A8A) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: const Border(left: BorderSide(color: AppColors.primary, width: 4)),
                      ),
                      child: Text(
                        notes.toString(),
                        style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: BorderSide(color: isDark ? const Color(0x24FFFFFF) : const Color(0xFFCBD5E1)),
                          ),
                          child: Text('Close', style: TextStyle(color: glass.textPrimary)),
                        ),
                      ),
                      if (_canAssign(asset)) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showAssignModal(asset);
                            },
                            icon: const Icon(Icons.person_add, size: 18),
                            label: const Text('Assign Asset'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpecTile(String title, String val) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text('$title: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: glass.textSecondary)),
            Expanded(child: Text(val, style: TextStyle(fontSize: 11, color: glass.textPrimary), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label1, String value1, String label2, String value2) {
    return Row(
      children: [
        Expanded(child: _buildDetailTile(label1, value1)),
        const SizedBox(width: 12),
        Expanded(child: _buildDetailTile(label2, value2)),
      ],
    );
  }

  Widget _buildDetailTile(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: glass.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: glass.textPrimary)),
        ],
      ),
    );
  }

  void _showAssignModal(Map<String, dynamic> asset) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    String selectedEmpId = '';
    DateTime issueDate = DateTime.now();
    String condition = 'GOOD';
    final notesController = TextEditingController();
    bool isAssigning = false;

    final tag = asset['assetCode'] ?? asset['assetTag'] ?? 'Asset';
    final name = asset['name'] ?? asset['assetName'] ?? '';
    final assetId = asset['id'] ?? asset['assetId'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                      Text('Assign Asset: $tag - $name', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Assign this hardware item to an employee', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                      const SizedBox(height: 16),

                      // Employee Dropdown
                      Text('Employee *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
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
                          if (val != null) setModalState(() => selectedEmpId = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Issue Date
                      Text('Issue Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: issueDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setModalState(() => issueDate = picked);
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
                              Text(DateFormat('yyyy-MM-dd').format(issueDate), style: TextStyle(color: glass.textPrimary)),
                              Icon(Icons.calendar_today, size: 18, color: glass.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Condition
                      Text('Condition', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: condition,
                        dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                        style: TextStyle(color: glass.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: [
                          DropdownMenuItem(value: 'GOOD', child: Text('Good', style: TextStyle(color: glass.textPrimary))),
                          DropdownMenuItem(value: 'MINOR_DAMAGE', child: Text('Minor Damage', style: TextStyle(color: glass.textPrimary))),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => condition = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Notes
                      Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        style: TextStyle(color: glass.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Remarks or warranty details...',
                          hintStyle: TextStyle(color: glass.textSecondary),
                          filled: true,
                          fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel', style: TextStyle(color: glass.textSecondary)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isAssigning
                                ? null
                                : () async {
                              if (selectedEmpId.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please select an employee.')),
                                );
                                return;
                              }

                              setModalState(() => isAssigning = true);
                              final apiClient = ref.read(apiClientProvider);
                              final payload = {
                                'employeeId': selectedEmpId,
                                'issueDate': DateFormat('yyyy-MM-dd').format(issueDate),
                                'condition': condition,
                                'notes': notesController.text.trim(),
                              };

                              try {
                                final assetService = ref.read(assetServiceProvider);
                                await assetService.assignAsset(assetId, payload);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Asset assigned successfully.'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                  _fetchAssetsData();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  setModalState(() => isAssigning = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to assign asset: ${e.toString()}'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: isAssigning
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                                : const Text('Assign'),
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
        );
      },
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
          title: 'IT Asset Management',
          showBottomBar: false,
          body: skeleton,
        );
      }
      return skeleton;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    final totalCount = _stats['total'] ?? _stats['totalAssets'] ?? _stats['count'] ?? _stats['total_assets'] ?? _assets.length;
    final assignedCount = _stats['assigned'] ?? _stats['assignedAssets'] ?? _stats['assigned_assets'] ?? _assets.where((a) => (a['status'] ?? '').toString().toUpperCase() == 'ASSIGNED').length;
    final availableCount = _stats['available'] ?? _stats['availableAssets'] ?? _stats['available_assets'] ?? _assets.where((a) => (a['status'] ?? '').toString().toUpperCase() == 'AVAILABLE').length;
    final repairCount = _stats['underRepair'] ?? _stats['underRepairAssets'] ?? _stats['inRepair'] ?? _stats['repair'] ?? _stats['under_repair'] ?? _assets.where((a) => (a['status'] ?? '').toString().toUpperCase() == 'UNDER_REPAIR').length;

    final filtered = _assets.where((a) {
      final name = (a['name'] ?? a['assetName'] ?? '').toString().toLowerCase();
      final tag = (a['assetCode'] ?? a['assetTag'] ?? '').toString().toLowerCase();
      final category = (a['category'] ?? '').toString().toUpperCase();
      final status = (a['status'] ?? 'AVAILABLE').toString().toUpperCase();

      final matchesSearch = name.contains(_searchQuery.toLowerCase()) || tag.contains(_searchQuery.toLowerCase());
      final matchesStatus = _statusFilter == 'ALL' || status == _statusFilter;
      final matchesCategory = _categoryFilter == 'ALL' || category == _categoryFilter;
      return matchesSearch && matchesStatus && matchesCategory;
    }).toList();

    final Widget mainContent = RefreshIndicator(
      onRefresh: _fetchAssetsData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. DASHBOARD COMPACT STATUS BANNER
            CompactStatusBanner(
              title: 'IT Asset Management',
              subtitle: 'Total: $totalCount • Assigned: $assignedCount • Available: $availableCount',
              icon: Icons.laptop_mac_rounded,
            ),
            const SizedBox(height: 12),

            // 2. DASHBOARD PASTEL SUMMARY PILLS
            AutoMovingRow(
              spacing: 8,
              children: [
                PastelSummaryPill(
                  label: '$totalCount Total Hardware Assets',
                  variant: PastelPillVariant.blue,
                ),
                PastelSummaryPill(
                  label: '$assignedCount Assigned',
                  variant: PastelPillVariant.green,
                ),
                PastelSummaryPill(
                  label: '$availableCount Available',
                  variant: PastelPillVariant.purple,
                ),
                PastelSummaryPill(
                  label: '$repairCount Under Repair',
                  variant: PastelPillVariant.amber,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 3. DASHBOARD CIRCULAR STATISTIC INDICATOR GROUP
            CircularStatGroup(
              items: [
                CircularStatItemData(
                  label: 'Total',
                  value: '$totalCount',
                  ringColor: AppColors.primary,
                ),
                CircularStatItemData(
                  label: 'Assigned',
                  value: '$assignedCount',
                  ringColor: AppColors.success,
                ),
                CircularStatItemData(
                  label: 'Available',
                  value: '$availableCount',
                  ringColor: const Color(0xFF2563EB),
                ),
                CircularStatItemData(
                  label: 'Repair',
                  value: '$repairCount',
                  ringColor: const Color(0xFFD97706),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. GLASS SEARCH BAR
            GlassSearchBar(
              controller: _searchController,
              placeholder: 'Search assets by tag or device name...',
              onChanged: (val) => setState(() => _searchQuery = val),
              onClear: () => setState(() => _searchQuery = ''),
            ),
            const SizedBox(height: 12),

            // 5. STATUS FILTER CHIPS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['ALL', 'AVAILABLE', 'ASSIGNED', 'UNDER_REPAIR', 'RETURNED', 'RETIRED'].map((status) {
                  final isSelected = _statusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        status == 'ALL' ? 'All' : status.replaceAll('_', ' '),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : glass.textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: isDark ? glass.cardFill : Colors.white.withOpacity(0.8),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : glass.cardBorder,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onSelected: (_) => setState(() => _statusFilter = status),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // 6. ASSET INVENTORY LIST
            if (filtered.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text('No assets found matching filters.', style: TextStyle(color: glass.textSecondary)),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final asset = filtered[index];
                  final tag = asset['assetCode'] ?? asset['assetTag'] ?? 'AST-100';
                  final name = asset['name'] ?? asset['assetName'] ?? 'Device';
                  final category = (asset['category'] ?? '').toString();
                  final assigneeName = _employeeName(asset);
                  final status = (asset['status'] ?? 'AVAILABLE').toString();

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
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.primary.withOpacity(0.2) : AppColors.lightPrimary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.laptop_mac_rounded, color: isDark ? AppColors.primaryLight : AppColors.primary, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          tag.toString(),
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.primaryLight : AppColors.primary,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0x24FFFFFF) : AppColors.lightSecondarySurface,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _categoryLabel(category),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: glass.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      name.toString(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: glass.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.person_outline, size: 14, color: glass.textSecondary),
                                        const SizedBox(width: 4),
                                        Text(
                                          assigneeName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: assigneeName == 'Unassigned' ? glass.textSecondary : glass.textPrimary,
                                            fontStyle: assigneeName == 'Unassigned' ? FontStyle.italic : FontStyle.normal,
                                            fontWeight: assigneeName == 'Unassigned' ? FontWeight.normal : FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              StatusChip(status: status),
                            ],
                          ),
                          Divider(height: 20, color: glass.cardBorder),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Purchase: ${_formatDate(asset['purchaseDate'])}',
                                style: TextStyle(fontSize: 11, color: glass.textSecondary),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.visibility_outlined, size: 20, color: isDark ? AppColors.primaryLight : AppColors.primary),
                                    tooltip: 'View Details',
                                    onPressed: () => _showViewDetailsModal(asset),
                                  ),
                                  if (_canAssign(asset))
                                    IconButton(
                                      icon: const Icon(Icons.person_add_outlined, size: 20, color: Color(0xFF16A34A)),
                                      tooltip: 'Assign Asset',
                                      onPressed: () => _showAssignModal(asset),
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
        appBar: GlassHeader(
          title: 'IT Asset Management',
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              tooltip: 'Add Asset',
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const ItAssetFormScreen()),
                );
                if (created == true) _fetchAssetsData();
              },
            ),
          ],
        ),
        showBottomBar: false,
        body: mainContent,
      );
    }

    return mainContent;
  }
}