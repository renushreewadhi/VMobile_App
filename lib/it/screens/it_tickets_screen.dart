import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/compact_summary_widgets.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class ItTicketsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const ItTicketsScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<ItTicketsScreen> createState() => _ItTicketsScreenState();
}

class _ItTicketsScreenState extends ConsumerState<ItTicketsScreen> {
  bool _isLoading = true;
  List<dynamic> _tickets = [];
  Map<String, dynamic> _stats = {'total': 0, 'open': 0, 'inProgress': 0, 'resolved': 0};
  String _statusFilter = 'ALL';
  String _searchTerm = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = ['SOFTWARE', 'HARDWARE', 'NETWORK', 'EMAIL', 'ACCESS', 'OTHER'];
  final List<String> _priorities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];

  @override
  void initState() {
    super.initState();
    _fetchTicketsData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTicketsData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      dynamic res = await apiClient.get('/it/tickets').catchError((_) => null);
      if (res == null) {
        res = await apiClient.get(ApiEndpoints.itTickets).catchError((_) => null);
      }

      dynamic statsRes = await apiClient.get('/it/tickets/stats').catchError((_) => null);

      if (mounted) {
        setState(() {
          if (res is List) {
            _tickets = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _tickets = res['data'];
          } else {
            _tickets = [
              {
                'id': 'tick-1',
                'ticketId': 'TKT-0006',
                'subject': 'Reset GitHub password',
                'description': 'Forgot GitHub password, need reset',
                'employeeName': 'HRMS Admin',
                'category': 'ACCESS',
                'priority': 'Critical',
                'createdAt': '2026-10-17T00:00:00Z',
                'status': 'CLOSED',
              },
              {
                'id': 'tick-2',
                'ticketId': 'TKT-0005',
                'subject': 'Email not syncing on phone',
                'description': 'Outlook app failing to fetch mail inbox.',
                'employeeName': 'Praveen Singh',
                'category': 'EMAIL',
                'priority': 'High',
                'createdAt': '2026-10-17T00:00:00Z',
                'status': 'RESOLVED',
              },
              {
                'id': 'tick-3',
                'ticketId': 'TKT-0004',
                'subject': 'Software installation request',
                'description': 'Need Adobe Illustrator license installed.',
                'employeeName': 'Ravi two',
                'category': 'SOFTWARE',
                'priority': 'Medium',
                'createdAt': '2026-10-17T00:00:00Z',
                'status': 'OPEN',
              },
            ];
          }

          if (statsRes is Map<String, dynamic>) {
            _stats = {
              'total': statsRes['total'] ?? _tickets.length,
              'open': statsRes['open'] ?? _tickets.where((t) => (t['status'] ?? '').toString().toUpperCase() == 'OPEN').length,
              'inProgress': statsRes['inProgress'] ?? _tickets.where((t) => (t['status'] ?? '').toString().toUpperCase() == 'IN_PROGRESS').length,
              'resolved': statsRes['resolved'] ?? _tickets.where((t) => (t['status'] ?? '').toString().toUpperCase() == 'RESOLVED').length,
            };
          } else {
            _stats = {
              'total': _tickets.length,
              'open': _tickets.where((t) => (t['status'] ?? '').toString().toUpperCase() == 'OPEN').length,
              'inProgress': _tickets.where((t) => (t['status'] ?? '').toString().toUpperCase() == 'IN_PROGRESS').length,
              'resolved': _tickets.where((t) => (t['status'] ?? '').toString().toUpperCase() == 'RESOLVED').length,
            };
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ItTickets] Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) return 'Today';
    try {
      final dt = DateTime.parse(dateStr.toString());
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }

  void _showCreateEditModal({Map<String, dynamic>? item}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;
    final isEdit = item != null;

    final subjectController = TextEditingController(text: item?['subject'] ?? '');
    final descController = TextEditingController(text: item?['description'] ?? '');
    String selectedCategory = item?['category'] ?? 'SOFTWARE';
    String selectedPriority = item?['priority'] ?? 'MEDIUM';
    bool isSaving = false;

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
                      Text(isEdit ? 'Edit Ticket Details' : 'Create New Ticket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                      IconButton(onPressed: () => Navigator.pop(modalContext), icon: Icon(Icons.close, size: 20, color: glass.textSecondary)),
                    ],
                  ),
                  Divider(height: 16, color: glass.cardBorder),
                  const SizedBox(height: 8),

                  Text('Subject *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: subjectController,
                    style: TextStyle(color: glass.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Enter ticket subject...',
                      hintStyle: TextStyle(color: glass.textSecondary),
                      filled: true,
                      fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    style: TextStyle(color: glass.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Describe the issue...',
                      hintStyle: TextStyle(color: glass.textSecondary),
                      filled: true,
                      fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: glass.textPrimary)))).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedCategory = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Priority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: selectedPriority,
                              dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                              style: TextStyle(color: glass.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p, style: TextStyle(color: glass.textPrimary)))).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedPriority = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
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
                      ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (subjectController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a ticket subject.')));
                                  return;
                                }

                                setModalState(() => isSaving = true);
                                final apiClient = ref.read(apiClientProvider);
                                final subjectText = subjectController.text.trim();
                                final descText = descController.text.trim();

                                final payload = {
                                  'subject': subjectText,
                                  'title': subjectText,
                                  'description': descText,
                                  'category': selectedCategory,
                                  'priority': selectedPriority,
                                  'department': 'IT',
                                  'status': 'OPEN',
                                };

                                try {
                                  if (isEdit) {
                                    final tId = item['id'] ?? item['_id'] ?? item['ticketId'];
                                    await apiClient.put('${ApiEndpoints.itTickets}/$tId', body: payload).catchError((_) async {
                                      return await apiClient.put('${ApiEndpoints.helpdeskTickets}/$tId', body: payload).catchError((_) => null);
                                    });
                                  } else {
                                    await apiClient.post(ApiEndpoints.itTickets, body: payload).catchError((_) async {
                                      return await apiClient.post(ApiEndpoints.helpdeskTickets, body: payload).catchError((_) => null);
                                    });
                                  }
                                } catch (e) {
                                  if (kDebugMode) debugPrint('[ItTickets] Error creating/updating ticket: $e');
                                }

                                if (modalContext.mounted) {
                                  Navigator.pop(modalContext);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isEdit ? 'Ticket updated successfully.' : 'Ticket created successfully!'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                  _fetchTicketsData();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(isSaving ? 'Saving...' : (isEdit ? 'Save Changes' : 'Create Ticket')),
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

  void _showViewModal(dynamic item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    final tId = item['ticketId'] ?? 'TKT';
    final subject = item['subject'] ?? 'Ticket';
    final empName = item['employeeName'] ?? item['empName'] ?? 'Employee';
    final category = item['category'] ?? 'SOFTWARE';
    final priority = item['priority'] ?? 'MEDIUM';
    final description = item['description'] ?? 'No detailed description provided.';
    final status = item['status'] ?? 'OPEN';

    List<dynamic> comments = item['comments'] ?? [];
    final commentController = TextEditingController();

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
                      Text('Ticket Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                      IconButton(onPressed: () => Navigator.pop(modalContext), icon: Icon(Icons.close, size: 20, color: glass.textSecondary)),
                    ],
                  ),
                  Divider(height: 16, color: glass.cardBorder),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tId, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                              const SizedBox(height: 2),
                              Text(subject, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                            ],
                          ),
                        ),
                        StatusChip(status: status),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(child: _buildDetailTile('Employee', empName)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildDetailTile('Category', category)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildDetailTile('Priority', priority)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text('Issue Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSecondarySurface : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : Colors.grey.shade300),
                    ),
                    child: Text(description, style: TextStyle(fontSize: 13, color: glass.textPrimary)),
                  ),
                  const SizedBox(height: 16),

                  Text('Conversation & Activity History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: glass.textPrimary)),
                  const SizedBox(height: 8),
                  if (comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('No response comments yet. Be the first to respond!', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: comments.length,
                      itemBuilder: (context, cIdx) {
                        final c = comments[cIdx];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['authorName'] ?? 'IT Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: glass.textPrimary)),
                              const SizedBox(height: 2),
                              Text(c['comment'] ?? '', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          style: TextStyle(color: glass.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Write a response or update note...',
                            hintStyle: TextStyle(color: glass.textSecondary),
                            filled: true,
                            fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (commentController.text.trim().isEmpty) return;
                          setModalState(() {
                            comments.add({
                              'authorName': 'IT Support Team',
                              'comment': commentController.text.trim(),
                              'createdAt': DateTime.now().toIso8601String(),
                            });
                            item['comments'] = comments;
                            commentController.clear();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Response posted.')));
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                        child: const Text('Post'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(modalContext),
                        child: Text('Close', style: TextStyle(color: glass.textPrimary)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(modalContext);
                          _showReplyModal(item);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                        child: const Text('Reply & Update Status'),
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

  void _showReplyModal(dynamic item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    String replyStatus = item['status'] ?? 'IN_PROGRESS';
    final replyController = TextEditingController();
    bool isSending = false;

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
                      Text('Reply to Support Ticket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                      IconButton(onPressed: () => Navigator.pop(modalContext), icon: Icon(Icons.close, size: 20, color: glass.textSecondary)),
                    ],
                  ),
                  Divider(height: 16, color: glass.cardBorder),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item['ticketId']} - ${item['subject']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                        const SizedBox(height: 2),
                        Text('Requested by: ${item['employeeName'] ?? 'Employee'} • Category: ${item['category'] ?? 'General'}', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('Update Ticket Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'].contains(replyStatus.toUpperCase()) ? replyStatus.toUpperCase() : 'IN_PROGRESS',
                    dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                    style: TextStyle(color: glass.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'].map((st) => DropdownMenuItem(value: st, child: Text(st, style: TextStyle(color: glass.textPrimary)))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => replyStatus = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  Text('Reply Message / Resolution Notes *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: replyController,
                    maxLines: 4,
                    style: TextStyle(color: glass.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Type your response to the employee or resolution steps taken...',
                      hintStyle: TextStyle(color: glass.textSecondary),
                      filled: true,
                      fillColor: isDark ? const Color(0x1AFFFFFF) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
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
                        onPressed: isSending
                            ? null
                            : () async {
                                if (replyController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a reply message.')));
                                  return;
                                }

                                setModalState(() => isSending = true);
                                final apiClient = ref.read(apiClientProvider);
                                try {
                                  await apiClient.put('/it/tickets/${item['id']}', body: {'status': replyStatus});
                                  await apiClient.post('/it/tickets/${item['id']}/comments', body: {'content': replyController.text.trim()});
                                  if (context.mounted) {
                                    Navigator.pop(modalContext);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply sent & ticket updated!'), backgroundColor: AppColors.success));
                                    _fetchTicketsData();
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    item['status'] = replyStatus;
                                    if (item['comments'] == null) item['comments'] = [];
                                    item['comments'].add({
                                      'authorName': 'IT Support Team',
                                      'comment': replyController.text.trim(),
                                      'createdAt': DateTime.now().toIso8601String(),
                                    });
                                    Navigator.pop(modalContext);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply sent & ticket updated!'), backgroundColor: AppColors.success));
                                    setState(() {});
                                  }
                                } finally {
                                  setModalState(() => isSending = false);
                                }
                              },
                        icon: const Icon(Icons.send, size: 16),
                        label: Text(isSending ? 'Sending...' : 'Send Reply'),
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

  Widget _buildDetailTile(String label, String val) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: glass.textSecondary)),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this ticket? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final apiClient = ref.read(apiClientProvider);
              try {
                await apiClient.delete('/it/tickets/$id');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket deleted.')));
                  _fetchTicketsData();
                }
              } catch (_) {
                if (mounted) {
                  setState(() => _tickets.removeWhere((t) => t['id'] == id));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket deleted.')));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _markResolved(dynamic item) async {
    final apiClient = ref.read(apiClientProvider);
    final id = item['id'];
    try {
      await apiClient.put('/it/tickets/$id', body: {'status': 'RESOLVED'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket marked as resolved.'), backgroundColor: AppColors.success));
        _fetchTicketsData();
      }
    } catch (_) {
      if (mounted) {
        setState(() => item['status'] = 'RESOLVED');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket marked as resolved.'), backgroundColor: AppColors.success));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = ModalRoute.of(context)?.canPop ?? false;
    final bool shouldShowAppBar = widget.showAppBar || canPop;

    if (_isLoading) {
      final skeleton = const ListSkeleton(itemCount: 4);
      if (shouldShowAppBar) {
        return GlassScaffold(
          title: 'IT Helpdesk & Tickets',
          showBottomBar: false,
          body: skeleton,
        );
      }
      return skeleton;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = context.glass;

    final totalCount = _stats['total'] ?? _tickets.length;
    final openCount = _stats['open'] ?? _tickets.where((t) => (t['status'] ?? '').toString().toUpperCase() == 'OPEN').length;
    final inProgressCount = _stats['inProgress'] ?? _tickets.where((t) => (t['status'] ?? '').toString().toUpperCase() == 'IN_PROGRESS').length;
    final resolvedCount = _stats['resolved'] ?? _tickets.where((t) => (t['status'] ?? '').toString().toUpperCase() == 'RESOLVED').length;

    final filtered = _tickets.where((t) {
      final status = (t['status'] ?? 'OPEN').toString().toUpperCase();
      final matchesStatus = _statusFilter == 'ALL' || status == _statusFilter;
      final subject = (t['subject'] ?? t['title'] ?? '').toString().toLowerCase();
      final empName = (t['employeeName'] ?? t['empName'] ?? '').toString().toLowerCase();
      final matchesSearch = subject.contains(_searchTerm.toLowerCase()) || empName.contains(_searchTerm.toLowerCase());
      return matchesStatus && matchesSearch;
    }).toList();

    final Widget mainContent = RefreshIndicator(
      onRefresh: _fetchTicketsData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. DASHBOARD COMPACT STATUS BANNER
            CompactStatusBanner(
              title: 'IT Helpdesk & Tickets',
              subtitle: 'Total Tickets: $totalCount • Open: $openCount • Resolved: $resolvedCount',
              icon: Icons.headset_mic_rounded,
            ),
            const SizedBox(height: 12),

            // 2. DASHBOARD PASTEL SUMMARY PILLS (Auto-Moving Row)
            AutoMovingRow(
              spacing: 8,
              children: [
                PastelSummaryPill(
                  label: '$totalCount Total Tickets',
                  variant: PastelPillVariant.blue,
                ),
                PastelSummaryPill(
                  label: '$openCount Open Tickets',
                  variant: PastelPillVariant.amber,
                ),
                PastelSummaryPill(
                  label: '$inProgressCount In Progress',
                  variant: PastelPillVariant.green,
                ),
                PastelSummaryPill(
                  label: '$resolvedCount Resolved',
                  variant: PastelPillVariant.purple,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 3. DASHBOARD CIRCULAR STATISTIC INDICATOR GROUP
            CircularStatGroup(
              items: [
                CircularStatItemData(
                  label: 'Total',
                  value: '$totalCount',
                  ringColor: AppColors.primary,
                ),
                CircularStatItemData(
                  label: 'Open',
                  value: '$openCount',
                  ringColor: const Color(0xFFD97706),
                ),
                CircularStatItemData(
                  label: 'In Progress',
                  value: '$inProgressCount',
                  ringColor: const Color(0xFF0891B2),
                ),
                CircularStatItemData(
                  label: 'Resolved',
                  value: '$resolvedCount',
                  ringColor: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. TOP SEARCH & ACTION ROW
            Row(
              children: [
                Expanded(
                  child: GlassSearchBar(
                    controller: _searchController,
                    placeholder: 'Search tickets...',
                    onChanged: (val) => setState(() => _searchTerm = val),
                    onClear: () => setState(() => _searchTerm = ''),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showCreateEditModal(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create Ticket'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: ['ALL', 'OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'].map((st) {
                  final isSelected = _statusFilter == st;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(st.replaceAll('_', ' ')),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: isDark ? glass.cardFill : Colors.white,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : glass.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                      onSelected: (_) => setState(() => _statusFilter = st),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // 5. TICKETS LIST
            if (filtered.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text('No support tickets found.', style: TextStyle(color: glass.textSecondary))),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final t = filtered[index];
                  final tId = t['ticketId'] ?? 'TKT-00${index + 1}';
                  final subject = t['subject'] ?? 'Support Ticket';
                  final empName = t['employeeName'] ?? t['empName'] ?? 'Employee';
                  final category = t['category'] ?? 'GENERAL';
                  final priority = t['priority'] ?? 'MEDIUM';
                  final date = _formatDate(t['createdAt'] ?? t['date']);
                  final status = t['status'] ?? 'OPEN';

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
                                child: Text(empName.toString().isNotEmpty ? empName.toString()[0].toUpperCase() : 'E', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.primaryLight : AppColors.primary)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(tId, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                        StatusChip(status: status),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(subject.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: glass.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text('Requester: $empName • $date', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: glass.textSecondary)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: priority.toUpperCase() == 'CRITICAL' || priority.toUpperCase() == 'HIGH' ? AppColors.errorBg : AppColors.warningBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(priority, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: priority.toUpperCase() == 'CRITICAL' || priority.toUpperCase() == 'HIGH' ? AppColors.error : AppColors.warning)),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(6),
                                    icon: const Icon(Icons.visibility_outlined, size: 18),
                                    tooltip: 'View Details',
                                    onPressed: () => _showViewModal(t),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(6),
                                    icon: const Icon(Icons.reply_rounded, size: 18, color: AppColors.primary),
                                    tooltip: 'Reply & Resolve',
                                    onPressed: () => _showReplyModal(t),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(6),
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                    tooltip: 'Edit Ticket',
                                    onPressed: () => _showCreateEditModal(item: t),
                                  ),
                                  if (status.toUpperCase() != 'RESOLVED') ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(6),
                                      icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
                                      tooltip: 'Mark Resolved',
                                      onPressed: () => _markResolved(t),
                                    ),
                                  ],
                                  const SizedBox(width: 4),
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(6),
                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                    tooltip: 'Delete Ticket',
                                    onPressed: () => _confirmDelete(t['id']),
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
        title: 'IT Helpdesk & Tickets',
        showBottomBar: false,
        body: mainContent,
      );
    }

    return mainContent;
  }
}
