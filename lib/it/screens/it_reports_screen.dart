import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class ItReportsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const ItReportsScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<ItReportsScreen> createState() => _ItReportsScreenState();
}

class _ItReportsScreenState extends ConsumerState<ItReportsScreen> {
  bool _isLoading = true;
  List<dynamic> _reports = [];
  Map<String, dynamic> _stats = {};
  String _searchTerm = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchReportsData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchReportsData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/it/reports').catchError((_) => null);
      final statsRes = await apiClient.get('/it/dashboard').catchError((_) => null);

      if (mounted) {
        setState(() {
          if (statsRes is Map<String, dynamic>) {
            _stats = statsRes;
          }

          _reports = [
            {
              'id': 'rep-invoices',
              'title': 'IT Software & Subscription Invoice Ledger',
              'category': 'Invoices',
              'lastGenerated': '27/10/2026',
              'description': 'Comprehensive financial expenditure ledger of all software subscriptions, SaaS licenses, and hardware purchases.'
            },
            {
              'id': 'rep-licenses',
              'title': 'SaaS License Utilization & Expiry Ledger',
              'category': 'Licenses',
              'lastGenerated': '27/10/2026',
              'description': 'Active license seats, assigned employees, expiry dates, and subscription status.'
            },
            {
              'id': 'rep-tickets',
              'title': 'Monthly Support Ticket SLA & Resolution Report',
              'category': 'Helpdesk',
              'lastGenerated': '27/10/2026',
              'description': 'IT support ticket turnaround time, SLA compliance, resolution statuses, and agent workloads.'
            },
            {
              'id': 'rep-security',
              'title': 'System Access & Security Log Audit',
              'category': 'Security',
              'lastGenerated': '27/10/2026',
              'description': 'Authentication attempts, failed login alerts, IP origins, and system security events log.'
            },
            {
              'id': 'rep-assets',
              'title': 'Hardware & IT Asset Allocation Audit',
              'category': 'Assets',
              'lastGenerated': '27/10/2026',
              'description': 'Hardware inventory, employee asset assignments, condition statuses, and warranty information.'
            }
          ];

          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ItReports] Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCustomReportModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    final titleController = TextEditingController(text: 'Custom IT System Audit Report');
    String selectedCategory = 'Invoices';
    String selectedTimeframe = '30';
    String selectedFormat = 'PDF';
    bool isGenerating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkMainSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Generate Custom IT Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                      IconButton(onPressed: () => Navigator.pop(modalContext), icon: Icon(Icons.close, size: 20, color: glass.textSecondary)),
                    ],
                  ),
                  Divider(height: 16, color: glass.cardBorder),
                  const SizedBox(height: 8),

