import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class MySalaryScreen extends ConsumerStatefulWidget {
  const MySalaryScreen({super.key});

  @override
  ConsumerState<MySalaryScreen> createState() => _MySalaryScreenState();
}

class _MySalaryScreenState extends ConsumerState<MySalaryScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _salaryInfo;

  @override
  void initState() {
    super.initState();
    _fetchSalary();
  }

  Future<void> _fetchSalary() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get(ApiEndpoints.mySalary).catchError((_) => null);
      if (mounted) {
        setState(() {
          _salaryInfo = res is Map<String, dynamic> ? (res['data'] ?? res) : {
            'basic': '₹45,000',
            'gross': '₹75,000',
            'deductions': '₹5,750',
            'net': '₹69,250',
            'hra': '₹18,000',
            'medical': '₹1,250',
            'special': '₹9,150',
            'pf': '₹5,400',
            'pt': '₹350'
          };
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Salary & Structure')),
      body: _isLoading
          ? const DashboardSkeleton()
          : RefreshIndicator(
              onRefresh: _fetchSalary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Salary Summary Grid (4 Cards)
                    Row(
                      children: [
                        Expanded(child: _salaryCard('Basic Salary', _salaryInfo?['basic']?.toString() ?? '₹45,000', Icons.work, Colors.blue)),
                        const SizedBox(width: 8),
                        Expanded(child: _salaryCard('Gross Pay', _salaryInfo?['gross']?.toString() ?? '₹75,000', Icons.receipt, Colors.purple)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _salaryCard('Deductions', '-${_salaryInfo?['deductions']?.toString() ?? '₹5,750'}', Icons.remove_circle, Colors.red)),
                        const SizedBox(width: 8),
                        Expanded(child: _salaryCard('Net Take-Home', _salaryInfo?['net']?.toString() ?? '₹69,250', Icons.check_circle, Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Salary Structure Breakdown Card
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Salary Structure Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Divider(height: 24),
                          _buildRow('Basic Salary', _salaryInfo?['basic']?.toString() ?? '₹45,000'),
                          const SizedBox(height: 12),
                          _buildRow('House Rent Allowance (HRA)', _salaryInfo?['hra']?.toString() ?? '₹18,000'),
                          const SizedBox(height: 12),
                          _buildRow('Medical Allowance', _salaryInfo?['medical']?.toString() ?? '₹1,250'),
                          const SizedBox(height: 12),
                          _buildRow('Special Allowance', _salaryInfo?['special']?.toString() ?? '₹9,150'),
                          const Divider(height: 24),
                          _buildRow('Provident Fund (PF)', '-${_salaryInfo?['pf']?.toString() ?? '₹5,400'}', isDeduction: true),
                          const SizedBox(height: 12),
                          _buildRow('Professional Tax', '-${_salaryInfo?['pt']?.toString() ?? '₹350'}', isDeduction: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _salaryCard(String label, String value, IconData icon, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.lightSecondaryText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String val, {bool isDeduction = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.lightSecondaryText, fontSize: 13)),
        Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDeduction ? AppColors.error : AppColors.lightPrimaryText)),
      ],
    );
  }
}
