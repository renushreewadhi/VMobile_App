import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../shared/widgets/status_chip.dart';

class AdminBenefitsManagementScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const AdminBenefitsManagementScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<AdminBenefitsManagementScreen> createState() => _AdminBenefitsManagementScreenState();
}

class _AdminBenefitsManagementScreenState extends ConsumerState<AdminBenefitsManagementScreen> {
  bool _isLoading = true;
  String _currentTab = 'list'; // 'list', 'claims', 'create'
  String _searchQuery = '';

  // Stats
  int _totalBenefits = 3;
  int _publishedCount = 2;
  int _draftCount = 0;
  int _activeEnrollments = 4;
  int _pendingClaims = 0;
  double _totalClaimsValue = 9800;

  List<dynamic> _benefits = [];
  List<dynamic> _claims = [];

  // Create Benefit Form Controllers
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Health Insurance');
  final _providerController = TextEditingController();
  final _premiumTypeController = TextEditingController(text: 'Company Paid');
  final _coverageController = TextEditingController();
  final _costController = TextEditingController();
  final _effectiveDateController = TextEditingController(text: 'Apr 17, 2026');
  final _expiryDateController = TextEditingController(text: 'Apr 17, 2027');
  final _maxClaimsController = TextEditingController(text: '1');
  final _descriptionController = TextEditingController();
  bool _approvalRequired = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _providerController.dispose();
    _premiumTypeController.dispose();
    _coverageController.dispose();
    _costController.dispose();
    _effectiveDateController.dispose();
    _expiryDateController.dispose();
    _maxClaimsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final apiClient = ref.read(apiClientProvider);

    try {
      dynamic res;
      dynamic claimsRes;
      try {
        res = await apiClient.get('/benefits').timeout(const Duration(seconds: 4));
      } catch (_) {
        res = null;
      }

      try {
        claimsRes = await apiClient.get('/benefits/claims').timeout(const Duration(seconds: 4));
      } catch (_) {
        claimsRes = null;
      }

      if (res != null) {
        dynamic data = res is Map ? (res['items'] ?? res['data'] ?? res) : res;
        if (data is List) {
          _benefits = data;
        }
      }

      if (claimsRes != null) {
        dynamic claimsData = claimsRes is Map ? (claimsRes['items'] ?? claimsRes['data'] ?? claimsRes) : claimsRes;
        if (claimsData is List) {
          _claims = claimsData;
        }
      }
    } catch (_) {}

    if (_benefits.isEmpty) {
      _benefits = [
        {
          'id': 'b-1',
          'name': 'Travel & Commute Allowance',
          'category': 'Travel',
          'provider': 'HRM Operations',
          'status': 'PUBLISHED',
          'coverageAmount': 25000,
          'premiumType': 'Company Paid',
          'effectiveDate': 'Apr 17, 2026',
          'code': 'TRV-ALLW',
        },
        {
          'id': 'b-2',
          'name': 'Wellness & Gym Subsidy',
          'category': 'Wellness',
          'provider': 'Cult.Fit',
          'status': 'ARCHIVED',
          'coverageAmount': 15000,
          'premiumType': 'Shared',
          'effectiveDate': 'Apr 17, 2026',
          'code': 'WELL-GYM',
        },
        {
          'id': 'b-3',
          'name': 'Health & Medical Insurance',
          'category': 'Health Insurance',
          'provider': 'Star Health Insurance',
          'status': 'PUBLISHED',
          'coverageAmount': 50000,
          'premiumType': 'Company Paid',
          'effectiveDate': 'Apr 17, 2026',
          'code': 'HLTH-INS',
        },
      ];
    }