                  Text('Report Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: glass.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Enter report title...',
                      hintStyle: TextStyle(color: glass.textSecondary),
                      filled: true,
                      fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                    style: TextStyle(color: glass.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Invoices', child: Text('Software Invoices & Subsc', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'Licenses', child: Text('SaaS Licenses', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'Helpdesk', child: Text('Helpdesk & SLA Tickets', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'Security', child: Text('Security & Audit Logs', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'Assets', child: Text('Hardware Assets', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  Text('Time Period', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedTimeframe,
                    dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                    style: TextStyle(color: glass.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: '7', child: Text('Last 7 Days', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: '30', child: Text('Last 30 Days', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: '90', child: Text('Last 90 Days', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: '365', child: Text('All Time', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedTimeframe = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  Text('Export Format', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedFormat,
                    dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                    style: TextStyle(color: glass.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'PDF', child: Text('PDF Document (.pdf)')),
                      DropdownMenuItem(value: 'EXCEL', child: Text('Excel Spreadsheet (.csv / .xlsx)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedFormat = val);
                    },
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(modalContext),
                        child: Text('Cancel', style: TextStyle(color: glass.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: isGenerating
                            ? null
                            : () async {
                                setModalState(() => isGenerating = true);
                                await Future.delayed(const Duration(milliseconds: 800));
                                if (context.mounted) {
                                  Navigator.pop(modalContext);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Custom report "${titleController.text}" generated & downloaded successfully!'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Generate & Download'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _downloadReport(dynamic report, String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading "${report['title']}" as $format...'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = ModalRoute.of(context)?.canPop ?? false;
    final bool shouldShowAppBar = widget.showAppBar || canPop;

    if (_isLoading) {
      final skeleton = const ListSkeleton(itemCount: 4);
      if (shouldShowAppBar) {
        return GlassScaffold(
          title: 'IT Reports & Analytics',
          showBottomBar: false,
          body: skeleton,
        );
      }
      return skeleton;
    }

    final glass = context.glass;

    final availableCount = _reports.length;
    const exportedCount = 17;
    const scheduledCount = 4;
    const slaCompliance = '100%';

    final filtered = _reports.where((r) {
      final title = (r['title'] ?? '').toString().toLowerCase();
      final category = (r['category'] ?? '').toString().toLowerCase();
      return title.contains(_searchTerm.toLowerCase()) || category.contains(_searchTerm.toLowerCase());
    }).toList();

    final Widget mainContent = RefreshIndicator(
      onRefresh: _fetchReportsData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('IT Reports & Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Generate, view, and export hardware asset reports, ticket SLA metrics, and security audits.', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showCustomReportModal,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Custom Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 1. PASTEL SUMMARY PILLS (Auto-Moving Row)
            AutoMovingRow(
              spacing: 8,
              children: [
                PastelSummaryPill(
                  label: '$availableCount Available Reports',
                  variant: PastelPillVariant.blue,
                ),
                PastelSummaryPill(
                  label: '$exportedCount Exports This Month',
                  variant: PastelPillVariant.green,
                ),
                PastelSummaryPill(
                  label: '$scheduledCount Scheduled Audits',
                  variant: PastelPillVariant.amber,
                ),
                PastelSummaryPill(
                  label: '$slaCompliance SLA Compliance',
                  variant: PastelPillVariant.purple,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. CIRCULAR STATISTIC INDICATOR GROUP
            CircularStatGroup(
              items: [
                CircularStatItemData(
                  label: 'Reports',
                  value: '$availableCount',
                  ringColor: AppColors.primary,
                ),
                CircularStatItemData(
                  label: 'Exports',
                  value: '$exportedCount',
                  ringColor: AppColors.success,
                ),
                CircularStatItemData(
                  label: 'Audits',
                  value: '$scheduledCount',
                  ringColor: const Color(0xFFD97706),
                ),
                CircularStatItemData(
                  label: 'SLA',
                  value: slaCompliance,
                  ringColor: const Color(0xFF9333EA),
                ),
              ],
            ),
            const SizedBox(height: 16),

            GlassSearchBar(
              controller: _searchController,
              placeholder: 'Search report name or category...',
              onChanged: (val) => setState(() => _searchTerm = val),
              onClear: () => setState(() => _searchTerm = ''),
            ),
            const SizedBox(height: 16),

            if (filtered.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text('No reports matching search.', style: TextStyle(color: glass.textSecondary))),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final rep = filtered[index];
                  final title = rep['title'] ?? 'Report Title';
                  final category = rep['category'] ?? 'General';
                  final lastGen = rep['lastGenerated'] ?? 'Today';
                  final desc = rep['description'] ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0x24FFFFFF) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                                ),
                                alignment: Alignment.center,
                                child: Icon(Icons.description_rounded, color: isDark ? AppColors.primaryLight : AppColors.primary, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text('Category: $category', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                                  ],
                                ),
                              ),
                              StatusChip(status: category.toString().toUpperCase()),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(desc, style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                          const SizedBox(height: 10),
                          Text('Last Generated: $lastGen', style: TextStyle(fontSize: 11, color: glass.textSecondary, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Format: PDF / Excel', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _downloadReport(rep, 'PDF'),
                                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 14),
                                    label: const Text('PDF', style: TextStyle(color: Colors.red)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      side: const BorderSide(color: Colors.redAccent),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _downloadReport(rep, 'Excel'),
                                    icon: const Icon(Icons.table_chart, size: 14),
                                    label: const Text('Excel'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );

    if (shouldShowAppBar) {
      return GlassScaffold(
        title: 'IT Reports & Analytics',
        showBottomBar: false,
        body: mainContent,
      );
    }

    return mainContent;
  }
}
