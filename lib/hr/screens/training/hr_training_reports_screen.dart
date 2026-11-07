import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import 'hr_training_dashboard_screen.dart';

class HrTrainingReportsScreen extends ConsumerStatefulWidget {
  const HrTrainingReportsScreen({super.key});

  @override
  ConsumerState<HrTrainingReportsScreen> createState() => _HrTrainingReportsScreenState();
}

class _HrTrainingReportsScreenState extends ConsumerState<HrTrainingReportsScreen> {
  bool _isLoading = false;
  String _selectedFormat = 'PDF Document';
  String _targetFocus = 'Course Completion Rate';

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingShimmer();

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
                    const Text('Training Reports & Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 2),
                    const Text('Track employee participation, course completion rates, and organizational progress', style: TextStyle(fontSize: 11.5, color: AppColors.lightSecondaryText)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exporting report...')));
                  },
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export Report', style: TextStyle(fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 14),
            buildHrTrainingSubNav(context, 6),
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
                _kpiCard('ACTIVE COURSES', '4', 'Programs', Icons.book, AppColors.primary),
                _kpiCard('TOTAL ASSIGNMENTS', '3', 'Assigned', Icons.list_alt, Colors.green),
                _kpiCard('COMPLETED TRAININGS', '0', 'Passed', Icons.check_circle, Colors.orange),
                _kpiCard('AVG. OVERALL PROGRESS', '0%', 'Team Average', Icons.trending_up, Colors.purple),
              ],
            ),
            const SizedBox(height: 16),

            // Report Controls & Filters
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Report Control & Date Range Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search employee, category...',
                      prefixIcon: Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: AppColors.lightInputBackground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Report Target Focus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _targetFocus,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'Course Completion Rate', child: Text('Course Completion Rate')),
                      DropdownMenuItem(value: 'Employee Performance', child: Text('Employee Performance')),
                      DropdownMenuItem(value: 'Department Analytics', child: Text('Department Analytics')),
                    ],
                    onChanged: (val) => setState(() => _targetFocus = val ?? 'Course Completion Rate'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report filters applied')));
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Export Format Options
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Choose Preferred Export Format', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _formatCard('PDF Document', 'Printable executive summary', _selectedFormat, (f) => setState(() => _selectedFormat = f))),
                      const SizedBox(width: 8),
                      Expanded(child: _formatCard('Excel Spreadsheet', 'XLSX format with raw data', _selectedFormat, (f) => setState(() => _selectedFormat = f))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloading $_selectedFormat report...')));
                      },
                      icon: const Icon(Icons.download),
                      label: Text('Download $_selectedFormat'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
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

  Widget _formatCard(String format, String desc, String current, Function(String) onTap) {
    final isSelected = current == format;
    return InkWell(
      onTap: () => onTap(format),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.lightBordersAndDividers),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(format, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? AppColors.primary : AppColors.lightPrimaryText)),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(fontSize: 10.5, color: AppColors.lightSecondaryText)),
          ],
        ),
      ),
    );
  }
}