    if (_claims.isEmpty) {
      _claims = [
        {
          'id': 'c-1',
          'employeeName': 'Ravi two',
          'benefitName': 'Wellness & Gym Subsidy',
          'code': 'WELL-GYM',
          'amount': 1800,
          'description': 'Annual gym membership reimbursement',
          'date': 'Oct 16, 2026',
          'submitted': 'Oct 15, 2026',
          'status': 'TL Approved',
          'reviewedBy': 'Praveen Singh',
        },
        {
          'id': 'c-2',
          'employeeName': 'Ravi two',
          'benefitName': 'Health & Medical Insurance',
          'code': 'HLTH-INS',
          'amount': 3500,
          'description': 'OPD Medical prescription claim',
          'date': 'Oct 15, 2026',
          'submitted': 'Oct 14, 2026',
          'status': 'HR Verified',
          'reviewedBy': 'Prachi Natali',
        },
        {
          'id': 'c-3',
          'employeeName': 'Ravi Vishwakarma',
          'benefitName': 'Travel & Commute Allowance',
          'code': 'TRV-ALLW',
          'amount': 4500,
          'description': 'Client site travel reimbursement',
          'date': 'Oct 12, 2026',
          'submitted': 'Oct 11, 2026',
          'status': 'Paid',
          'reviewedBy': 'Prachi Natali',
        },
      ];
    }

