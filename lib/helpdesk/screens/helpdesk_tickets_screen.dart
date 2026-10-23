import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/helpdesk_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import 'create_ticket_screen.dart';
import 'ticket_detail_screen.dart';

class HelpdeskTicketsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const HelpdeskTicketsScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<HelpdeskTicketsScreen> createState() => _HelpdeskTicketsScreenState();
}

class _HelpdeskTicketsScreenState extends ConsumerState<HelpdeskTicketsScreen> {
  bool _isLoading = true;
  List<dynamic> _tickets = [];
  List<dynamic> _filteredTickets = [];
  String _searchQuery = '';
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    setState(() => _isLoading = true);
    try {
      final helpdeskSvc = ref.read(helpdeskServiceProvider);
      final res = await helpdeskSvc.getTickets();
      if (mounted) {
        setState(() {
          _tickets = res;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    List<dynamic> list = [..._tickets];
    if (_selectedFilter == 'open') {
      list = list.where((t) => t['status'] == 'OPEN').toList();
    } else if (_selectedFilter == 'in_progress') {
      list = list.where((t) => t['status'] == 'IN_PROGRESS' || t['status'] == 'WAITING_ON_EMPLOYEE').toList();
    } else if (_selectedFilter == 'escalated') {
      list = list.where((t) => t['status'] == 'ESCALATED').toList();
    } else if (_selectedFilter == 'resolved') {
      list = list.where((t) => t['status'] == 'RESOLVED' || t['status'] == 'CLOSED').toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) {
        final subject = (t['subject'] ?? '').toString().toLowerCase();
        final number = (t['ticketNumber'] ?? '').toString().toLowerCase();
        return subject.contains(q) || number.contains(q);
      }).toList();
    }

    _filteredTickets = list;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilter();
    });
  }

  void _onFilterSelected(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
  }

  void _navigateToCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateTicketScreen()),
    ).then((created) {
      if (created == true) _fetchTickets();
    });
  }

  void _navigateToDetail(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: id)),
    ).then((_) => _fetchTickets());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final skeleton = const ListSkeleton(itemCount: 4);
      if (!widget.showAppBar) return skeleton;
      return Scaffold(
        appBar: AppBar(title: const Text('Support Tickets')),
        body: skeleton,
      );
    }

    final body = RefreshIndicator(
      onRefresh: _fetchTickets,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Support Tickets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ElevatedButton.icon(
                  onPressed: _navigateToCreate,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Ticket'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search by subject or ticket #...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All Tickets'),
                  _buildFilterChip('open', 'Open'),
                  _buildFilterChip('in_progress', 'In Progress'),
                  _buildFilterChip('escalated', 'Escalated'),
                  _buildFilterChip('resolved', 'Resolved'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_filteredTickets.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('No tickets found.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredTickets.length,
                itemBuilder: (context, index) {
                  final ticket = _filteredTickets[index];
                  final id = ticket['id']?.toString() ?? '';
                  final ticketNumber = ticket['ticketNumber'] ?? 'TICKET-000';
                  final title = ticket['subject'] ?? 'Untitled Ticket';
                  final category = ticket['category'] ?? 'GENERAL';
                  final priority = ticket['priority'] ?? 'MEDIUM';
                  final status = ticket['status'] ?? 'OPEN';

                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    onTap: () {
                      if (id.isNotEmpty) _navigateToDetail(id);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(ticketNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12)),
                            StatusChip(status: status.toString()),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text('Category: $category', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const Spacer(),
                            Text('Priority: $priority', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warning)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );

    if (!widget.showAppBar) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Support Tickets')),
      body: body,
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _onFilterSelected(value),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
      ),
    );
  }
}
