import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
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
  String _activeTab = 'eligible'; // 'eligible' | 'enrolled' | 'claims'
  List<dynamic> _eligibleBenefits = [];
  List<dynamic> _enrollments = [];
  List<dynamic> _claims = [];
  String? _enrollingId;

  // Claim modal state
  bool _showClaimModal = false;
  final _claimFormKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _docUrlController = TextEditingController();
  String _claimDateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _selectedEmployeeBenefitId = '';
  bool _submittingClaim = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    _docUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadEligible(),
      _loadEnrollments(),
      _loadClaims(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadEligible() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/benefits/my').catchError((_) => null);
      if (mounted && res != null) {
        if (res is List) {
          _eligibleBenefits = res;
        } else if (res is Map<String, dynamic> && res['data'] is List) {
          _eligibleBenefits = res['data'];
        }
      }
    } catch (_) {}
  }

  Future<void> _loadEnrollments() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/benefits/my/enrollments').catchError((_) => null);
      if (mounted && res != null) {
        if (res is List) {
          _enrollments = res;
        } else if (res is Map<String, dynamic> && res['data'] is List) {
          _enrollments = res['data'];
        }
      }
    } catch (_) {}
  }

  Future<void> _loadClaims() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/benefits/my/claims').catchError((_) => null);
      if (mounted && res != null) {
        if (res is List) {
          _claims = res;
        } else if (res is Map<String, dynamic> && res['data'] is List) {
          _claims = res['data'];
        }
      }
    } catch (_) {}
  }

  List<dynamic> get _enrolledBenefits => _enrollments.where((e) => (e['status'] ?? '').toString().toUpperCase() == 'ENROLLED').toList();

  List<dynamic> get _activeClaims => _claims.where((c) {
        final s = (c['status'] ?? '').toString().toUpperCase();
        return s == 'PENDING' || s == 'TL_APPROVED' || s == 'HR_VERIFIED' || s == 'PROCESSED';
      }).toList();

  Future<void> _enroll(String benefitId) async {
    setState(() => _enrollingId = benefitId);
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post('/benefits/my/enroll/$benefitId', body: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are now enrolled in this benefit!'), backgroundColor: AppColors.success),
        );
        await _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        final err = e.toString().replaceFirst('ApiException: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.isNotEmpty ? err : 'Failed to enroll.'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _enrollingId = null);
    }
  }

  Future<void> _optOut(String enrollmentId) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post('/benefits/my/enrollments/$enrollmentId/opt-out', body: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have opted out of the benefit.'), backgroundColor: AppColors.success),
        );
        await _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        final err = e.toString().replaceFirst('ApiException: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.isNotEmpty ? err : 'Failed to opt out.'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _openClaimModal(Map<String, dynamic> enrollment) {
    setState(() {
      _selectedEmployeeBenefitId = enrollment['id']?.toString() ?? '';
      _amountController.clear();
      _descController.clear();
      _docUrlController.clear();
      _claimDateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _showClaimModal = true;
    });
  }

  void _closeClaimModal() {
    setState(() => _showClaimModal = false);
  }

  Future<void> _submitClaim() async {
    if (!_claimFormKey.currentState!.validate()) return;
    setState(() => _submittingClaim = true);

    final apiClient = ref.read(apiClientProvider);
    final payload = {
      'employeeBenefitId': _selectedEmployeeBenefitId,
      'amount': double.tryParse(_amountController.text.trim()) ?? 0,
      'description': _descController.text.trim(),
      'claimDate': _claimDateStr,
      'documentUrl': _docUrlController.text.trim(),
    };

    try {
      await apiClient.post('/benefits/my/claims', body: payload);
      if (mounted) {
        _closeClaimModal();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim submitted for review!'), backgroundColor: AppColors.success),
        );
        await _loadClaims();
        setState(() => _activeTab = 'claims');
      }
    } catch (e) {
      if (mounted) {
        final err = e.toString().replaceFirst('ApiException: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.isNotEmpty ? err : 'Failed to submit claim.'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingClaim = false);
    }
  }

  String _categoryLabel(String c) {
    switch (c.toUpperCase()) {
      case 'HEALTH_INSURANCE':
        return 'Health Insurance';
      case 'LIFE_INSURANCE':
        return 'Life Insurance';
      case 'WELLNESS':
        return 'Wellness';
      case 'MEAL':
        return 'Meal Stipend';
      case 'TRAVEL':
        return 'Travel';
      case 'EDUCATION':
        return 'Education';
      case 'WFH':
        return 'Work From Home';
      default:
        return c.replaceAll('_', ' ');
    }
  }

  IconData _categoryIcon(String c) {
    switch (c.toUpperCase()) {
      case 'HEALTH_INSURANCE':
        return Icons.local_hospital;
      case 'LIFE_INSURANCE':
        return Icons.security;
      case 'WELLNESS':
        return Icons.spa;
      case 'MEAL':
        return Icons.restaurant;
      case 'TRAVEL':
        return Icons.flight;
      case 'EDUCATION':
        return Icons.school;
      case 'WFH':
        return Icons.home_work;
      default:
        return Icons.card_giftcard;
    }
  }

  String _premiumTypeLabel(String t) {
    switch (t.toUpperCase()) {
      case 'EMPLOYER_PAID':
        return 'Company Paid';
      case 'EMPLOYEE_PAID':
        return 'Employee Paid';
      case 'SHARED':
        return 'Shared';
      default:
        return t;
    }
  }

  String _formatMoney(dynamic n) {
    if (n == null) return '—';
    final numVal = num.tryParse(n.toString()) ?? 0;
    return NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(numVal);
  }

  String _formatDate(String? d) {
    if (d == null || d.isEmpty) return '—';
    try {
      final dt = DateTime.parse(d);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: const Text('My Benefits')) : null,
      body: _isLoading
          ? const ListSkeleton(itemCount: 4)
          : RefreshIndicator(
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
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.favorite, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('My Benefits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              SizedBox(height: 2),
                              Text('View and manage your employee benefits', style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                            ],
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
                        Expanded(child: _statCard('Claims', '${_activeClaims.length}', Icons.description, AppColors.warning)),
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
                          Expanded(child: _tabButton('Available (${_eligibleBenefits.length})', 'eligible')),
                          Expanded(child: _tabButton('Enrollments (${_enrolledBenefits.length})', 'enrolled')),
                          Expanded(child: _tabButton('Claims (${_claims.length})', 'claims')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Active Tab Content
                    if (_activeTab == 'eligible') _buildEligibleTab(isDark),
                    if (_activeTab == 'enrolled') _buildEnrolledTab(isDark),
                    if (_activeTab == 'claims') _buildClaimsTab(isDark),
                  ],
                ),
              ),
            ),
      bottomSheet: _showClaimModal ? _buildClaimModal(context, isDark) : null,
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.lightSecondaryText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, String key) {
    final isActive = _activeTab == key;
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
            color: isActive ? Colors.white : AppColors.lightSecondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildEligibleTab(bool isDark) {
    if (_eligibleBenefits.isEmpty) {
      return const AppCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.card_giftcard, size: 40, color: Colors.grey),
                SizedBox(height: 12),
                Text('No Available Benefits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('Check back later for new company benefits.', style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
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
                      color: AppColors.lightPrimary,
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
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                    child: Text(_premiumTypeLabel(premiumType), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(b['name']?.toString() ?? 'Benefit Plan', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (b['provider'] != null) ...[
                const SizedBox(height: 2),
                Text(b['provider'].toString(), style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
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
                        const Icon(Icons.shield, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('Coverage: ${_formatMoney(b['coverageAmount'])}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  if (b['premium'] != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('Premium: ${_formatMoney(b['premium'])}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  if (b['effectiveDate'] != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('Effective: ${_formatDate(b['effectiveDate'])}', style: const TextStyle(fontSize: 12)),
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
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnrolledTab(bool isDark) {
    if (_enrolledBenefits.isEmpty) {
      return const AppCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.volunteer_activism, size: 40, color: Colors.grey),
                SizedBox(height: 12),
                Text('No Enrollments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('Enroll in a benefit from the Available tab.', style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.lightPrimary, borderRadius: BorderRadius.circular(10)),
                        child: Icon(_categoryIcon(category), color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e['benefitName']?.toString() ?? 'Benefit Plan', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('${_categoryLabel(category)} • ${_premiumTypeLabel(e['premiumType'] ?? '')}', style: const TextStyle(fontSize: 11, color: AppColors.lightSecondaryText)),
                        ],
                      ),
                    ],
                  ),
                  StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (e['coverageAmount'] != null) Text('Coverage: ${_formatMoney(e['coverageAmount'])}', style: const TextStyle(fontSize: 12)),
                  if (e['enrolledAt'] != null) Text('Enrolled: ${_formatDate(e['enrolledAt'])}', style: const TextStyle(fontSize: 12)),
                  if (e['expiryDate'] != null) Text('Expires: ${_formatDate(e['expiryDate'])}', style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _optOut(enrollmentId),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    child: const Text('Opt Out'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _openClaimModal(e),
                    icon: const Icon(Icons.description, size: 16),
                    label: const Text('Submit Claim'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClaimsTab(bool isDark) {
    if (_claims.isEmpty) {
      return const AppCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.description_outlined, size: 40, color: Colors.grey),
                SizedBox(height: 12),
                Text('No Claims', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('Submit a claim from your Enrollments tab.', style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
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
        final status = c['status']?.toString() ?? 'PENDING';
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
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(benefitName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                    ],
                  ),
                  StatusChip(status: status),
                ],
              ),
              if (c['description'] != null && c['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(c['description'].toString(), style: const TextStyle(fontSize: 12.5, color: AppColors.lightSecondaryText)),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wallet, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(_formatMoney(c['amount']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  if (c['claimDate'] != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(_formatDate(c['claimDate']), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  if (reviewer != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user, size: 14, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text('Reviewed by $reviewer', style: const TextStyle(fontSize: 11.5)),
                      ],
                    ),
                ],
              ),
              if (reviewNote != null && reviewNote.toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.comment, size: 14, color: Colors.amber),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Note: $reviewNote', style: const TextStyle(fontSize: 11.5, color: Colors.brown, fontStyle: FontStyle.italic))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildClaimModal(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)],
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _claimFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Submit Benefit Claim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: _closeClaimModal),
                ],
              ),
              const Divider(height: 16),
              const Text('Claim Amount (₹) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  filled: true,
                  fillColor: isDark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Amount is required';
                  final val = double.tryParse(v.trim()) ?? 0;
                  if (val <= 0) return 'Amount must be greater than zero';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const Text('Description *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe the claim details...',
                  filled: true,
                  fillColor: isDark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Description is required' : null,
              ),
              const SizedBox(height: 14),
              const Text('Supporting Document URL / Link', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _docUrlController,
                decoration: InputDecoration(
                  hintText: 'https://link-to-bill-or-receipt.com',
                  filled: true,
                  fillColor: isDark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submittingClaim ? null : _submitClaim,
                  child: Text(_submittingClaim ? 'Submitting...' : 'Submit Claim'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
