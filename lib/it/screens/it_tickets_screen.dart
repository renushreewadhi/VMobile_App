import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class ItTicketsScreen extends ConsumerStatefulWidget {
  const ItTicketsScreen({super.key});

  @override
  ConsumerState<ItTicketsScreen> createState() => _ItTicketsScreenState();
}

class _ItTicketsScreenState extends ConsumerState<ItTicketsScreen> {
  bool _isLoading = true;
  List<dynamic> _tickets = [];
  String _statusFilter = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get(ApiEndpoints.itTickets).catchError((_) => null);
      if (mounted) {
        setState(() {
          if (res is List) {
            _tickets = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _tickets = res['data'];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const ListSkeleton(itemCount: 4);

    final filtered = _tickets.where((t) {
      final status = (t['status'] ?? 'OPEN').toString();
      final matchesStatus = _statusFilter == 'ALL' || status == _statusFilter;
      final subject = (t['subject'] ?? t['title'] ?? '').toString().toLowerCase();
      final empName = (t['employeeName'] ?? t['empName'] ?? '').toString().toLowerCase();
      final matchesSearch = subject.contains(_searchQuery.toLowerCase()) || empName.contains(_searchQuery.toLowerCase());
      return matchesStatus && matchesSearch;
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchTickets,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('IT Support Ticket Queue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search tickets or employees...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['ALL', 'OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'].map((status) {
                  final isSelected = _statusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(status.replaceAll('_', ' ')),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                      onSelected: (_) => setState(() => _statusFilter = status),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No IT tickets found.')),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final t = filtered[index];
                  final subject = t['subject'] ?? t['title'] ?? 'Support Request';
                  final priority = t['priority'] ?? 'MEDIUM';
                  final status = t['status'] ?? 'OPEN';
                  final requester = t['employeeName'] ?? t['requesterName'] ?? 'Employee';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(subject.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ),
                              StatusChip(status: status.toString()),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text('Priority: $priority', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning)),
                              const SizedBox(width: 12),
                              Text('Requester: $requester', style: const TextStyle(fontSize: 12, color: AppColors.lightMutedText)),
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
  }
}
