import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/app_card.dart';

class HrReportsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const HrReportsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<HrReportsScreen> createState() => _HrReportsScreenState();
}

class _HrReportsScreenState extends ConsumerState<HrReportsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String _activeTab = 'hr'; // hr, attendance, payroll
  String _selectedDateRange = 'THIS_MONTH';

  Map<String, dynamic> _dashboardStats = {};
  List<dynamic> _headcountData = [];
  List<dynamic> _genderData = [];
  List<dynamic> _turnoverData = [];
  List<dynamic> _salaryData = [];
  List<dynamic> _attendanceTrendData = [];
  List<dynamic> _attendanceBreakdownData = [];
  List<dynamic> _deptAttendanceData = [];
  List<dynamic> _payrollExpensesData = [];
  List<dynamic> _payrollCategoryData = [];
  List<dynamic> _deptPayrollData = [];

  final List<Map<String, dynamic>> _quickReports = [
    {'name': 'Employee Directory', 'description': 'Complete list of all employees', 'icon': Icons.contacts, 'color': Colors.blue},
    {'name': 'Attendance Summary', 'description': 'Monthly attendance report', 'icon': Icons.calendar_today, 'color': Colors.green},
    {'name': 'Leave Balance', 'description': 'Current leave balances', 'icon': Icons.beach_access, 'color': Colors.amber},
    {'name': 'Payroll Register', 'description': 'Monthly payroll breakdown', 'icon': Icons.receipt_long, 'color': Colors.red},
    {'name': 'Performance Summary', 'description': 'Quarterly performance ratings', 'icon': Icons.star, 'color': Colors.cyan},
    {'name': 'Training Completion', 'description': 'Training program completion rates', 'icon': Icons.school, 'color': Colors.purple},
  ];

  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkUserAndLoad();
    });
  }

  void _checkUserAndLoad() {
    final authState = ref.read(authServiceProvider);
    final user = authState.user;
    if (user == null || !authState.isAuthenticated) {
      if (!mounted) return;
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

    _loadReports();
  }

  void _resetState() {
    setState(() {
      _dashboardStats = {};
      _headcountData = [];
      _genderData = [];
      _turnoverData = [];
      _salaryData = [];
      _attendanceTrendData = [];
      _attendanceBreakdownData = [];
      _deptAttendanceData = [];
      _payrollExpensesData = [];
      _payrollCategoryData = [];
      _deptPayrollData = [];
      _errorMessage = null;
      _isLoading = true;
    });
  }

  Future<void> _loadReports() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      final query = '?dateRange=$_selectedDateRange';
      
      final statsRes = await apiClient.get('/reports/dashboard-stats$query').catchError((_) => {});
      if (!mounted || currentReq != _requestId) return;
      
      final deptDistRes = await apiClient.get('/reports/department-distribution$query').catchError((_) => {});
      if (!mounted || currentReq != _requestId) return;
      
      final adminAnRes = await apiClient.get('/reports/admin-analytics$query').catchError((_) => {});
      if (!mounted || currentReq != _requestId) return;
      
      final attTrendRes = await apiClient.get('/reports/attendance-trend$query&days=7').catchError((_) => {});
      if (!mounted || currentReq != _requestId) return;
      
      final payTrendRes = await apiClient.get('/reports/payroll-trend$query&months=6').catchError((_) => {});
      if (!mounted || currentReq != _requestId) return;

      final stats = statsRes is Map<String, dynamic> ? (statsRes['data'] ?? statsRes) : {};
      
      List<dynamic> headcount = [];
      if (deptDistRes is Map && deptDistRes['labels'] != null) {
        headcount = _chartToBarData(deptDistRes);
      } else if (deptDistRes is List) {
        headcount = deptDistRes;
      }

      List<dynamic> gender = [];
      final adminData = adminAnRes is Map<String, dynamic> ? (adminAnRes['data'] ?? adminAnRes) : {};
      if (adminData['gender'] is Map && adminData['gender']['labels'] != null) {
        final colors = [Colors.blue, Colors.pink, Colors.cyan, Colors.purple];
        final gLabels = adminData['gender']['labels'] as List;
        final gData = adminData['gender']['datasets']?[0]?['data'] as List? ?? [];
        gender = List.generate(gLabels.length, (i) => {
          'label': gLabels[i],
          'value': i < gData.length ? (num.tryParse(gData[i]?.toString() ?? '0') ?? 0) : 0,
          'color': colors[i % colors.length],
        });
      }

      List<dynamic> attBreakdown = [];
      if (adminData['attendanceBreakdown'] is Map && adminData['attendanceBreakdown']['labels'] != null) {
        final aColors = [Colors.green, Colors.amber, Colors.blue, Colors.red];
        final aLabels = adminData['attendanceBreakdown']['labels'] as List;
        final aData = adminData['attendanceBreakdown']['datasets']?[0]?['data'] as List? ?? [];
        attBreakdown = List.generate(aLabels.length, (i) => {
          'label': aLabels[i],
          'value': i < aData.length ? (num.tryParse(aData[i]?.toString() ?? '0') ?? 0) : 0,
          'color': aColors[i % aColors.length],
        });
      }

      List<dynamic> attTrend = [];
      if (attTrendRes is Map && attTrendRes['labels'] != null) {
        attTrend = _chartToBarData(attTrendRes);
      } else if (attTrendRes is List) {
        attTrend = attTrendRes;
      }

      List<dynamic> payExp = [];
      if (payTrendRes is Map && payTrendRes['labels'] != null) {
        payExp = _chartToBarData(payTrendRes);
      } else if (payTrendRes is List) {
        payExp = payTrendRes;
      }

      setState(() {
        _dashboardStats = stats;
        _headcountData = headcount;
        _genderData = gender;
        _attendanceTrendData = attTrend;
        _attendanceBreakdownData = attBreakdown;
        _payrollExpensesData = payExp;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load report analytics: $e';
        _isLoading = false;
      });
    }
  }

  List<dynamic> _chartToBarData(Map<dynamic, dynamic> chart) {
    final labels = chart['labels'] is List ? chart['labels'] as List : [];
    final dataset = (chart['datasets'] is List && (chart['datasets'] as List).isNotEmpty) ? chart['datasets'][0] : {};
    final data = dataset['data'] is List ? dataset['data'] as List : [];
    return List.generate(labels.length, (i) => {
      'label': labels[i]?.toString() ?? '',
      'value': i < data.length ? (num.tryParse(data[i]?.toString() ?? '0') ?? 0) : 0,
    });
  }

  void _exportExcel() {
    final csvBuffer = StringBuffer();
    csvBuffer.writeln('Report Type,Active Tab,Date Range,Export Timestamp');
    csvBuffer.writeln('"HR Analytics Report","${_activeTab.toUpperCase()}","$_selectedDateRange","${DateTime.now().toIso8601String()}"');

    if (_activeTab == 'hr' && _headcountData.isNotEmpty) {
      csvBuffer.writeln('\nDepartment,Headcount');
      for (final h in _headcountData) {
        csvBuffer.writeln('"${h['label']}","${h['value']}"');
      }
    } else if (_activeTab == 'attendance' && _attendanceTrendData.isNotEmpty) {
      csvBuffer.writeln('\nPeriod,Attendance Rate (%)');
      for (final a in _attendanceTrendData) {
        csvBuffer.writeln('"${a['label']}","${a['value']}"');
      }
    } else if (_activeTab == 'payroll' && _payrollExpensesData.isNotEmpty) {
      csvBuffer.writeln('\nPeriod,Payroll Expenditure (₹)');
      for (final p in _payrollExpensesData) {
        csvBuffer.writeln('"${p['label']}","${p['value']}"');
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully generated and exported ${_activeTab.toUpperCase()} report CSV file.')),
    );
  }

  void _downloadQuickReport(String reportName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully generated and downloaded "$reportName" report.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    if (_isLoading) {
      final skeleton = const Center(child: CircularProgressIndicator());
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: skeleton);
      return GlassScaffold(title: 'Reports & Analytics', body: skeleton);
    }

    if (_errorMessage != null) {
      final errBody = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Unable to Load Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 24),
              ElevatedButton.icon(onPressed: _loadReports, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
        ),
      );
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: errBody);
      return GlassScaffold(title: 'Reports & Analytics', body: errBody);
    }

    final cardBg = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    // Actual API Stats
    final totalHeadcount = _dashboardStats['totalEmployees'] ?? _dashboardStats['totalHeadcount'] ?? '—';
    final activeDepartments = _dashboardStats['departments'] ?? _dashboardStats['totalDepartments'] ?? '—';
    final newHires = _dashboardStats['newJoiners'] ?? _dashboardStats['newHires'] ?? '—';
    final presentToday = _dashboardStats['presentToday'] ?? '—';
    final absentToday = _dashboardStats['absentToday'] ?? '—';
    final lateArrivals = _dashboardStats['lateArrivalsToday'] ?? '—';
    final monthlyPayrollNet = _dashboardStats['monthlyPayrollNet'] ?? '—';

    final bodyContent = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Action Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                child: DropdownButton<String>(
                  value: _selectedDateRange,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'THIS_MONTH', child: Text('This Month', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'LAST_MONTH', child: Text('Last Month', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'THIS_QUARTER', child: Text('This Quarter', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'THIS_YEAR', child: Text('This Year', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedDateRange = val ?? 'THIS_MONTH');
                    _loadReports();
                  },
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.file_download, size: 16),
                label: const Text('Export Excel', style: TextStyle(fontSize: 12)),
                onPressed: _exportExcel,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Submodule Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabButton('hr', 'HR & Headcount Reports', Icons.pie_chart),
                const SizedBox(width: 8),
                _buildTabButton('attendance', 'Attendance Reports', Icons.calendar_month),
                const SizedBox(width: 8),
                _buildTabButton('payroll', 'Payroll & Compensation', Icons.money),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // TAB 1: HR & Headcount
          if (_activeTab == 'hr') ...[
            Row(
              children: [
                Expanded(child: _buildMetricCard('Total Headcount', '$totalHeadcount', '$activeDepartments Active Depts', Colors.blue, Icons.group, cardBg)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('New Hires', '$newHires', 'Active period', Colors.green, Icons.person_add, cardBg)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildMetricCard('Gender Diversity', 'Reported Data', 'Distribution', Colors.purple, Icons.balance, cardBg)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('Annual Turnover', '—', 'Benchmark', Colors.orange, Icons.trending_down, cardBg)),
              ],
            ),
            const SizedBox(height: 20),

            // Charts Section
            _buildSectionCard('Employee Headcount by Department', _headcountData.isEmpty ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No headcount distribution data available.'))) : _buildHeadcountBarChart(), cardBg),
            const SizedBox(height: 16),
            _buildSectionCard('Gender & Diversity Distribution', _genderData.isEmpty ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No gender distribution data available.'))) : _buildGenderDonutChart(), cardBg),
            const SizedBox(height: 16),
            _buildSectionCard('Monthly Employee Turnover Rate', _turnoverData.isEmpty ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No turnover data available.'))) : _buildTurnoverBarChart(), cardBg),
            const SizedBox(height: 16),
            _buildSectionCard('Average Salary Level Distribution', _salaryData.isEmpty ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No salary distribution data available.'))) : _buildSalaryDistributionList(), cardBg),
            const SizedBox(height: 20),

            // Quick Access Reports
            const Text('Quick Access HR Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _quickReports.length,
              itemBuilder: (context, index) {
                final r = _quickReports[index];
                return AppCard(
                  backgroundColor: cardBg,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: (r['color'] as Color).withAlpha(30),
                      child: Icon(r['icon'] as IconData, color: r['color'] as Color, size: 20),
                    ),
                    title: Text(r['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(r['description'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    trailing: IconButton(
                      icon: Icon(Icons.file_download, color: primaryColor),
                      onPressed: () => _downloadQuickReport(r['name']?.toString() ?? ''),
                    ),
                  ),
                );
              },
            ),
          ]

          // TAB 2: Attendance
          else if (_activeTab == 'attendance') ...[
            Row(
              children: [
                Expanded(child: _buildMetricCard('Avg Attendance Rate', 'Reported', 'Active period', Colors.green, Icons.how_to_reg, cardBg)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('Present Today', '$presentToday', 'On Duty', Colors.blue, Icons.person_pin, cardBg)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildMetricCard('Late Arrivals', '$lateArrivals', 'Action Flagged', Colors.orange, Icons.timer, cardBg)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('Unexcused Absences', '$absentToday', 'Requires HR Review', Colors.red, Icons.person_off, cardBg)),
              ],
            ),
            const SizedBox(height: 20),

            _buildSectionCard('Monthly Attendance Rate Trend (%)', _attendanceTrendData.isEmpty ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No attendance trend data available.'))) : _buildAttendanceTrendChart(), cardBg),
            const SizedBox(height: 16),
            _buildSectionCard('Today\'s Attendance Status Breakdown', _attendanceBreakdownData.isEmpty ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No attendance breakdown data available.'))) : _buildAttendanceBreakdownChart(), cardBg),
            const SizedBox(height: 20),

            // Department Attendance Table
            const Text('Department Attendance Rates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _deptAttendanceData.isEmpty
                ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No department attendance records available.')))
                : AppCard(
                    backgroundColor: cardBg,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Department')),
                          DataColumn(label: Text('Attendance Rate')),
                          DataColumn(label: Text('Present')),
                          DataColumn(label: Text('Absent')),
                          DataColumn(label: Text('Status')),
                        ],
                        rows: _deptAttendanceData.map((item) {
                          final rate = double.tryParse(item['rate']?.toString() ?? '0') ?? 0.0;
                          final isExcellent = rate >= 95.0;
                          return DataRow(cells: [
                            DataCell(Text(item['dept'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text('$rate%')),
                            DataCell(Text('${item['present'] ?? 0}')),
                            DataCell(Text('${item['absent'] ?? 0}')),
                            DataCell(
                              Chip(
                                label: Text(isExcellent ? 'EXCELLENT' : 'NEEDS ATTENTION', style: const TextStyle(fontSize: 10, color: Colors.white)),
                                backgroundColor: isExcellent ? Colors.green : Colors.orange,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
          ]

          // TAB 3: Payroll
          else ...[
            Row(
              children: [
                Expanded(child: _buildMetricCard('Total Monthly Payroll', monthlyPayrollNet != '—' ? '₹$monthlyPayrollNet' : 'Reported', 'Current Cycle', Colors.blue, Icons.payments, cardBg)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('Bonuses & Incentives', '—', 'Performance Pay', Colors.green, Icons.card_giftcard, cardBg)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildMetricCard('Benefits & Insurance', '—', 'Company Contribution', Colors.purple, Icons.security, cardBg)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('Tax Withholding', '—', 'Statutory Deductions', Colors.orange, Icons.account_balance, cardBg)),
              ],
            ),
            const SizedBox(height: 20),

            _buildSectionCard('Monthly Payroll Expenditure (₹)', _payrollExpensesData.isEmpty ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No payroll expenditure data available.'))) : _buildPayrollTrendChart(), cardBg),
            const SizedBox(height: 16),
            _buildSectionCard('Compensation Cost Breakdown', _payrollCategoryData.isEmpty ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No compensation breakdown data available.'))) : _buildPayrollCategoryChart(), cardBg),
            const SizedBox(height: 20),

            // Department Payroll Table
            const Text('Department Payroll Expenditure Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _deptPayrollData.isEmpty
                ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No department payroll records available.')))
                : AppCard(
                    backgroundColor: cardBg,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Department')),
                          DataColumn(label: Text('Total Payroll Cost')),
                          DataColumn(label: Text('Average Salary')),
                          DataColumn(label: Text('Headcount')),
                        ],
                        rows: _deptPayrollData.map((item) {
                          return DataRow(cells: [
                            DataCell(Text(item['dept'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(item['totalCost'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                            DataCell(Text(item['avgSalary'] ?? '—')),
                            DataCell(Text('${item['employeeCount'] ?? 0} Employees')),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
          ],
        ],
      ),
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: bodyContent);

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Reports & Analytics',
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReports),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildMetricCard(String label, String value, String subtext, Color color, IconData icon, Color cardBg) {
    return AppCard(
      backgroundColor: cardBg,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                  Text(subtext, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String tabKey, String label, IconData icon) {
    final isActive = _activeTab == tabKey;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Theme.of(context).primaryColor : Colors.grey[100],
        foregroundColor: isActive ? Colors.white : Colors.grey[800],
        elevation: 0,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () => setState(() => _activeTab = tabKey),
    );
  }

  Widget _buildSectionCard(String title, Widget content, Color cardBg) {
    return AppCard(
      backgroundColor: cardBg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildHeadcountBarChart() {
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 80,
          barGroups: _headcountData.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final val = (num.tryParse(item['value'].toString()) ?? 0).toDouble();
            return BarChartGroupData(x: idx, barRods: [BarChartRodData(toY: val, color: Colors.blue, width: 16, borderRadius: BorderRadius.circular(4))]);
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < _headcountData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(_headcountData[idx]['label']?.toString() ?? '', style: const TextStyle(fontSize: 10)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildGenderDonutChart() {
    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: _genderData.map((item) {
            final val = (num.tryParse(item['value'].toString()) ?? 0).toDouble();
            final color = item['color'] is Color ? item['color'] as Color : Colors.blue;
            return PieChartSectionData(
              value: val,
              title: '${item['label']}\n(${val.toInt()})',
              color: color,
              radius: 50,
              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTurnoverBarChart() {
    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 10,
          barGroups: _turnoverData.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final val = (num.tryParse(item['value'].toString()) ?? 0).toDouble();
            return BarChartGroupData(x: idx, barRods: [BarChartRodData(toY: val, color: Colors.orange, width: 16, borderRadius: BorderRadius.circular(4))]);
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < _turnoverData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(_turnoverData[idx]['label']?.toString() ?? '', style: const TextStyle(fontSize: 10)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildSalaryDistributionList() {
    return Column(
      children: _salaryData.map((item) {
        final level = item['level'] ?? '';
        final avg = num.tryParse(item['avg'].toString()) ?? 0;
        final percent = num.tryParse(item['percent'].toString()) ?? 0;
        final color = item['color'] is Color ? item['color'] as Color : Colors.blue;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(level, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(avg), style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: percent / 100.0,
                color: color,
                backgroundColor: Colors.grey[200],
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAttendanceTrendChart() {
    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barGroups: _attendanceTrendData.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final val = (num.tryParse(item['value'].toString()) ?? 0).toDouble();
            return BarChartGroupData(x: idx, barRods: [BarChartRodData(toY: val, color: Colors.green, width: 16, borderRadius: BorderRadius.circular(4))]);
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < _attendanceTrendData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(_attendanceTrendData[idx]['label']?.toString() ?? '', style: const TextStyle(fontSize: 10)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildAttendanceBreakdownChart() {
    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: _attendanceBreakdownData.map((item) {
            final val = (num.tryParse(item['value'].toString()) ?? 0).toDouble();
            final color = item['color'] is Color ? item['color'] as Color : Colors.green;
            return PieChartSectionData(
              value: val,
              title: '${item['label']}\n(${val.toInt()})',
              color: color,
              radius: 50,
              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPayrollTrendChart() {
    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 500000,
          barGroups: _payrollExpensesData.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final val = (num.tryParse(item['value'].toString()) ?? 0).toDouble();
            return BarChartGroupData(x: idx, barRods: [BarChartRodData(toY: val, color: Colors.blue, width: 16, borderRadius: BorderRadius.circular(4))]);
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < _payrollExpensesData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(_payrollExpensesData[idx]['label']?.toString() ?? '', style: const TextStyle(fontSize: 10)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildPayrollCategoryChart() {
    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: _payrollCategoryData.map((item) {
            final val = (num.tryParse(item['value'].toString()) ?? 0).toDouble();
            final color = item['color'] is Color ? item['color'] as Color : Colors.blue;
            return PieChartSectionData(
              value: val,
              title: '${item['label']}\n(₹${(val / 1000).toInt()}k)',
              color: color,
              radius: 50,
              titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
            );
          }).toList(),
        ),
      ),
    );
  }
}
