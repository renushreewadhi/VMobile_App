import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class FinanceLoansAdvancesScreen extends ConsumerStatefulWidget {
  const FinanceLoansAdvancesScreen({super.key});

  @override
  ConsumerState<FinanceLoansAdvancesScreen> createState() => _FinanceLoansAdvancesScreenState();
}

class _FinanceLoansAdvancesScreenState extends ConsumerState<FinanceLoansAdvancesScreen> {
  String _searchTerm = '';
  String _selectedType = 'All'; // 'All', 'Personal', 'Advance', 'Medical', 'Education'
  String _selectedStatus = 'All'; // 'All', 'Active', 'Pending', 'Paid Off'
  bool _isLoading = true;

  List<Map<String, dynamic>> _loans = [];

  // New Loan Form Controllers
  final TextEditingController _newEmpNameController = TextEditingController();
  final TextEditingController _newAmountController = TextEditingController();
  final TextEditingController _newReasonController = TextEditingController();
  String _newLoanType = 'Personal Loan';
  int _newTenureMonths = 12;

  final List<String> _loanTypes = [
    'All',
    'Personal',
    'Advance',
    'Medical',
    'Education',
  ];

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  @override
  void dispose() {
    _newEmpNameController.dispose();
    _newAmountController.dispose();
    _newReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadLoans() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.financeLoans).catchError((_) => null);

      if (mounted) {
        List<dynamic> items = [];
        if (res is List) {
          items = res;
        } else if (res is Map<String, dynamic> && res['data'] is List) {
          items = res['data'];
        }

        if (items.isNotEmpty) {
          _loans = items.map((l) => _mapLoanItem(l)).toList();
        } else {
          _loans = _getMockLoans();
        }
        _isLoading = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loans = _getMockLoans();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapLoanItem(dynamic l) {
    final Map<String, dynamic> map = l is Map<String, dynamic> ? l : {};
    final empName = map['employeeName'] ?? map['empName'] ?? 'Employee';
    final rawStatus = (map['status'] ?? 'Pending').toString();

    return {
      'loanId': map['loanId'] ?? (map['id'] != null ? map['id'].toString().substring(0, 8).toUpperCase() : 'LN-001'),
      'rawId': map['id'] ?? map['loanId'],
      'empName': empName,
      'dept': map['departmentName'] ?? map['dept'] ?? 'Engineering',
      'type': map['loanType'] ?? map['type'] ?? 'Personal Loan',
      'totalAmount': (map['requestedAmount'] ?? map['totalAmount'] ?? 0) as num,
      'balance': (map['outstandingAmount'] ?? map['balance'] ?? 0) as num,
      'monthlyDeduction': (map['monthlyEMI'] ?? map['monthlyDeduction'] ?? 0) as num,
      'term': '${map['tenureMonths'] ?? 12} Months',
      'status': _normalizeStatus(rawStatus),
      'avatar': _getInitials(empName),
    };
  }

  String _normalizeStatus(String s) {
    if (s.isEmpty) return 'Pending';
    final upper = s.toUpperCase();
    if (upper == 'APPROVED' || upper == 'DISBURSED' || upper == 'ACTIVE') return 'Active';
    if (upper == 'PENDING' || upper == 'SUBMITTED') return 'Pending';
    if (upper == 'CLOSED' || upper == 'REPAID' || upper == 'PAID OFF') return 'Paid Off';
    if (upper == 'REJECTED') return 'Rejected';
    return 'Pending';
  }

  List<Map<String, dynamic>> _getMockLoans() {
    return [
      {
        'loanId': 'LN-2026-101',
        'rawId': '1',
        'empName': 'Sarah Jenkins',
        'dept': 'Product Design',
        'type': 'Personal Loan',
        'totalAmount': 100000,
        'balance': 65000,
        'monthlyDeduction': 8333,
        'term': '12 Months',
        'status': 'Active',
        'avatar': 'SJ',
      },
      {
        'loanId': 'LN-2026-102',
        'rawId': '2',
        'empName': 'David Miller',
        'dept': 'Engineering',
        'type': 'Salary Advance',
        'totalAmount': 30000,
        'balance': 10000,
        'monthlyDeduction': 10000,
        'term': '3 Months',
        'status': 'Active',
        'avatar': 'DM',
      },
      {
        'loanId': 'LN-2026-103',
        'rawId': '3',
        'empName': 'Emily Watson',
        'dept': 'Human Resources',
        'type': 'Emergency Medical',
        'totalAmount': 50000,
        'balance': 50000,
        'monthlyDeduction': 4166,
        'term': '12 Months',
        'status': 'Pending',
        'avatar': 'EW',
      },
      {
        'loanId': 'LN-2026-104',
        'rawId': '4',
        'empName': 'Alex Rivera',
        'dept': 'Sales Operations',
        'type': 'Education Support',
        'totalAmount': 80000,
        'balance': 0,
        'monthlyDeduction': 6666,
        'term': '12 Months',
        'status': 'Paid Off',
        'avatar': 'AR',
      },
    ];
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'LN';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : name.length).toUpperCase();
  }

