import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinancePayrollScreen extends ConsumerStatefulWidget {
  const FinancePayrollScreen({super.key});

  @override
  ConsumerState<FinancePayrollScreen> createState() => _FinancePayrollScreenState();
}

class _FinancePayrollScreenState extends ConsumerState<FinancePayrollScreen> {
  String _selectedMonth = 'Oct 2026';
  String _selectedDepartment = 'All';
  String _selectedStatus = 'All'; // 'All', 'Processed', 'Pending Review', 'Draft', 'Calculated'
  String _searchQuery = '';
  bool _isLoading = true;

  final List<String> _monthOptions = [
    'Oct 2026',
    'Sep 2026',
    'Aug 2026',
    'Jul 2026',
    'Jun 2026',
    'May 2026',
  ];

  final List<String> _departmentOptions = [
    'All',
    'Engineering',
    'IT Operations',
    'Digital Marketing',
    'Product Design',
    'Human Resources',
    'Finance',
  ];

  final List<String> _statusOptions = [
    'All',
    'Processed',
    'Pending Review',
    'Draft',
    'Calculated',
  ];

  List<Map<String, dynamic>> _payrolls = [];

  final List<Map<String, dynamic>> _milestones = [
    {
      'step': '01',
      'title': 'Attendance & Leave Lock',
      'date': '25th of Month',
      'desc': 'Biometric logs & leave requests frozen',
      'status': 'Completed',
      'color': const Color(0xFF16A34A),
    },
    {
      'step': '02',
      'title': 'Variable Pay & Reimbursements',
      'date': '28th of Month',
      'desc': 'Overtime & expense claim approvals synced',
      'status': 'Completed',
      'color': const Color(0xFF16A34A),
    },
    {
      'step': '03',
      'title': 'Statutory Deduction Verification',
      'date': '30th of Month',
      'desc': 'TDS, PF & ESI tax computation check',
      'status': 'In Progress',
      'color': const Color(0xFF2563EB),
    },
    {
      'step': '04',
      'title': 'Bank Salary Disbursement',
      'date': '1st of Month',
      'desc': 'Direct payout transfer to accounts',
      'status': 'Upcoming',
      'color': const Color(0xFFEA580C),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPayrollData();
  }

  Future<void> _loadPayrollData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.payrollDashboard).catchError((_) => null);

