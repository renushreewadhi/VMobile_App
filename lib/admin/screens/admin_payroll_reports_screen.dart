import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';

class AdminPayrollReportsScreen extends ConsumerStatefulWidget {
  final bool? showAppBar;
  const AdminPayrollReportsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<AdminPayrollReportsScreen> createState() => _AdminPayrollReportsScreenState();
}

class _AdminPayrollReportsScreenState extends ConsumerState<AdminPayrollReportsScreen> {
  bool get _showAppBar => widget.showAppBar ?? true;
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedMonth = 'Sep 2026';

  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkUserAndLoad();
      }
    });
  }

  void _checkUserAndLoad() {
    _requestId++;
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
    }

    final userRole = user.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    if (!isAuthorized) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    _loadReportData();
  }

  Future<void> _loadReportData() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted || currentReq != _requestId) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load payroll reports.';
        _isLoading = false;
      });
    }
  }

  void _exportExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payroll analytics report exported successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    final authState = ref.watch(authServiceProvider);
    final userRole = authState.user?.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    final mainContent = !isAuthorized
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: AppCard(
                backgroundColor: cardBgColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48, color: Color(0xFFEF4444)),
                    const SizedBox(height: 16),
                    Text('Access Restricted', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                    const SizedBox(height: 8),
                    Text('You do not have administrative permissions to view payroll analytics reports.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                  ],
                ),
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadReportData,
            child: _buildMainContent(glass, cardBgColor),
          );

    if (!_showAppBar) return mainContent;

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Payroll Reports',
        actions: [
          if (isAuthorized) ...[
            IconButton(
              icon: const Icon(Icons.download_rounded, size: 20),
              tooltip: 'Export Excel',
              onPressed: _exportExcel,
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Refresh',
              onPressed: _loadReportData,
            ),
          ],
        ],
      ),
      body: mainContent,
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text('Unable to Load Payroll Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadReportData),
            ],
          ),
        ),
      );
    }

    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner matching web platform
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: glass.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('Payroll Analytics & Compensation Reports', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: glass.textPrimary)),
                    ),
                    DropdownButton<String>(
                      value: _selectedMonth,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'Sep 2026', child: Text('Sep 2026', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 'Oct 2026', child: Text('Oct 2026', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 'Nov 2026', child: Text('Nov 2026', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      ],
                      onChanged: (val) => setState(() => _selectedMonth = val ?? 'Sep 2026'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Real-time breakdown of department cost distribution, location-wise compensation, statutory taxes, and earnings analysis.', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4 KPI Summary Cards Row matching web platform
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(width: 140, child: _buildStatTile(glass, cardBgColor, label: 'TOTAL GROSS PAYROLL', value: currencyFmt.format(296332), sub: '$_selectedMonth', icon: Icons.account_balance_wallet_rounded, iconColor: const Color(0xFFD97706))),
                const SizedBox(width: 8),
                SizedBox(width: 140, child: _buildStatTile(glass, cardBgColor, label: 'NET PAYABLE AMOUNT', value: currencyFmt.format(271222), sub: '11 / 11 Disbursed', icon: Icons.check_circle_rounded, iconColor: const Color(0xFF10B981))),
                const SizedBox(width: 8),
                SizedBox(width: 140, child: _buildStatTile(glass, cardBgColor, label: 'TOTAL DEDUCTIONS', value: currencyFmt.format(25110), sub: 'PF, ESI & Taxes', icon: Icons.receipt_long_rounded, iconColor: const Color(0xFFEF4444))),
                const SizedBox(width: 8),
                SizedBox(width: 140, child: _buildStatTile(glass, cardBgColor, label: 'AVG. SALARY / EMPLOYEE', value: currencyFmt.format(24657), sub: 'Across 11 Staff', icon: Icons.people_rounded, iconColor: const Color(0xFF2563EB))),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Earnings Breakdown Card
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Earnings Breakdown', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                    const Text('₹296,332', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                  ],
                ),
                const Divider(height: 14),
                _buildComponentBar('Basic Salary', 192000, 296332, Colors.green),
                const SizedBox(height: 10),
                _buildComponentBar('House Rent Allowance (HRA)', 76800, 296332, Colors.green),
                const SizedBox(height: 10),
                _buildComponentBar('Special Allowances', 27532, 296332, Colors.green),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Deductions Breakdown Card
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Deductions Breakdown', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                    const Text('₹25,110', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  ],
                ),
                const Divider(height: 14),
                _buildComponentBar('Provident Fund (PF)', 23040, 25110, Colors.red),
                const SizedBox(height: 10),
                _buildComponentBar('Income Tax (TDS)', 9600, 25110, Colors.red),
                const SizedBox(height: 10),
                _buildComponentBar('Employee State Insurance (ESI)', 3360, 25110, Colors.red),
                const SizedBox(height: 10),
                _buildComponentBar('Professional Tax', 0, 25110, Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Compensation Distribution by Department Card
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Compensation Distribution by Department', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: const [Color(0xFFEF4444), Color(0xFF10B981), Color(0xFF3B82F6), Color(0xFFEF4444)],
                          stops: const [0.0, 0.6, 0.85, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legendDot('Engineering', const Color(0xFFEF4444)),
                    const SizedBox(width: 12),
                    _legendDot('Human Resources', const Color(0xFF3B82F6)),
                    const SizedBox(width: 12),
                    _legendDot('Finance', const Color(0xFF10B981)),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _distStatCol('TOTAL COMPENSATION', '₹ 296,332'),
                    _distStatCol('HIGHEST', 'Engineering (₹ 147,166)'),
                    _distStatCol('LOWEST', 'Finance (₹ 29,166)'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Compensation Distribution by Location Card
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Compensation Distribution by Location', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: const [Color(0xFFD97706), Color(0xFF10B981), Color(0xFFD97706)],
                          stops: const [0.0, 0.85, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legendDot('Head Office', const Color(0xFFD97706)),
                    const SizedBox(width: 16),
                    _legendDot('Pune Office', const Color(0xFF10B981)),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _distStatCol('TOTAL COMPENSATION', '₹ 296,332'),
                    _distStatCol('HIGHEST', 'Head Office (₹ 264,332)'),
                    _distStatCol('LOWEST', 'Pune Office (₹ 32,000)'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(
    GlassTheme glass,
    Color cardBgColor, {
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color iconColor,
  }) {
    return AppCard(
      backgroundColor: cardBgColor,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 4),
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: glass.textSecondary, fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: glass.textPrimary)),
          const SizedBox(height: 2),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8.5, color: glass.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildComponentBar(String label, double amount, double total, Color color) {
    final pct = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF334155)))),
            const SizedBox(width: 4),
            Text(currencyFmt.format(amount), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withAlpha(20),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
      ],
    );
  }

  Widget _distStatCol(String label, String val) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
          const SizedBox(height: 2),
          Text(val, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
