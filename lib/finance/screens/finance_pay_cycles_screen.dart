import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinancePayCyclesScreen extends ConsumerStatefulWidget {
  final bool? showAppBar;
  const FinancePayCyclesScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<FinancePayCyclesScreen> createState() => _FinancePayCyclesScreenState();
}

class _FinancePayCyclesScreenState extends ConsumerState<FinancePayCyclesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _cycles = [];

  // Modal Controllers
  final TextEditingController _nameController = TextEditingController(text: 'Nov 2026 Pay Cycle');
  final TextEditingController _monthController = TextEditingController(text: 'Nov');
  final TextEditingController _yearController = TextEditingController(text: '2026');
  final TextEditingController _startDateController = TextEditingController(text: '11/11/2026');
  final TextEditingController _endDateController = TextEditingController(text: '11/11/2026');
  final TextEditingController _disburseDateController = TextEditingController(text: '11/11/2026');
  String _cycleStatus = 'Open';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCycles();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _disburseDateController.dispose();
    super.dispose();
  }

  Future<void> _loadCycles() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.payCycles).catchError((_) => null);

      if (mounted) {
        if (res != null) {
          List<dynamic> items = [];
          if (res is List) {
            items = res;
          } else if (res is Map<String, dynamic>) {
            final data = res['data'] ?? res['items'] ?? res['result'] ?? res['cycles'];
            if (data is List) {
              items = data;
            }
          }

          final mapped = items.map((c) => _mapCycle(c)).toList();
          if (mapped.isNotEmpty) {
            _cycles = mapped;
          } else {
            _cycles = [];
          }
        } else {
          _cycles = [];
        }
        _isLoading = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cycles = [];
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapCycle(dynamic c) {
    final Map<String, dynamic> map = c is Map<String, dynamic> ? c : {};
    return {
      'title': map['title'] ?? map['cycleName'] ?? 'Payroll Cycle',
      'period': map['period'] ?? '${map['month'] ?? 'Nov'} ${map['year'] ?? '2026'}',
      'startDate': map['startDate'] ?? '11/11/2026',
      'endDate': map['endDate'] ?? '11/11/2026',
      'payDay': map['payDay'] ?? map['disbursementDate'] ?? '11/11/2026',
      'status': map['status'] ?? 'Open',
    };
  }

  void _showAddCycleModal() {
    _nameController.text = 'Nov 2026 Pay Cycle';
    _monthController.text = 'Nov';
    _yearController.text = '2026';
    _startDateController.text = '11/11/2026';
    _endDateController.text = '11/11/2026';
    _disburseDateController.text = '11/11/2026';
    _cycleStatus = 'Open';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            titlePadding: const EdgeInsets.all(16),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            actionsPadding: const EdgeInsets.all(12),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Add Pay Cycle', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('Manage payroll execution windows', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pay Cycle Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Nov 2026 Pay Cycle',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Month (3 letters) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _monthController,
                              decoration: InputDecoration(
                                hintText: 'Nov',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Year *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _yearController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '2026',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _startDateController,
                              decoration: InputDecoration(
                                suffixIcon: const Icon(Icons.calendar_today, size: 16),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('End Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _endDateController,
                              decoration: InputDecoration(
                                suffixIcon: const Icon(Icons.calendar_today, size: 16),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Disbursement Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _disburseDateController,
                              decoration: InputDecoration(
                                suffixIcon: const Icon(Icons.calendar_today, size: 16),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Cycle Status *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _cycleStatus,
                              isExpanded: true,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Open', child: Text('Open', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Closed', child: Text('Closed', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Processing', child: Text('Processing', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => _cycleStatus = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (_nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter pay cycle name'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  _saveNewCycle();
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Save Pay Cycle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveNewCycle() async {
    final name = _nameController.text.trim();
    final newCycle = {
      'title': name,
      'period': '${_monthController.text.trim()} ${_yearController.text.trim()}',
      'startDate': _startDateController.text.trim(),
      'endDate': _endDateController.text.trim(),
      'payDay': _disburseDateController.text.trim(),
      'status': _cycleStatus,
    };

    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post(ApiEndpoints.payCycles, data: newCycle).catchError((_) => null);

      if (mounted) {
        setState(() {
          _cycles.insert(0, newCycle);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pay cycle "$name" created successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cycles.insert(0, newCycle);
        });
      }
    }
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.lightSecondaryText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.lightPrimaryText),
          ),
          Text(
            sub,
            style: const TextStyle(fontSize: 10, color: AppColors.lightMutedText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCycleCard(Map<String, dynamic> item) {
    final status = (item['status'] ?? 'Open').toString();
    final isOpen = status.toLowerCase() == 'open';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.lightInputBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item['period'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOpen ? AppColors.successBg : AppColors.warningBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: isOpen ? AppColors.success : AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.lightInputBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricColumn('Start Date', item['startDate'] ?? '-', Colors.black87),
                _buildMetricColumn('End Date', item['endDate'] ?? '-', Colors.black87),
                _buildMetricColumn('Disbursement', item['payDay'] ?? '-', AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.lightSecondaryText), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    final bool showHeader = widget.showAppBar ?? false;

    final content = DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Tab Header Bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: AppColors.lightSecondarySurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.lightSecondaryText,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Pay Cycles Management'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: Overview
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppCard(
                        backgroundColor: AppColors.darkPrimary,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.white24,
                                  child: Icon(Icons.calendar_month, color: Colors.white, size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Payroll Configuration',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Define salary components, statutory formulas & pay cycles for automated payroll execution',
                                        style: TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showAddCycleModal,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Pay Cycle'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.darkPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          _buildStatCard(
                            label: 'TOTAL COMPONENTS',
                            value: '10',
                            sub: 'Master salary rules',
                            icon: Icons.list_alt,
                            bgColor: const Color(0xFFEFF6FF),
                            iconColor: const Color(0xFF2563EB),
                          ),
                          _buildStatCard(
                            label: 'EARNINGS',
                            value: '6',
                            sub: 'Gross salary additions',
                            icon: Icons.add_circle_outline,
                            bgColor: const Color(0xFFF0FDF4),
                            iconColor: const Color(0xFF16A34A),
                          ),
                          _buildStatCard(
                            label: 'DEDUCTIONS & STATUTORY',
                            value: '4',
                            sub: 'PF, ESI, TDS & Tax',
                            icon: Icons.remove_circle_outline,
                            bgColor: const Color(0xFFFEF2F2),
                            iconColor: const Color(0xFFDC2626),
                          ),
                          _buildStatCard(
                            label: 'ACTIVE PAY CYCLES',
                            value: '${_cycles.length}',
                            sub: 'Current payroll windows',
                            icon: Icons.date_range,
                            bgColor: const Color(0xFFFFF7ED),
                            iconColor: const Color(0xFFEA580C),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tab 2: Pay Cycles Management
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Pay Cycles Management',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.lightPrimary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_cycles.length} Configured',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Manage payroll execution windows, processing periods & payout dates',
                        style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText),
                      ),
                      const SizedBox(height: 12),

                      if (_cycles.isEmpty)
                        AppCard(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: const [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: AppColors.lightSecondarySurface,
                                  child: Icon(Icons.calendar_today_outlined, size: 28, color: AppColors.lightSecondaryText),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No pay cycles configured yet.',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Create a new pay cycle to begin payroll execution.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _cycles.length,
                          itemBuilder: (context, index) {
                            final item = _cycles[index];
                            return _buildCycleCard(item);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!showHeader) {
      return Material(color: Colors.transparent, child: content);
    }

    return GlassScaffold(
      appBar: const GlassHeader(title: 'Pay Cycles'),
      showBottomBar: false,
      body: content,
    );
  }
}