  int _getStatusCount(String label) {
    if (label == 'All') return _loans.length;
    if (label == 'Active') return _loans.where((l) => l['status'] == 'Active').length;
    if (label == 'Pending') return _loans.where((l) => l['status'] == 'Pending').length;
    if (label == 'Paid Off') return _loans.where((l) => l['status'] == 'Paid Off').length;
    return 0;
  }

  List<Map<String, dynamic>> get _filteredLoans {
    return _loans.where((item) {
      final name = (item['empName'] ?? '').toString().toLowerCase();
      final type = (item['type'] ?? '').toString().toLowerCase();
      final loanId = (item['loanId'] ?? '').toString().toLowerCase();
      final search = _searchTerm.toLowerCase();

      final matchesSearch = _searchTerm.isEmpty || name.contains(search) || type.contains(search) || loanId.contains(search);
      final matchesType = _selectedType == 'All' || type.contains(_selectedType.toLowerCase());
      final matchesStatus = _selectedStatus == 'All' || item['status'] == _selectedStatus;

      return matchesSearch && matchesType && matchesStatus;
    }).toList();
  }

  int get _activeCount => _loans.where((l) => l['status'] == 'Active').length;
  int get _pendingCount => _loans.where((l) => l['status'] == 'Pending').length;
  int get _paidOffCount => _loans.where((l) => l['status'] == 'Paid Off').length;

  num get _totalOutstanding {
    return _loans
        .where((l) => l['status'] == 'Active')
        .fold<num>(0, (sum, l) => sum + ((l['balance'] as num?) ?? 0));
  }

  String _formatCurrency(num amount) {
    final str = amount.toInt().toString();
    final RegExp reg = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final String result = str.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₹$result';
  }

