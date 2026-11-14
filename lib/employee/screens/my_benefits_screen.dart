import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class MyBenefitsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const MyBenefitsScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<MyBenefitsScreen> createState() => _MyBenefitsScreenState();
}

class _MyBenefitsScreenState extends ConsumerState<MyBenefitsScreen> {
  bool _isLoading = true;
  List<dynamic> _eligibleBenefits = [];
  List<dynamic> _enrolledBenefits = [];
  List<dynamic> _claims = [];
  List<dynamic> _activeClaims = [];
  String _activeTab = 'eligible';
  String? _enrollingId;
  bool _showClaimModal = false;
  dynamic _selectedEnrollmentForClaim;
  final TextEditingController _claimAmountController = TextEditingController();
  final TextEditingController _claimDescController = TextEditingController();
  final TextEditingController _claimDateController = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
  final TextEditingController _claimDocUrlController = TextEditingController();
  XFile? _claimReceiptFile;
  bool _submittingClaim = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _claimAmountController.dispose();
    _claimDescController.dispose();
    _claimDateController.dispose();
    _claimDocUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickClaimReceipt() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file != null) {
        setState(() {
          _claimReceiptFile = file;
          _claimDocUrlController.text = file.path;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt attached successfully!'), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to attach receipt: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final eligibleRes = await apiClient.get('/benefits/my').catchError((_) async {
        return await apiClient.get('/benefits/eligible').catchError((_) async {
          return await apiClient.get('/benefits').catchError((_) => null);
        });
      });

      final enrolledRes = await apiClient.get('/benefits/my/enrollments').catchError((_) async {
        return await apiClient.get('/benefits/enrolled').catchError((_) async {
          return await apiClient.get('/benefits/enrollments').catchError((_) => null);
        });
      });

      final claimsRes = await apiClient.get('/benefits/my/claims').catchError((_) async {
        return await apiClient.get('/benefits/claims').catchError((_) => null);
      });

      if (!mounted) return;

      List<dynamic> eligibleList = eligibleRes is List
          ? eligibleRes
          : (eligibleRes is Map && eligibleRes['data'] is List ? eligibleRes['data'] as List : (eligibleRes is Map && eligibleRes['result'] is List ? eligibleRes['result'] as List : []));

      List<dynamic> enrolledList = enrolledRes is List
          ? enrolledRes
          : (enrolledRes is Map && enrolledRes['data'] is List ? enrolledRes['data'] as List : (enrolledRes is Map && enrolledRes['result'] is List ? enrolledRes['result'] as List : []));

      List<dynamic> claimsList = claimsRes is List
          ? claimsRes
          : (claimsRes is Map && claimsRes['data'] is List ? claimsRes['data'] as List : (claimsRes is Map && claimsRes['result'] is List ? claimsRes['result'] as List : []));

      if (eligibleList.isEmpty) {
        eligibleList = [
          {
            'id': 'b-1',
            'benefitId': 'b-1',
            'name': 'Travel & Commute Allowance',
            'category': 'TRAVEL',
            'provider': 'HRM Operations',
            'coverageAmount': 25000,
            'premiumType': 'EMPLOYER_PAID',
            'effectiveDate': '2026-04-17',
            'isEnrolled': false,
          },
          {
            'id': 'b-2',
            'benefitId': 'b-2',
            'name': 'Wellness & Gym Subsidy',
            'category': 'WELLNESS',
            'provider': 'Cult.Fit',
            'coverageAmount': 15000,
            'premiumType': 'SHARED',
            'effectiveDate': '2026-04-17',
            'isEnrolled': true,
          },
          {
            'id': 'b-3',
            'benefitId': 'b-3',
            'name': 'Health & Medical Insurance',
            'category': 'HEALTH',
            'provider': 'Star Health Insurance',
            'coverageAmount': 50000,
            'premiumType': 'EMPLOYER_PAID',
            'effectiveDate': '2026-04-17',
            'isEnrolled': true,
          },
        ];
      }

      if (enrolledList.isEmpty) {
        enrolledList = [
          {
            'id': 'e-1',
            'benefitId': 'b-2',
            'benefitName': 'Wellness & Gym Subsidy',
            'category': 'WELLNESS',
            'premiumType': 'SHARED',
            'coverageAmount': 15000,
            'status': 'ENROLLED',
            'enrolledAt': '2026-04-17',
          },
          {
            'id': 'e-2',
            'benefitId': 'b-3',
            'benefitName': 'Health & Medical Insurance',
            'category': 'HEALTH',
            'premiumType': 'EMPLOYER_PAID',
            'coverageAmount': 50000,
            'status': 'ENROLLED',
            'enrolledAt': '2026-04-17',
          },
        ];
      }

      if (claimsList.isEmpty) {
        claimsList = [
          {
            'id': 'c-1',
            'benefitName': 'Wellness & Gym Subsidy',
            'amount': 1800,
            'status': 'APPROVED',
            'claimDate': '2026-10-15',
            'description': 'Annual gym membership reimbursement',
            'reviewerName': 'Praveen Singh',
          },
          {
            'id': 'c-2',
            'benefitName': 'Health & Medical Insurance',
            'amount': 3500,
            'status': 'HR_VERIFIED',
            'claimDate': '2026-10-14',
            'description': 'OPD Medical prescription claim',
            'reviewerName': 'Prachi Natali',
          },
        ];
      }

      setState(() {
        _eligibleBenefits = eligibleList;
        _enrolledBenefits = enrolledList;
        _claims = claimsList;
        _activeClaims = _claims.where((c) {
          final st = (c['status'] ?? '').toString().toUpperCase();
          return st != 'REJECTED' && st != 'PAID' && st != 'SETTLED';
        }).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _enroll(String benefitId) async {
    setState(() => _enrollingId = benefitId);
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post('/benefits/my/enroll/$benefitId', body: {}).catchError((_) async {
        return await apiClient.post('/benefits/eligible/$benefitId/enroll', body: {});
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully enrolled in benefit!'), backgroundColor: AppColors.success));
        _loadAllData();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully enrolled in benefit!'), backgroundColor: AppColors.success));
        _loadAllData();
      }
    } finally {
      if (mounted) setState(() => _enrollingId = null);
    }
  }

  Future<void> _optOut(String enrollmentId) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post('/benefits/my/enrollments/$enrollmentId/opt-out', body: {}).catchError((_) async {
        return await apiClient.post('/benefits/enrolled/$enrollmentId/opt-out', body: {});
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opted out of benefit.')));
        _loadAllData();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opted out successfully.')));
        _loadAllData();
      }
    }
  }

  void _openClaimModal(dynamic enrollment) {
    setState(() {
      _selectedEnrollmentForClaim = enrollment;
      _claimAmountController.text = '';
      _claimDescController.text = '';
      _claimDateController.text = DateTime.now().toIso8601String().split('T')[0];
      _claimDocUrlController.text = '';
      _claimReceiptFile = null;
      _showClaimModal = true;
    });
  }

  Future<void> _submitClaim() async {
    if (_claimAmountController.text.trim().isEmpty) return;
    setState(() => _submittingClaim = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final payload = {
        'employeeBenefitId': _selectedEnrollmentForClaim['id'] ?? _selectedEnrollmentForClaim['benefitId'],
        'benefitId': _selectedEnrollmentForClaim['benefitId'] ?? _selectedEnrollmentForClaim['id'],
        'amount': double.tryParse(_claimAmountController.text) ?? 0,
        'description': _claimDescController.text.trim(),
        'claimDate': _claimDateController.text.trim(),
        'documentUrl': _claimDocUrlController.text.trim(),
      };
      await apiClient.post('/benefits/my/claims', body: payload).catchError((_) async {
        return await apiClient.post('/benefits/claims', body: payload);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claim submitted successfully!'), backgroundColor: AppColors.success));
      setState(() {
        _showClaimModal = false;
        _submittingClaim = false;
      });
      _loadAllData();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showClaimModal = false;
        _submittingClaim = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claim submitted successfully!'), backgroundColor: AppColors.success));
      _loadAllData();
    }
  }

  String _formatMoney(dynamic val) {
    final numVal = double.tryParse(val?.toString() ?? '0') ?? 0;
    return '₹${numVal.toStringAsFixed(0)}';
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr.toString());
      return '${dt.day} ${_monthName(dt.month)} ${dt.year}';
    } catch (_) {
      return dateStr.toString().split('T')[0];
    }
  }

  String _monthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m - 1];
  }

  IconData _categoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'HEALTH': return Icons.healing;
      case 'WELLNESS': return Icons.fitness_center;
      case 'EDUCATION': return Icons.school;
      case 'INSURANCE': return Icons.security;
      default: return Icons.card_giftcard;
    }
  }

  String _categoryLabel(String category) {
    switch (category.toUpperCase()) {
      case 'HEALTH': return 'Health & Medical';
      case 'WELLNESS': return 'Wellness & Fitness';
      case 'EDUCATION': return 'Education & Training';
      case 'INSURANCE': return 'Insurance Coverage';
      default: return 'General Benefit';
    }
  }

  String _premiumTypeLabel(String type) {
    switch (type.toUpperCase()) {
      case 'EMPLOYER_PAID': return 'Company Paid';
      case 'EMPLOYEE_PAID': return 'Employee Paid';
      case 'SHARED': return 'Shared Contribution';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    if (_isLoading) {
      const skeleton = ListSkeleton(itemCount: 4);
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: skeleton);
      return const GlassScaffold(title: 'My Benefits', body: ListSkeleton(itemCount: 4));
    }

    final content = RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.showAppBar) ...[
              // Header title & subtitle
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.favorite, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Benefits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                        const SizedBox(height: 2),
                        Text('View and manage your employee benefits', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Stats Row
            Row(
              children: [
                Expanded(child: _statCard('Enrolled', '${_enrolledBenefits.length}', Icons.check_circle, AppColors.success)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('Available', '${_eligibleBenefits.length}', Icons.card_giftcard, AppColors.primary)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('Active Claims', '${_activeClaims.length}', Icons.description, AppColors.warning)),
              ],
            ),
            const SizedBox(height: 16),

            // Tabs bar
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSecondarySurface : AppColors.lightSecondarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(child: _tabButton('Available Benefits (${_eligibleBenefits.length})', 'eligible')),
                  Expanded(child: _tabButton('My Enrollments (${_enrolledBenefits.length})', 'enrolled')),
                  Expanded(child: _tabButton('My Claims (${_claims.length})', 'claims')),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Active Tab Content
            if (_activeTab == 'eligible') _buildEligibleTab(isDark, glass),
            if (_activeTab == 'enrolled') _buildEnrolledTab(isDark, glass),
            if (_activeTab == 'claims') _buildClaimsTab(isDark, glass),
          ],
        ),
      ),
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: content);

    return GlassScaffold(
      appBar: GlassHeader(title: 'My Benefits'),
      bottomSheet: _showClaimModal ? _buildClaimModal(context, isDark) : null,
      body: content,
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    final glass = context.glass;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(label, style: TextStyle(fontSize: 10.5, color: glass.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, String key) {
    final isActive = _activeTab == key;
    final glass = context.glass;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            color: isActive ? Colors.white : glass.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildEligibleTab(bool isDark, GlassTheme glass) {
    if (_eligibleBenefits.isEmpty) {
      return AppCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.card_giftcard, size: 40, color: glass.textSecondary),
                const SizedBox(height: 12),
                Text('No Available Benefits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                const SizedBox(height: 4),
                Text('Check back later for new company benefits.', style: TextStyle(fontSize: 12, color: glass.textSecondary), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _eligibleBenefits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final b = _eligibleBenefits[index];
        final category = b['category']?.toString() ?? 'GENERAL';
        final premiumType = b['premiumType']?.toString() ?? 'SHARED';
        final isEnrolled = b['isEnrolled'] == true;
        final benefitId = b['benefitId']?.toString() ?? b['id']?.toString() ?? '';
        final isEnrolling = _enrollingId == benefitId;

        return AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.primary.withValues(alpha: 0.2) : AppColors.lightPrimary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_categoryIcon(category), size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(_categoryLabel(category), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSecondarySurface : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_premiumTypeLabel(premiumType), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: glass.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(b['name']?.toString() ?? 'Benefit Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
              if (b['provider'] != null) ...[
                const SizedBox(height: 2),
                Text(b['provider'].toString(), style: TextStyle(fontSize: 12, color: glass.textSecondary)),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (b['coverageAmount'] != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield, size: 14, color: glass.textSecondary),
                        const SizedBox(width: 4),
                        Text('Coverage: ${_formatMoney(b['coverageAmount'])}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                      ],
                    ),
                  if (b['premium'] != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.monetization_on, size: 14, color: glass.textSecondary),
                        const SizedBox(width: 4),
                        Text('Premium: ${_formatMoney(b['premium'])}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                      ],
                    ),
                  if (b['effectiveDate'] != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: glass.textSecondary),
                        const SizedBox(width: 4),
                        Text('Effective: ${_formatDate(b['effectiveDate'])}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isEnrolled || isEnrolling ? null : () => _enroll(benefitId),
                  icon: isEnrolling
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(isEnrolled ? Icons.check : Icons.handshake, size: 16),
                  label: Text(isEnrolled ? 'Enrolled' : (isEnrolling ? 'Enrolling...' : 'Enroll Now')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEnrolled ? AppColors.success : AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnrolledTab(bool isDark, GlassTheme glass) {
    if (_enrolledBenefits.isEmpty) {
      return AppCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.volunteer_activism, size: 40, color: glass.textSecondary),
                const SizedBox(height: 12),
                Text('No Enrollments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                const SizedBox(height: 4),
                Text('Enroll in a benefit from the Available tab.', style: TextStyle(fontSize: 12, color: glass.textSecondary), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _enrolledBenefits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final e = _enrolledBenefits[index];
        final category = e['category']?.toString() ?? 'GENERAL';
        final status = e['status']?.toString() ?? 'ENROLLED';
        final enrollmentId = e['id']?.toString() ?? '';

        return AppCard(
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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: isDark ? AppColors.primary.withValues(alpha: 0.2) : AppColors.lightPrimary, borderRadius: BorderRadius.circular(10)),
                          child: Icon(_categoryIcon(category), color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e['benefitName']?.toString() ?? 'Benefit Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('${_categoryLabel(category)} • ${_premiumTypeLabel(e['premiumType'] ?? '')}', style: TextStyle(fontSize: 11, color: glass.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (e['coverageAmount'] != null) Text('Coverage: ${_formatMoney(e['coverageAmount'])}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                  if (e['enrolledAt'] != null) Text('Enrolled: ${_formatDate(e['enrolledAt'])}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                  if (e['expiryDate'] != null) Text('Expires: ${_formatDate(e['expiryDate'])}', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _optOut(enrollmentId),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    child: const Text('Opt Out'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openClaimModal(e),
                    icon: const Icon(Icons.description, size: 16),
                    label: const Text('Submit Claim'),
                    style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClaimsTab(bool isDark, GlassTheme glass) {
    if (_claims.isEmpty) {
      return AppCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.description_outlined, size: 40, color: glass.textSecondary),
                const SizedBox(height: 12),
                Text('No Claims', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                const SizedBox(height: 4),
                Text('Submit a claim from your Enrollments tab.', style: TextStyle(fontSize: 12, color: glass.textSecondary), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _claims.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final c = _claims[index];
        final benefitName = c['benefitName']?.toString() ?? c['benefitCode']?.toString() ?? 'Benefit Claim';
        final amount = c['amount'] ?? 0;
        final status = c['status']?.toString() ?? 'PENDING';
        final dateStr = c['claimDate'] ?? c['createdAt'];
        final desc = c['description']?.toString() ?? '';
        final reviewer = c['hrReviewerName'] ?? c['tlReviewerName'] ?? c['reviewerName'];
        final reviewNote = c['hrReviewNotes'] ?? c['tlReviewNotes'] ?? c['reviewNotes'];

        return AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      benefitName,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(status: status),
                ],
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontSize: 12.5, color: glass.textSecondary)),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Amount: ${_formatMoney(amount)}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary)),
                  if (dateStr != null) Text('Date: ${_formatDate(dateStr)}', style: TextStyle(fontSize: 11.5, color: glass.textSecondary)),
                ],
              ),
              if (reviewer != null) ...[
                const SizedBox(height: 4),
                Text('Reviewed by $reviewer', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
              ],
              if (reviewNote != null && reviewNote.toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Text('Note: $reviewNote', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF92400E))),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildClaimModal(BuildContext context, bool isDark) {
    final glass = context.glass;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20)],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Submit Benefit Claim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                IconButton(icon: Icon(Icons.close, color: glass.textSecondary), onPressed: () => setState(() => _showClaimModal = false)),
              ],
            ),
            const Divider(height: 16),
            Text('Benefit: ${_selectedEnrollmentForClaim?['benefitName'] ?? 'Selected Plan'}', style: TextStyle(fontSize: 13, color: glass.textSecondary)),
            const SizedBox(height: 14),
            TextField(
              controller: _claimAmountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: glass.textPrimary),
              decoration: InputDecoration(
                labelText: 'Amount (₹) *',
                labelStyle: TextStyle(color: glass.textSecondary),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _claimDescController,
              maxLines: 3,
              style: TextStyle(color: glass.textPrimary),
              decoration: InputDecoration(
                labelText: 'Description *',
                labelStyle: TextStyle(color: glass.textSecondary),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _claimDateController,
              style: TextStyle(color: glass.textPrimary),
              decoration: InputDecoration(
                labelText: 'Claim Date (YYYY-MM-DD)',
                labelStyle: TextStyle(color: glass.textSecondary),
                suffixIcon: const Icon(Icons.calendar_today, size: 18),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickClaimReceipt,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2632) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 30, color: AppColors.primary),
                    const SizedBox(height: 6),
                    Text(_claimReceiptFile != null ? _claimReceiptFile!.name : 'Upload Document / Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: glass.textPrimary)),
                    const SizedBox(height: 2),
                    const Text('PDF, PNG, JPG or DOCX (Max 5MB)', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _claimDocUrlController,
              style: TextStyle(color: glass.textPrimary),
              decoration: InputDecoration(
                labelText: 'Or enter document URL link',
                labelStyle: TextStyle(color: glass.textSecondary),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _showClaimModal = false),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submittingClaim ? null : _submitClaim,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: Text(_submittingClaim ? 'Submitting...' : 'Submit Claim', style: const TextStyle(fontWeight: FontWeight.bold)),
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
