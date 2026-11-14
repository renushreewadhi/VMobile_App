import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/training_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import 'hr_training_dashboard_screen.dart';

class HrCertificatesScreen extends ConsumerStatefulWidget {
  const HrCertificatesScreen({super.key});

  @override
  ConsumerState<HrCertificatesScreen> createState() => _HrCertificatesScreenState();
}

class _HrCertificatesScreenState extends ConsumerState<HrCertificatesScreen> {
  bool _isLoading = false;
  List<dynamic> _certificates = [];
  String _searchTerm = '';
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  Future<void> _loadCertificates() async {
    setState(() => _isLoading = true);
    final trainingService = ref.read(trainingServiceProvider);
    try {
      final res = await trainingService.getCertificates().catchError((_) => null);
      List<dynamic> items = res is List ? res : (res is Map && res['data'] is List ? res['data'] : []);
      setState(() {
        _certificates = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

    final filtered = _certificates.where((c) {
      final map = c is Map<String, dynamic> ? c : {};
      final title = (map['courseTitle'] ?? '').toString().toLowerCase();
      final emp = (map['employeeName'] ?? '').toString().toLowerCase();
      return _searchTerm.isEmpty || title.contains(_searchTerm.toLowerCase()) || emp.contains(_searchTerm.toLowerCase());
    }).toList();

    return GlassScaffold(
      title: 'Training & Development',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Training Certificates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 2),
                    const Text('Manage, issue, verify, and inspect employee training completion certificates', style: TextStyle(fontSize: 11.5, color: AppColors.lightSecondaryText)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating pending certificates...')));
                  },
                  icon: const Icon(Icons.workspace_premium, size: 16),
                  label: const Text('Generate Pending', style: TextStyle(fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 14),
            buildHrTrainingSubNav(context, 5),
            const SizedBox(height: 16),

            // 4 KPI Cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                _kpiCard('TOTAL ISSUED', '${_certificates.length}', 'Certificates', Icons.workspace_premium, AppColors.primary),
                _kpiCard('VALID CERTIFICATES', '${_certificates.length}', 'Verified', Icons.check_circle, Colors.green),
                _kpiCard('EXPIRING SOON', '0', 'Next 90 Days', Icons.timer, Colors.orange),
                _kpiCard('REVOKED / INACTIVE', '0', 'Flagged', Icons.cancel, Colors.red),
              ],
            ),
            const SizedBox(height: 16),

            // Search & Filter Bar
            AppCard(
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search certificate, employee, or course...',
                      prefixIcon: Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                      filled: true,
                      fillColor: AppColors.lightInputBackground,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (val) => setState(() => _searchTerm = val),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: ['All', 'Valid', 'Expiring', 'Revoked'].map((f) {
                      final isSelected = _filter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppColors.lightPrimaryText)),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: Colors.white,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text('Issued Certificates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            filtered.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.workspace_premium_outlined, size: 40, color: Colors.grey),
                            const SizedBox(height: 8),
                            const Text('No Certificates Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            const Text('No matching completion certificates match your current filters.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => setState(() {
                                _filter = 'All';
                                _searchTerm = '';
                              }),
                              child: const Text('Clear Filters'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final c = filtered[index] as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          child: ListTile(
                            title: Text(c['courseTitle'] ?? 'Certificate', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Employee: ${c['employeeName']} • Issued: ${c['issuedDate']}'),
                            trailing: const Icon(Icons.download, color: AppColors.primary),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value, String sub, IconData icon, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Text(sub, style: const TextStyle(fontSize: 9, color: AppColors.lightSecondaryText), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
