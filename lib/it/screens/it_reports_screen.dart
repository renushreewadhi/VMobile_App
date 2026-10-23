import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';

class ItReportsScreen extends ConsumerStatefulWidget {
  const ItReportsScreen({super.key});

  @override
  ConsumerState<ItReportsScreen> createState() => _ItReportsScreenState();
}

class _ItReportsScreenState extends ConsumerState<ItReportsScreen> {
  bool _isLoading = false;
  String _searchTerm = '';

  final List<Map<String, String>> _reports = [
    {
      'id': 'rep-invoices',
      'title': 'IT Software & Subscription Invoice Ledger',
      'category': 'Invoices',
      'lastGenerated': 'Today',
      'description': 'Comprehensive financial expenditure ledger of all software subscriptions, SaaS licenses, and hardware purchases.'
    },
    {
      'id': 'rep-licenses',
      'title': 'SaaS License Utilization & Expiry Ledger',
      'category': 'Licenses',
      'lastGenerated': 'Today',
      'description': 'Active license seats, assigned employees, expiry dates, and subscription status.'
    },
    {
      'id': 'rep-tickets',
      'title': 'Monthly Support Ticket SLA & Resolution Report',
      'category': 'Helpdesk',
      'lastGenerated': 'Today',
      'description': 'IT support ticket turnaround time, SLA compliance, resolution statuses, and agent workloads.'
    },
    {
      'id': 'rep-security',
      'title': 'System Access & Security Log Audit',
      'category': 'Security',
      'lastGenerated': 'Today',
      'description': 'Authentication attempts, failed login alerts, IP origins, and system security events log.'
    },
    {
      'id': 'rep-assets',
      'title': 'Hardware & IT Asset Allocation Audit',
      'category': 'Assets',
      'lastGenerated': 'Today',
      'description': 'Hardware inventory, employee asset assignments, condition statuses, and warranty information.'
    }
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const ListSkeleton(itemCount: 4);

    final filtered = _reports.where((r) {
      return r['title']!.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          r['category']!.toLowerCase().contains(_searchTerm.toLowerCase());
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('IT Reports & Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  SizedBox(height: 2),
                  Text('Generate, view, and export hardware asset & audit reports.', style: TextStyle(fontSize: 12, color: AppColors.lightMutedText)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Custom IT Report modal')));
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Custom Report'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: StatCard(title: 'Reports', value: '${_reports.length}', icon: Icons.description, iconColor: AppColors.primary, iconBgColor: AppColors.lightPrimary)),
              const SizedBox(width: 8),
              Expanded(child: StatCard(title: 'SLA Compliance', value: '98.5%', icon: Icons.pie_chart, iconColor: Colors.green, iconBgColor: Colors.green.withOpacity(0.1))),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search report name or category...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (val) => setState(() => _searchTerm = val),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final rep = filtered[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.analytics, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(rep['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(rep['description']!, style: const TextStyle(fontSize: 13, color: AppColors.lightMutedText)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloading ${rep['category']} PDF Report...')));
                            },
                            icon: const Icon(Icons.picture_as_pdf, size: 14, color: Colors.red),
                            label: const Text('PDF', style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloading ${rep['category']} Excel Report...')));
                            },
                            icon: const Icon(Icons.table_chart, size: 14),
                            label: const Text('Excel'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
    );
  }
}
