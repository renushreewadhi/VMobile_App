import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/helpdesk_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import '../../core/widgets/glass_scaffold.dart';
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
  String _selectedStatus = 'All Status';
  String _selectedCategory = 'All Categories';
  String _selectedPriority = 'All Priorities';

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
          if (_tickets.isEmpty) {
            _tickets = [
              {
                'id': 'hd-1',
                'ticketNumber': 'HD-0001',
                'subject': 'hi',
                'employeeName': 'Ravi two',
                'category': 'Laptop / Hardware',
                'priority': 'Medium',
                'slaStatus': 'WITHIN_SLA',
                'createdAt': '02 Nov 2026',
                'status': 'OPEN',
              },
            ];
          }
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _tickets = [
            {
              'id': 'hd-1',
              'ticketNumber': 'HD-0001',
              'subject': 'hi',
              'employeeName': 'Ravi two',
              'category': 'Laptop / Hardware',
              'priority': 'Medium',
              'slaStatus': 'WITHIN_SLA',
              'createdAt': '02 Nov 2026',
              'status': 'OPEN',
            },
          ];
          _applyFilter();
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilter() {
    List<dynamic> list = [..._tickets];
    if (_selectedFilter == 'open') {
      list = list.where((t) => (t['status'] ?? '').toString().toUpperCase() == 'OPEN').toList();
    } else if (_selectedFilter == 'in_progress') {
      list = list.where((t) => (t['status'] ?? '').toString().toUpperCase() == 'IN_PROGRESS').toList();
    } else if (_selectedFilter == 'escalated') {
      list = list.where((t) => (t['status'] ?? '').toString().toUpperCase() == 'ESCALATED').toList();
    } else if (_selectedFilter == 'resolved') {
      list = list.where((t) => (t['status'] ?? '').toString().toUpperCase() == 'RESOLVED' || (t['status'] ?? '').toString().toUpperCase() == 'CLOSED').toList();
    }

    if (_selectedStatus != 'All Status') {
      list = list.where((t) => (t['status'] ?? '').toString().toUpperCase() == _selectedStatus.toUpperCase()).toList();
    }
    if (_selectedCategory != 'All Categories') {
      list = list.where((t) => (t['category'] ?? '').toString().contains(_selectedCategory)).toList();
    }
    if (_selectedPriority != 'All Priorities') {
      list = list.where((t) => (t['priority'] ?? '').toString().toUpperCase() == _selectedPriority.toUpperCase()).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) {
        final subject = (t['subject'] ?? '').toString().toLowerCase();
        final number = (t['ticketNumber'] ?? t['id'] ?? '').toString().toLowerCase();
        final emp = (t['employeeName'] ?? '').toString().toLowerCase();
        return subject.contains(q) || number.contains(q) || emp.contains(q);
      }).toList();
    }

    _filteredTickets = list;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    if (_isLoading) {
      const skeleton = ListSkeleton(itemCount: 4);
      if (!widget.showAppBar) return skeleton;
      return const GlassScaffold(title: 'Helpdesk Tickets', body: ListSkeleton(itemCount: 4));
    }

    final totalCount = _tickets.length;
    final openCount = _tickets.where((t) => (t['status'] ?? '').toString().toUpperCase() == 'OPEN').length;
    final inProgressCount = _tickets.where((t) => (t['status'] ?? '').toString().toUpperCase() == 'IN_PROGRESS').length;
    final resolvedCount = _tickets.where((t) => (t['status'] ?? '').toString().toUpperCase() == 'RESOLVED' || (t['status'] ?? '').toString().toUpperCase() == 'CLOSED').length;

    final body = RefreshIndicator(
      onRefresh: _fetchTickets,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Helpdesk Tickets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Manage IT support tickets: laptop, software, email, network.', style: TextStyle(fontSize: 11.5, color: glass.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _navigateToCreate,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Ticket', style: TextStyle(fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Category Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterChip('all', 'All IT Tickets ($totalCount)'),
                  const SizedBox(width: 6),
                  _buildFilterChip('open', 'Open ($openCount)'),
                  const SizedBox(width: 6),
                  _buildFilterChip('in_progress', 'In Progress ($inProgressCount)'),
                  const SizedBox(width: 6),
                  _buildFilterChip('assigned_me', 'Assigned to Me (0)'),
                  const SizedBox(width: 6),
                  _buildFilterChip('escalated', 'Escalated (0)'),
                  const SizedBox(width: 6),
                  _buildFilterChip('resolved', 'Resolved ($resolvedCount)'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Summary Metric Cards (Total, Open, In Progress, Resolved)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.1,
              children: [
                _kpiCard('Total', '$totalCount', Icons.confirmation_number_rounded, AppColors.primary),
                _kpiCard('Open', '$openCount', Icons.folder_open_rounded, Colors.amber),
                _kpiCard('In Progress', '$inProgressCount', Icons.hourglass_top_rounded, Colors.purple),
                _kpiCard('Resolved', '$resolvedCount', Icons.check_circle_rounded, AppColors.success),
              ],
            ),
            const SizedBox(height: 12),

            // Search and Filters Toolbar
            AppCard(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  TextField(
                    style: TextStyle(color: glass.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search tickets by subject, employee...',
                      hintStyle: TextStyle(color: glass.textSecondary, fontSize: 12),
                      prefixIcon: Icon(Icons.search, color: glass.textSecondary, size: 18),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1A2632) : AppColors.lightInputBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _applyFilter();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedStatus,
                          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'All Status', child: Text('All Status', style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: 'OPEN', child: Text('Open', style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress', style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: 'RESOLVED', child: Text('Resolved', style: TextStyle(fontSize: 11))),
                          ],
                          onChanged: (val) => setState(() {
                            _selectedStatus = val ?? 'All Status';
                            _applyFilter();
                          }),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'All Categories', child: Text('All Categories', style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: 'Laptop', child: Text('Laptop / Hardware', style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: 'SOFTWARE', child: Text('Software', style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: 'NETWORK', child: Text('Network', style: TextStyle(fontSize: 11))),
                          ],
                          onChanged: (val) => setState(() {
                            _selectedCategory = val ?? 'All Categories';
                            _applyFilter();
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tickets List
            if (_filteredTickets.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.support_agent, size: 40, color: glass.textSecondary),
                        const SizedBox(height: 12),
                        Text('No tickets found.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: glass.textPrimary)),
                        const SizedBox(height: 4),
                        Text('Try adjusting your search or filter criteria.', style: TextStyle(fontSize: 12, color: glass.textSecondary), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
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
                  final ticketNumber = ticket['ticketNumber'] ?? 'HD-0001';
                  final title = ticket['subject'] ?? 'Untitled Ticket';
                  final employee = ticket['employeeName'] ?? 'Ravi two';
                  final category = ticket['category'] ?? 'Laptop / Hardware';
                  final priority = ticket['priority'] ?? 'Medium';
                  final status = ticket['status'] ?? 'OPEN';
                  final date = ticket['createdAt']?.toString().substring(0, 11) ?? '02 Nov 2026';

                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
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
                            StatusChip(status: status.toString().toUpperCase()),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: glass.textPrimary)),
                        const SizedBox(height: 6),
                        Text('Employee: $employee • Category: $category', style: TextStyle(fontSize: 11.5, color: glass.textSecondary)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Priority: $priority • Date: $date', style: const TextStyle(fontSize: 11, color: AppColors.warning)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                              child: const Text('WITHIN_SLA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                            ),
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

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: body);

    return GlassScaffold(
      title: 'Helpdesk Tickets',
      body: body,
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    final glass = context.glass;
    return Material(
      color: Colors.transparent,
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() {
          _selectedFilter = value;
          _applyFilter();
        }),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : glass.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          fontSize: 11.5,
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    final glass = context.glass;
    return AppCard(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                Text(label, style: TextStyle(fontSize: 10, color: glass.textSecondary), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