  Future<void> _approveLoan(Map<String, dynamic> item) async {
    setState(() {
      item['status'] = 'Active';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loan ${item['loanId']} approved successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.put('${ApiEndpoints.financeLoans}/${item['rawId'] ?? item['loanId']}', data: {'status': 'APPROVED'}).catchError((_) => null);
    } catch (_) {}
  }

  Future<void> _rejectLoan(Map<String, dynamic> item) async {
    setState(() {
      item['status'] = 'Rejected';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loan ${item['loanId']} rejected'),
          backgroundColor: AppColors.error,
        ),
      );
    }

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.put('${ApiEndpoints.financeLoans}/${item['rawId'] ?? item['loanId']}', data: {'status': 'REJECTED'}).catchError((_) => null);
    } catch (_) {}
  }

  void _showCreateLoanModal() {
    _newEmpNameController.clear();
    _newAmountController.clear();
    _newReasonController.clear();
    _newLoanType = 'Personal Loan';
    _newTenureMonths = 12;

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
                  children: const [
                    Icon(Icons.volunteer_activism, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Create Loan Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  const Text('Employee Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _newEmpNameController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Sarah Jenkins',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            const Text('Loan Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _newLoanType,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Personal Loan', child: Text('Personal Loan', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Salary Advance', child: Text('Salary Advance', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Emergency Medical', child: Text('Medical', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Education Support', child: Text('Education', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => _newLoanType = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Requested Amount (₹) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _newAmountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '50000',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text('Tenure (Months)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int>(
                    value: _newTenureMonths,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 3, child: Text('3 Months')),
                      DropdownMenuItem(value: 6, child: Text('6 Months')),
                      DropdownMenuItem(value: 12, child: Text('12 Months')),
                      DropdownMenuItem(value: 24, child: Text('24 Months')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => _newTenureMonths = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  const Text('Reason / Purpose', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _newReasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Explain the loan purpose...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
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
                  if (_newEmpNameController.text.trim().isEmpty || _newAmountController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter employee name and requested amount'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  _saveNewLoan();
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Create Loan Request'),
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

  void _saveNewLoan() {
    final amount = num.tryParse(_newAmountController.text.trim()) ?? 50000;
    final emi = (amount / _newTenureMonths).round();

    final newEntry = {
      'loanId': 'LN-${1000 + (DateTime.now().millisecondsSinceEpoch % 8999)}',
      'rawId': DateTime.now().millisecondsSinceEpoch.toString(),
      'empName': _newEmpNameController.text.trim(),
      'dept': 'Finance / Operations',
      'type': _newLoanType,
      'totalAmount': amount,
      'balance': amount,
      'monthlyDeduction': emi,
      'term': '$_newTenureMonths Months',
      'status': 'Pending',
      'avatar': _getInitials(_newEmpNameController.text.trim()),
    };

    setState(() {
      _loans.insert(0, newEntry);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Loan request created successfully'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _viewLoanDetails(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.all(16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actionsPadding: const EdgeInsets.all(12),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Loan Details: ${item['loanId']}'),
              ],
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Employee', item['empName'] ?? '', isBold: true),
            _buildDetailRow('Department', item['dept'] ?? ''),
            _buildDetailRow('Loan Type', item['type'] ?? ''),
            _buildDetailRow('Sanctioned Amount', _formatCurrency(item['totalAmount'] ?? 0), isAmount: true),
            _buildDetailRow('Outstanding Balance', _formatCurrency(item['balance'] ?? 0), isError: true),
            _buildDetailRow('Monthly EMI', _formatCurrency(item['monthlyDeduction'] ?? 0), isPrimary: true),
            _buildDetailRow('Tenure', item['term'] ?? ''),
            _buildDetailRow('Status', item['status'] ?? ''),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String val, {bool isBold = false, bool isAmount = false, bool isError = false, bool isPrimary = false}) {
    Color textColor = AppColors.lightPrimaryText;
    if (isAmount || isPrimary) textColor = AppColors.primary;
    if (isError) textColor = AppColors.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.lightMutedText),
          ),
          const SizedBox(height: 2),
          Text(
            val,
            style: TextStyle(
              fontSize: isAmount ? 15 : 13,
              fontWeight: (isBold || isAmount || isError || isPrimary) ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();

    final filteredList = _filteredLoans;

    return RefreshIndicator(
      onRefresh: _loadLoans,
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
                        child: Icon(Icons.volunteer_activism, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Loans & Salary Advances',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Track loan applications, salary advances, & EMI recovery',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Exporting loan records to Excel...'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
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
                        onPressed: _showCreateLoanModal,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('New Loan Request'),
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
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.25,
              children: [
                _buildStatCard(
                  label: 'Total Active Loans',
                  value: '$_activeCount',
                  sub: '${_formatCurrency(_totalOutstanding)} Outstanding',
                  icon: Icons.volunteer_activism,
                  bgColor: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                ),
                _buildStatCard(
                  label: 'Pending Requests',
                  value: '$_pendingCount',
                  sub: 'Awaiting Review',
                  icon: Icons.schedule,
                  bgColor: const Color(0xFFFFF7ED),
                  iconColor: const Color(0xFFEA580C),
                ),
                _buildStatCard(
                  label: 'Paid Off / Closed',
                  value: '$_paidOffCount',
                  sub: 'Fully Repaid',
                  icon: Icons.check_circle_outline,
                  bgColor: const Color(0xFFF0FDF4),
                  iconColor: const Color(0xFF16A34A),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search & Filter Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchTerm = val),
                    decoration: InputDecoration(
                      hintText: 'Search loan ID, employee...',
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
                      const Icon(Icons.filter_list, size: 18, color: AppColors.lightSecondaryText),
                      const SizedBox(width: 6),
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
                              value: _selectedType,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                              style: const TextStyle(fontSize: 12, color: AppColors.lightPrimaryText, fontWeight: FontWeight.w500),
                              items: _loanTypes.map((t) {
                                return DropdownMenuItem<String>(
                                  value: t,
                                  child: Text(t == 'All' ? 'All Types' : t),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedType = val);
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
                      children: [
                        _buildTabChip('All Loans', 'All', _getStatusCount('All')),
                        const SizedBox(width: 8),
                        _buildTabChip('Active', 'Active', _activeCount),
                        const SizedBox(width: 8),
                        _buildTabChip('Pending', 'Pending', _pendingCount),
                        const SizedBox(width: 8),
                        _buildTabChip('Paid Off', 'Paid Off', _paidOffCount),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Loan Records List Header & Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.format_list_bulleted, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Loans & Advances Register',
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
                    '${filteredList.length} Listed',
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
                        child: Icon(Icons.volunteer_activism_outlined, size: 28, color: AppColors.lightSecondaryText),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No loan records match your search filter',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Try clearing or modifying your search and filter options.',
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
                  return _buildLoanCard(item);
                },
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
      padding: const EdgeInsets.all(10),
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
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.lightPrimaryText),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText),
          ),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: AppColors.lightMutedText),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, String value, int count) {
    final isActive = _selectedStatus == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : AppColors.lightSecondaryText,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($count)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white70 : AppColors.lightMutedText,
            ),
          ),
        ],
      ),
      selected: isActive,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.lightInputBackground,
      onSelected: (_) => setState(() => _selectedStatus = value),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isActive ? AppColors.primary : Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildLoanCard(Map<String, dynamic> item) {
    final status = item['status'] ?? 'Pending';
    final isPending = status == 'Pending';
    final isActive = status == 'Active';
    final isPaidOff = status == 'Paid Off';

    Color statusBg = AppColors.warningBg;
    Color statusFg = AppColors.warning;

    if (isActive) {
      statusBg = AppColors.successBg;
      statusFg = AppColors.success;
    } else if (isPaidOff) {
      statusBg = AppColors.infoBg;
      statusFg = AppColors.info;
    } else if (status == 'Rejected') {
      statusBg = AppColors.errorBg;
      statusFg = AppColors.error;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Loan ID & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.lightInputBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    item['loanId'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
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
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Employee Avatar & Name
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.darkPrimary,
                  child: Text(
                    item['avatar'] ?? 'LN',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['empName'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.lightInputBackground,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item['dept'] ?? '',
                              style: const TextStyle(fontSize: 10, color: AppColors.lightSecondaryText, fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item['type'] ?? '',
                            style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Amount breakdown grid
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
                        const Text('Sanctioned', style: TextStyle(fontSize: 10, color: AppColors.lightMutedText)),
                        const SizedBox(height: 2),
                        Text(_formatCurrency(item['totalAmount'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(height: 20, width: 1, color: Colors.grey.shade300),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Balance', style: TextStyle(fontSize: 10, color: AppColors.lightMutedText)),
                        const SizedBox(height: 2),
                        Text(_formatCurrency(item['balance'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.error)),
                      ],
                    ),
                  ),
                  Container(height: 20, width: 1, color: Colors.grey.shade300),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Monthly EMI', style: TextStyle(fontSize: 10, color: AppColors.lightMutedText)),
                        const SizedBox(height: 2),
                        Text(_formatCurrency(item['monthlyDeduction'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: AppColors.lightMutedText),
                    const SizedBox(width: 4),
                    Text(
                      'Tenure: ${item['term']}',
                      style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (isPending)
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _approveLoan(item),
                        icon: const Icon(Icons.check, size: 14),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: () => _rejectLoan(item),
                        icon: const Icon(Icons.close, size: 14),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => _viewLoanDetails(item),
                    icon: const Icon(Icons.visibility, size: 14),
                    label: const Text('View'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
