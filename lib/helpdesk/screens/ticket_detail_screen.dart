import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/helpdesk_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';

class TicketDetailScreen extends ConsumerStatefulWidget {
  final String ticketId;

  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _ticket;
  List<dynamic> _comments = [];
  final _commentController = TextEditingController();
  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final helpdeskSvc = ref.read(helpdeskServiceProvider);
      final ticketRes = await helpdeskSvc.getTicket(widget.ticketId);
      final commentsRes = await helpdeskSvc.getComments(widget.ticketId);

      if (mounted) {
        setState(() {
          _ticket = ticketRes;
          _comments = commentsRes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSendingComment) return;

    setState(() => _isSendingComment = true);
    try {
      final helpdeskSvc = ref.read(helpdeskServiceProvider);
      await helpdeskSvc.addComment(widget.ticketId, {'content': text});
      _commentController.clear();
      final commentsRes = await helpdeskSvc.getComments(widget.ticketId);
      if (mounted) {
        setState(() {
          _comments = commentsRes;
          _isSendingComment = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  Future<void> _resolveTicket() async {
    final controller = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve Ticket'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Resolution note'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Resolve')),
        ],
      ),
    );

    if (res != null) {
      try {
        final helpdeskSvc = ref.read(helpdeskServiceProvider);
        await helpdeskSvc.resolveTicket(widget.ticketId, res);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _escalateTicket() async {
    final controller = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escalate Ticket'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason for escalation'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Escalate')),
        ],
      ),
    );

    if (res != null) {
      try {
        final helpdeskSvc = ref.read(helpdeskServiceProvider);
        await helpdeskSvc.escalateTicket(widget.ticketId, res);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _closeTicket() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Ticket'),
        content: const Text('Are you sure you want to close this ticket?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Close')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final helpdeskSvc = ref.read(helpdeskServiceProvider);
        await helpdeskSvc.closeTicket(widget.ticketId);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'OPEN':
        return Colors.blue;
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'WAITING_ON_EMPLOYEE':
        return Colors.purple;
      case 'ESCALATED':
        return Colors.red;
      case 'RESOLVED':
      case 'CLOSED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const GlassScaffold(
        title: 'Ticket Details',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_ticket == null) {
      return const GlassScaffold(
        title: 'Ticket Details',
        body: Center(child: Text('Ticket not found')),
      );
    }

    final ticket = _ticket!;
    final status = ticket['status'] ?? 'OPEN';
    final priority = ticket['priority'] ?? 'MEDIUM';
    final ticketNumber = ticket['ticketNumber'] ?? 'Ticket Details';

    List<Widget>? headerActions;
    if (status != 'CLOSED' && status != 'RESOLVED') {
      headerActions = [
        IconButton(
          icon: const Icon(Icons.check_circle_outline),
          tooltip: 'Resolve',
          onPressed: _resolveTicket,
        ),
        IconButton(
          icon: const Icon(Icons.arrow_upward),
          tooltip: 'Escalate',
          onPressed: _escalateTicket,
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: _closeTicket,
        ),
      ];
    }

    return GlassScaffold(
      appBar: GlassHeader(
        title: ticketNumber,
        actions: headerActions,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _getStatusColor(status)),
                        ),
                        child: Text(
                          status.replaceAll('_', ' '),
                          style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Priority: $priority',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        ticket['department'] ?? '',
                        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ticket['subject'] ?? '',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Category: ${ticket['category'] ?? ''}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text(ticket['description'] ?? 'No description provided.', style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 24),
                  const Text('Comments & Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  if (_comments.isEmpty)
                    const Text('No comments yet.', style: TextStyle(color: Colors.grey))
                  else
                    ..._comments.map((c) => AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    c['authorName'] ?? c['userName'] ?? 'User',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  Text(
                                    c['createdAt'] != null ? c['createdAt'].toString().substring(0, 10) : '',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(c['content'] ?? c['text'] ?? ''),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ),
          if (status != 'CLOSED')
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Type a comment or update...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isSendingComment
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send, color: AppColors.primary),
                    onPressed: _isSendingComment ? null : _addComment,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