    if (!mounted) return;
    setState(() {
      _totalBenefits = _benefits.length;
      _publishedCount = _benefits.where((b) => (b['status'] ?? '').toString().toUpperCase() == 'PUBLISHED').length;
      _draftCount = _benefits.where((b) => (b['status'] ?? '').toString().toUpperCase() == 'DRAFT').length;
      _activeEnrollments = 4;
      _pendingClaims = _claims.where((c) => (c['status'] ?? '').toString().toUpperCase().contains('PENDING')).length;
      _isLoading = false;
    });
  }

  Future<void> _createBenefit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Benefit name is required.'), backgroundColor: Colors.red));
      return;
    }

    final payload = {
      'name': name,
      'category': _categoryController.text,
      'provider': _providerController.text.trim(),
      'premiumType': _premiumTypeController.text,
      'coverageAmount': double.tryParse(_coverageController.text) ?? 10000,
      'cost': double.tryParse(_costController.text) ?? 0,
      'effectiveDate': _effectiveDateController.text,
      'expiryDate': _expiryDateController.text,
      'maxClaimsPerYear': int.tryParse(_maxClaimsController.text) ?? 1,
      'requiresApproval': _approvalRequired,
      'description': _descriptionController.text.trim(),
    };

    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post('/benefits', body: payload);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Benefit created successfully!'), backgroundColor: Colors.green));
      setState(() => _currentTab = 'list');
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create benefit: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header Banner with Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Benefits Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                            const SizedBox(height: 2),
                            Text('Manage company employee benefits, coverage, enrollments & claims', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (_currentTab != 'list')
                            OutlinedButton.icon(
                              icon: const Icon(Icons.arrow_back, size: 16),
                              label: const Text('Back', style: TextStyle(fontSize: 12)),
                              onPressed: () => setState(() => _currentTab = 'list'),
                            )
                          else ...[
                            ElevatedButton.icon(
                              icon: const Icon(Icons.fact_check_outlined, size: 16),
                              label: const Text('Review Claims', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF475569), foregroundColor: Colors.white),
                              onPressed: () => setState(() => _currentTab = 'claims'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Create Benefit', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6B66), foregroundColor: Colors.white),
                              onPressed: () => setState(() => _currentTab = 'create'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 6 KPI Summary Cards Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatCard(glass, cardBgColor, 'Total Benefits', '$_totalBenefits', Icons.card_giftcard, const Color(0xFF2563EB)),
                        _buildStatCard(glass, cardBgColor, 'Published', '$_publishedCount', Icons.check_circle_outline, const Color(0xFF10B981)),
                        _buildStatCard(glass, cardBgColor, 'Draft', '$_draftCount', Icons.edit_note, const Color(0xFFF59E0B)),
                        _buildStatCard(glass, cardBgColor, 'Active Enrollments', '$_activeEnrollments', Icons.group_outlined, const Color(0xFF8B5CF6)),
                        _buildStatCard(glass, cardBgColor, 'Pending Claims', '$_pendingClaims', Icons.hourglass_empty, const Color(0xFFD97706)),
                        _buildStatCard(glass, cardBgColor, 'Total Claims Value', '₹${_totalClaimsValue.toStringAsFixed(0)}', Icons.currency_rupee, const Color(0xFFEC4899)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_currentTab == 'list') ...[
                    // Search & Filters Bar
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search benefits by name, provider, code...',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              filled: true,
                              fillColor: cardBgColor,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glass.cardBorder)),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Benefits Grid / Cards
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _benefits.length,
                      itemBuilder: (ctx, idx) {
                        final b = _benefits[idx];
                        final name = b['name'] ?? 'Benefit Plan';
                        final provider = b['provider'] ?? 'HRM Operations';
                        final status = b['status'] ?? 'PUBLISHED';
                        final coverage = b['coverageAmount'] ?? 25000;
                        final premiumType = b['premiumType'] ?? 'Company Paid';
                        final effectiveDate = b['effectiveDate'] ?? 'Apr 17, 2026';
                        final code = b['code'] ?? 'BEN-01';

                        return AppCard(
                          backgroundColor: cardBgColor,
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.card_giftcard_rounded, size: 18, color: Color(0xFF0F6B66)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: status == 'PUBLISHED' ? Colors.green.withAlpha(30) : Colors.grey.withAlpha(30),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: status == 'PUBLISHED' ? Colors.green : Colors.grey)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(provider, style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Coverage', style: TextStyle(fontSize: 10, color: glass.textSecondary)),
                                      const SizedBox(height: 2),
                                      Text('₹$coverage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Premium Type', style: TextStyle(fontSize: 10, color: glass.textSecondary)),
                                      const SizedBox(height: 2),
                                      Text(premiumType, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Effective Date', style: TextStyle(fontSize: 10, color: glass.textSecondary)),
                                      const SizedBox(height: 2),
                                      Text(effectiveDate, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.grey.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                                    child: Text(code, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: glass.textSecondary)),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                        onPressed: () {
                                          setState(() => _benefits.removeAt(idx));
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Benefit deleted')));
                                        },
                                      ),
                                      const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ] else if (_currentTab == 'claims') ...[
                    // Review Claims View
                    Text('Benefit Claims', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                    const SizedBox(height: 12),
                    AppCard(
                      backgroundColor: cardBgColor,
                      padding: const EdgeInsets.all(0),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _claims.length,
                        itemBuilder: (ctx, idx) {
                          final c = _claims[idx];
                          return ListTile(
                            title: Text(c['employeeName'] ?? 'Employee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                            subtitle: Text('${c['benefitName']} • ₹${c['amount']} • ${c['date']}', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                            trailing: StatusChip(status: c['status'] ?? 'Pending'),
                          );
                        },
                      ),
                    ),
                  ] else if (_currentTab == 'create') ...[
                    // Create Benefit Form View
                    AppCard(
                      backgroundColor: cardBgColor,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Benefit Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                          const Divider(height: 20),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Name *', hintText: 'e.g. Health Insurance', border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _categoryController,
                            decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _providerController,
                            decoration: const InputDecoration(labelText: 'Provider', hintText: 'Insurance company / vendor', border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _coverageController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Coverage Amount (₹)', border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _costController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Premium / Cost (₹)', border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _effectiveDateController,
                                  decoration: const InputDecoration(labelText: 'Effective Date *', border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _expiryDateController,
                                  decoration: const InputDecoration(labelText: 'Expiry Date', border: OutlineInputBorder()),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          CheckboxListTile(
                            title: const Text('Claims require HR/Admin approval', style: TextStyle(fontSize: 13)),
                            value: _approvalRequired,
                            onChanged: (val) => setState(() => _approvalRequired = val ?? true),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () => setState(() => _currentTab = 'list'),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6B66), foregroundColor: Colors.white),
                                onPressed: _createBenefit,
                                child: const Text('Create Benefit'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: content);

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Benefits Management',
      ),
      body: content,
    );
  }

  Widget _buildStatCard(GlassTheme glass, Color cardBgColor, String label, String value, IconData icon, Color color) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 10),
      child: AppCard(
        backgroundColor: cardBgColor,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(child: Text(label, style: TextStyle(fontSize: 10, color: glass.textSecondary, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: glass.textPrimary)),
          ],
        ),
      ),
    );
  }
}