      if (mounted) {
        List<dynamic> items = [];
        if (res is List) {
          items = res;
        } else if (res is Map<String, dynamic> && res['records'] is List) {
          items = res['records'];
        }

        if (items.isNotEmpty) {
          _payrolls = items.map((r) => _mapPayrollRow(r)).toList();
        } else {
          _payrolls = _getMockPayrolls();
        }
        _isLoading = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _payrolls = _getMockPayrolls();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapPayrollRow(dynamic r) {
    final Map<String, dynamic> item = r is Map<String, dynamic> ? r : {};
    final name = item['employeeName'] ?? item['name'] ?? 'Employee';

    return {
      'payrollId': item['id'] ?? 'PR-801',
      'employeeId': item['employeeId'] ?? 'EMP-101',
      'name': name,
      'empId': item['employeeCode'] ?? item['empId'] ?? 'EMP-101',
      'designation': item['designation'] ?? 'Software Engineer',
      'department': item['department'] ?? 'Engineering',
      'basicSalary': item['basicSalary'] != null ? '₹${item['basicSalary']}' : '₹45,000',
      'allowances': item['allowances'] != null ? '₹${item['allowances']}' : '₹18,000',
      'deductions': item['deductions'] != null ? '₹${item['deductions']}' : '₹7,850',
      'netPay': item['netPay'] != null ? '₹${item['netPay']}' : '₹55,150',
      'rawNetPay': item['netPay'] ?? 55150,
      'status': item['status'] ?? 'Processed',
      'initials': _getInitials(name),
      'avatarBg': const Color(0xFFEFF6FF),
      'avatarColor': const Color(0xFF2563EB),
    };
  }

  List<Map<String, dynamic>> _getMockPayrolls() {
    return [
      {
        'payrollId': 'PR-101',
        'employeeId': 'EMP-26-0010',
        'name': 'Gaurav Modi',
        'empId': 'EMP-26-0010',
        'designation': 'Lead DevOps Engineer',
        'department': 'IT Operations',
        'basicSalary': '₹45,000',
        'allowances': '₹25,000',
        'deductions': '₹7,850',
        'netPay': '₹62,150',
        'rawNetPay': 62150,
        'status': 'Processed',
        'initials': 'GM',
        'avatarBg': const Color(0xFFEFF6FF),
        'avatarColor': const Color(0xFF2563EB),
      },
      {
        'payrollId': 'PR-102',
        'employeeId': 'EMP-26-0008',
        'name': 'Vidyarthi Prince',
        'empId': 'EMP-26-0008',
        'designation': 'Marketing Specialist',
        'department': 'Digital Marketing',
        'basicSalary': '₹45,000',
        'allowances': '₹25,000',
        'deductions': '₹53,187',
        'netPay': '₹16,813',
        'rawNetPay': 16813,
        'status': 'Pending Review',
        'initials': 'VP',
        'avatarBg': const Color(0xFFFFF7ED),
        'avatarColor': const Color(0xFFEA580C),
      },
      {
        'payrollId': 'PR-103',
        'employeeId': 'EMP-26-0012',
        'name': 'Priya Sharma',
        'empId': 'EMP-26-0012',
        'designation': 'Senior UI/UX Designer',
        'department': 'Product Design',
        'basicSalary': '₹50,000',
        'allowances': '₹20,000',
        'deductions': '₹8,200',
        'netPay': '₹61,800',
        'rawNetPay': 61800,
        'status': 'Calculated',
        'initials': 'PS',
        'avatarBg': const Color(0xFFF0FDF4),
        'avatarColor': const Color(0xFF16A34A),
      },
      {
        'payrollId': 'PR-104',
        'employeeId': 'EMP-26-0015',
        'name': 'Sarah Jenkins',
        'empId': 'EMP-26-0015',
        'designation': 'HR Operations Lead',
        'department': 'Human Resources',
        'basicSalary': '₹48,000',
        'allowances': '₹18,000',
        'deductions': '₹7,500',
        'netPay': '₹58,500',
        'rawNetPay': 58500,
        'status': 'Draft',
        'initials': 'SJ',
        'avatarBg': const Color(0xFFE0F2FE),
        'avatarColor': const Color(0xFF0284C7),
      },
    ];
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'PR';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : name.length).toUpperCase();
  }

  List<Map<String, dynamic>> get _filteredPayrolls {
    return _payrolls.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final empId = (item['empId'] ?? '').toString().toLowerCase();
      final dept = (item['department'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      final matchesQuery = _searchQuery.isEmpty || name.contains(query) || empId.contains(query) || dept.contains(query);
      final matchesDept = _selectedDepartment == 'All' || item['department'] == _selectedDepartment;
      final matchesStatus = _selectedStatus == 'All' || item['status'] == _selectedStatus;

      return matchesQuery && matchesDept && matchesStatus;
    }).toList();
  }

  int get _processedCount => _payrolls.where((p) => p['status'] == 'Processed').length;
  int get _pendingCount => _payrolls.where((p) => p['status'] == 'Pending Review' || p['status'] == 'Draft').length;

  num get _totalNetPay {
    return _payrolls.fold<num>(0, (sum, p) => sum + ((p['rawNetPay'] as num?) ?? 0));
  }

  String _formatCurrency(num amount) {
    final str = amount.toInt().toString();
    final RegExp reg = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final String result = str.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₹$result';
  }

  void _exportPayrollExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exporting Payroll Sheet for $_selectedMonth to Excel...'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _exportPayslipExcel(Map<String, dynamic> item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading Payslip Excel for ${item['name']} (${item['empId']})...'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _openWorkflowModal(Map<String, dynamic> item) {
    int currentStep = 0;
    if (item['status'] == 'Pending Review') currentStep = 1;
    if (item['status'] == 'Calculated') currentStep = 2;
    if (item['status'] == 'Processed') currentStep = 3;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.all(16),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            actionsPadding: const EdgeInsets.all(12),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.alt_route, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Payroll Workflow: ${item['name']}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                  // Step Indicator Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightInputBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStepIcon(0, 'TL Approve', Icons.how_to_reg, currentStep, () => setModalState(() => currentStep = 0)),
                        _buildStepIcon(1, 'HR Verify', Icons.verified_user, currentStep, () => setModalState(() => currentStep = 1)),
                        _buildStepIcon(2, 'Calculate', Icons.calculate, currentStep, () => setModalState(() => currentStep = 2)),
                        _buildStepIcon(3, 'Disburse', Icons.payments, currentStep, () => setModalState(() => currentStep = 3)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Step Content View
                  if (currentStep == 0) _buildTLApproveStep(item, setModalState),
                  if (currentStep == 1) _buildHRVerifyStep(item, setModalState),
                  if (currentStep == 2) _buildCalculateStep(item, setModalState),
                  if (currentStep == 3) _buildDisburseStep(item, setModalState),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close Workflow'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStepIcon(int stepIdx, String title, IconData icon, int currentStep, VoidCallback onTap) {
    final isActive = currentStep == stepIdx;
    final isPassed = currentStep > stepIdx;

    Color bg = AppColors.lightInputBackground;
    Color fg = AppColors.lightSecondaryText;
    if (isActive) {
      bg = AppColors.primary;
      fg = Colors.white;
    } else if (isPassed) {
      bg = AppColors.successBg;
      fg = AppColors.success;
    }

    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: bg,
            child: Icon(isPassed ? Icons.check : icon, color: fg, size: 16),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? AppColors.primary : AppColors.lightSecondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTLApproveStep(Map<String, dynamic> item, StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Step 1: Team Lead Attendance Approval', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Verify monthly attendance logs, leave balances, & overtime.', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.lightInputBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Total Working Days:', style: TextStyle(fontSize: 12)),
                  Text('22 Days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Present Days:', style: TextStyle(fontSize: 12)),
                  Text('22 Days (100%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Overtime Logged:', style: TextStyle(fontSize: 12)),
                  Text('+8.5 Hours', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Attendance approved by Team Lead for ${item['name']}'), backgroundColor: AppColors.success),
            );
            setModalState(() {});
          },
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Approve TL Attendance'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
        ),
      ],
    );
  }

  Widget _buildHRVerifyStep(Map<String, dynamic> item, StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Step 2: HR Audit & Policy Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Review statutory compliance, LOP deductions, & bonus allowances.', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.lightInputBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Unpaid LOP Days:', style: TextStyle(fontSize: 12)),
                  Text('0 Days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Performance Bonus:', style: TextStyle(fontSize: 12)),
                  Text('+₹5,000', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('HR Audit Status:', style: TextStyle(fontSize: 12)),
                  Text('VERIFIED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('HR audit verified for ${item['name']}'), backgroundColor: AppColors.primary),
            );
            setModalState(() {});
          },
          icon: const Icon(Icons.verified, size: 16),
          label: const Text('Verify HR Compliance'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
        ),
      ],
    );
  }

  Widget _buildCalculateStep(Map<String, dynamic> item, StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Step 3: Gross-to-Net Salary Computation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Compute PF, ESI, TDS, & LOP adjustments for final Net Payable salary.', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.lightInputBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Basic Salary:', style: TextStyle(fontSize: 12)),
                  Text(item['basicSalary'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Allowances:', style: TextStyle(fontSize: 12)),
                  Text(item['allowances'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Statutory Deductions (PF/TDS):', style: TextStyle(fontSize: 12)),
                  Text(item['deductions'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error)),
                ],
              ),
              const Divider(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Computed Net Payable:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(item['netPay'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDisburseStep(Map<String, dynamic> item, StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Step 4: Finance Sign-off & Bank Disbursement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Generate NEFT/RTGS payment advice and disburse salary to bank account.', style: TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.lightInputBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Net Salary Payable:', style: TextStyle(fontSize: 12)),
                  Text(item['netPay'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Disbursement Mode:', style: TextStyle(fontSize: 12)),
                  Text('Bank Direct NEFT/RTGS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Disbursement Status:', style: TextStyle(fontSize: 12)),
                  Text(item['status'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              item['status'] = 'Processed';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Salary disbursed & payslip generated for ${item['name']}'), backgroundColor: AppColors.success),
            );
          },
          icon: const Icon(Icons.payments, size: 16),
          label: const Text('Confirm Disbursement & Pay'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    final filteredList = _filteredPayrolls;

    return RefreshIndicator(
      onRefresh: _loadPayrollData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Card
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
                        child: Icon(Icons.calculate, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Payroll & Salary Computation',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Monthly salary computation, attendance, deductions, & payslips',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Header Quick Actions
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _exportPayrollExcel,
                        icon: const Icon(Icons.table_chart_outlined, size: 16),
                        label: const Text('Export Excel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _loadPayrollData,
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Run Payroll Batch'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.darkPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stat Cards Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  label: 'Total Earnings Allocation',
                  value: _formatCurrency(3136250),
                  sub: 'Gross allocation for $_selectedMonth',
                  icon: Icons.account_balance_wallet,
                  bgColor: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                ),
                _buildStatCard(
                  label: 'Net Disbursed Pay',
                  value: _formatCurrency(_totalNetPay),
                  sub: '${_payrolls.length} Employees • $_processedCount Paid',
                  icon: Icons.payments_outlined,
                  bgColor: const Color(0xFFF0FDF4),
                  iconColor: const Color(0xFF16A34A),
                ),
                _buildStatCard(
                  label: 'Statutory Deductions',
                  value: _formatCurrency(530750),
                  sub: 'PF, ESI & Payroll TDS',
                  icon: Icons.calculate_outlined,
                  bgColor: const Color(0xFFFFF7ED),
                  iconColor: const Color(0xFFEA580C),
                ),
                _buildStatCard(
                  label: 'Pending Processing',
                  value: '$_pendingCount Records',
                  sub: '$_processedCount processed • awaiting sign-off',
                  icon: Icons.schedule,
                  bgColor: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF0284C7),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filters & Search Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search employee by name, ID, or dept...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.lightMutedText),
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.lightSecondaryText),
                      filled: true,
                      fillColor: AppColors.lightInputBackground,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      // Month Select
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedMonth,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                              style: const TextStyle(fontSize: 12, color: AppColors.lightPrimaryText, fontWeight: FontWeight.w500),
                              items: _monthOptions.map((m) {
                                return DropdownMenuItem<String>(value: m, child: Text(m));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedMonth = val);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Department Select
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedDepartment,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                              style: const TextStyle(fontSize: 12, color: AppColors.lightPrimaryText, fontWeight: FontWeight.w500),
                              items: _departmentOptions.map((d) {
                                return DropdownMenuItem<String>(value: d, child: Text(d == 'All' ? 'All Depts' : d));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedDepartment = val);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _statusOptions.map((st) {
                        final isActive = _selectedStatus == st;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              st,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isActive ? Colors.white : AppColors.lightSecondaryText,
                              ),
                            ),
                            selected: isActive,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.lightInputBackground,
                            onSelected: (_) => setState(() => _selectedStatus = st),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isActive ? AppColors.primary : Colors.grey.shade300,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Employee Payroll Breakdown Header & Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.badge_outlined, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Monthly Employee Payroll Sheet',
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
                    '${filteredList.length} Records',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (filteredList.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: const [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.lightSecondarySurface,
                        child: Icon(Icons.search_off_outlined, size: 28, color: AppColors.lightSecondaryText),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No payroll records found',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Try clearing or modifying your filter criteria.',
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
                itemCount: filteredList.length,
                itemBuilder: (context, index) {
                  final item = filteredList[index];
                  return _buildPayrollCard(item);
                },
              ),

            const SizedBox(height: 24),

            // Monthly Cycle Milestones Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.alt_route, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Monthly Processing Cycle',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      Text(
                        _selectedMonth,
                        style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  ..._milestones.map((m) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.lightInputBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (m['color'] as Color).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              m['step'] as String,
                              style: TextStyle(color: m['color'] as Color, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('${m['desc']} • ${m['date']}', style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (m['color'] as Color).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              m['status'] as String,
                              style: TextStyle(fontSize: 10, color: m['color'] as Color, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Expense Composition Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.pie_chart, color: AppColors.success, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Payroll Expense Composition',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Gross Allocation',
                          style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  _buildCompositionRow('Basic Salary & HRA', '₹ 31,36,250 (65%)', 0.65, AppColors.primary),
                  const SizedBox(height: 10),
                  _buildCompositionRow('Allowances & Bonus', '₹ 11,58,000 (24%)', 0.24, AppColors.success),
                  const SizedBox(height: 10),
                  _buildCompositionRow('Employer Statutory', '₹ 5,30,750 (11%)', 0.11, AppColors.warning),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollCard(Map<String, dynamic> item) {
    final status = item['status'] ?? 'Draft';
    final isProcessed = status == 'Processed';
    final isPending = status == 'Pending Review';

    Color statusBg = AppColors.lightInputBackground;
    Color statusFg = AppColors.lightSecondaryText;

    if (isProcessed) {
      statusBg = AppColors.successBg;
      statusFg = AppColors.success;
    } else if (isPending) {
      statusBg = AppColors.warningBg;
      statusFg = AppColors.warning;
    } else if (status == 'Calculated') {
      statusBg = AppColors.infoBg;
      statusFg = AppColors.info;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar, Name, Designation & Status
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.darkPrimary,
                  child: Text(
                    item['initials'] ?? 'PR',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        '${item['empId']} • ${item['designation']}',
                        style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusFg,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Salary Component Grid
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.lightInputBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Basic Salary', style: TextStyle(fontSize: 10, color: AppColors.lightMutedText)),
                        const SizedBox(height: 2),
                        Text(item['basicSalary'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(height: 20, width: 1, color: Colors.grey.shade300),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Allowances', style: TextStyle(fontSize: 10, color: AppColors.lightMutedText)),
                        const SizedBox(height: 2),
                        Text('+${item['allowances']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.success)),
                      ],
                    ),
                  ),
                  Container(height: 20, width: 1, color: Colors.grey.shade300),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Deductions', style: TextStyle(fontSize: 10, color: AppColors.lightMutedText)),
                        const SizedBox(height: 2),
                        Text('-${item['deductions']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.error)),
                      ],
                    ),
                  ),
                  Container(height: 20, width: 1, color: Colors.grey.shade300),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Net Pay', style: TextStyle(fontSize: 10, color: AppColors.lightMutedText)),
                        const SizedBox(height: 2),
                        Text(item['netPay'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 18),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openWorkflowModal(item),
                  icon: const Icon(Icons.calculate_outlined, size: 14),
                  label: const Text('Calculate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: () => _openWorkflowModal(item),
                  icon: const Icon(Icons.alt_route, size: 14),
                  label: const Text('Workflow'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => _exportPayslipExcel(item),
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  color: AppColors.success,
                  tooltip: 'Payslip Excel',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompositionRow(String label, String valueStr, double pct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            Text(valueStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
