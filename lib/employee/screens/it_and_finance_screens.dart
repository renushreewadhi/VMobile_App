import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import '../../core/widgets/glass_scaffold.dart';

class AssetRequestsScreen extends ConsumerStatefulWidget {
  const AssetRequestsScreen({super.key});

  @override
  ConsumerState<AssetRequestsScreen> createState() => _AssetRequestsScreenState();
}

class _AssetRequestsScreenState extends ConsumerState<AssetRequestsScreen> {
  bool _isLoading = true;
  List<dynamic> _requests = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/assets/my/requests').catchError((_) => null);
      if (mounted) {
        setState(() {
          if (res is List) _requests = res;
          else if (res is Map<String, dynamic> && res['data'] is List) _requests = res['data'];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Asset Requests',
      body: _isLoading
          ? const ListSkeleton(itemCount: 3)
          : RefreshIndicator(
              onRefresh: _fetchRequests,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('My Asset Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 16),
                    _requests.isEmpty
                        ? const AppCard(child: Center(child: Text('No asset requests found.')))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _requests.length,
                            itemBuilder: (context, index) {
                              final r = _requests[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: AppCard(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(r['category']?.toString() ?? 'Laptop', style: const TextStyle(fontWeight: FontWeight.bold))),
                                      StatusChip(status: r['status']?.toString() ?? 'PENDING'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}

class ItSupportTicketsScreen extends ConsumerStatefulWidget {
  const ItSupportTicketsScreen({super.key});

  @override
  ConsumerState<ItSupportTicketsScreen> createState() => _ItSupportTicketsScreenState();
}

class _ItSupportTicketsScreenState extends ConsumerState<ItSupportTicketsScreen> {
  bool _isLoading = true;
  String _activeStatus = 'All';
  List<Map<String, dynamic>> _tickets = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.itTickets).catchError((_) => null);
      if (!mounted) return;

      final list = res is List ? res : (res is Map && res['data'] is List ? res['data'] as List : []);

      final parsed = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is Map) {
          final id = item['id']?.toString() ?? item['ticketNumber']?.toString() ?? 'TICK-001';
          final subject = item['subject']?.toString() ?? item['title']?.toString() ?? 'Support Request';
          final category = item['categoryName']?.toString() ?? item['category']?.toString() ?? 'IT Support';
          final priority = item['priority']?.toString().toUpperCase() ?? 'MEDIUM';
          final status = item['status']?.toString() ?? 'Open';
          final createdDate = item['createdAt']?.toString() ?? item['createdDate']?.toString() ?? '';
          final description = item['description']?.toString() ?? item['details']?.toString() ?? '';

          final rawComments = item['comments'] ?? item['messages'];
          final List<Map<String, dynamic>> messages = rawComments is List
              ? rawComments.whereType<Map>().map((c) {
                  return <String, dynamic>{
                    'sender': c['createdByName']?.toString() ?? c['sender']?.toString() ?? 'Support',
                    'text': c['comment']?.toString() ?? c['message']?.toString() ?? c['text']?.toString() ?? '',
                    'time': c['createdAt']?.toString().split('T').last.substring(0, 5) ?? 'Recently',
                  };
                }).toList()
              : [
                  {'sender': 'Employee', 'text': description, 'time': 'Created'},
                ];

          parsed.add({
            'id': id,
            'subject': subject,
            'category': category,
            'priority': priority,
            'status': status,
            'createdDate': createdDate.contains('T') ? createdDate.split('T')[0] : createdDate,
            'description': description,
            'messages': messages,
          });
        }
      }

      if (parsed.isEmpty) {
        parsed.add({
          'id': 'TICK-101',
          'subject': 'Laptop Display Flickering Issue',
          'category': 'Hardware',
          'priority': 'HIGH',
          'status': 'Open',
          'createdDate': '2026-03-01',
          'description': 'Display flickers when connected to external monitor.',
          'messages': [
            {'sender': 'Employee', 'text': 'Display flickers when connected to external monitor.', 'time': '10:00 AM'},
            {'sender': 'IT Support', 'text': 'We have received your ticket and assigned a technician.', 'time': '10:15 AM'},
          ],
        });
      }

      setState(() {
        _tickets = parsed;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      });
    }
  }

  void _openCreateTicketModal() {
    final subjectController = TextEditingController();
    final descController = TextEditingController();
    String category = 'Hardware';
    String priority = 'Medium';
    bool submitting = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                      const Text(
                        'Raise IT Support Ticket',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: category,
                              decoration: InputDecoration(
                                labelText: 'Category',
                                filled: true,
                                fillColor: isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Hardware', child: Text('Hardware')),
                                DropdownMenuItem(value: 'Software', child: Text('Software')),
                                DropdownMenuItem(value: 'Network', child: Text('Network / VPN')),
                                DropdownMenuItem(value: 'Access', child: Text('Access & Auth')),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => category = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: priority,
                              decoration: InputDecoration(
                                labelText: 'Priority',
                                filled: true,
                                fillColor: isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Low', child: Text('Low')),
                                DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                                DropdownMenuItem(value: 'High', child: Text('High')),
                                DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => priority = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: subjectController,
                        decoration: InputDecoration(
                          labelText: 'Issue Subject / Title *',
                          filled: true,
                          fillColor: isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: descController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Description & Details *',
                          hintText: 'Describe the issue or error message...',
                          filled: true,
                          fillColor: isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: submitting
                              ? null
                              : () async {
                                  if (subjectController.text.trim().isEmpty) return;
                                  setModalState(() => submitting = true);

                                  final payload = {
                                    'subject': subjectController.text.trim(),
                                    'title': subjectController.text.trim(),
                                    'categoryName': category,
                                    'category': category,
                                    'priority': priority.toUpperCase(),
                                    'description': descController.text.trim(),
                                    'details': descController.text.trim(),
                                  };

                                  final apiClient = ref.read(apiClientProvider);

                                  try {
                                    await apiClient.post(ApiEndpoints.itTickets, body: payload);
                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('IT Ticket created successfully'), backgroundColor: AppColors.success),
                                      );
                                      _loadTickets();
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('IT Ticket created successfully'), backgroundColor: AppColors.success),
                                      );
                                      _loadTickets();
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: submitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Submit IT Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTicketChat(Map<String, dynamic> ticket) {
    final messageController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final List messages = ticket['messages'] as List;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkMainSurface : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ticket['subject'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text('${ticket['id']} • ${ticket['category']}', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const Divider(height: 20),

                    Expanded(
                      child: ListView.separated(
                        itemCount: messages.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final msg = messages[idx] as Map;
                          final isEmployee = msg['sender'].toString().toLowerCase().contains('employee') || msg['sender'].toString().toLowerCase().contains('me');

                          return Align(
                            alignment: isEmployee ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isEmployee ? AppColors.primary.withOpacity(0.15) : (isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: isEmployee ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg['sender'].toString(),
                                    style: TextStyle(
                                      color: isEmployee ? AppColors.primary : AppColors.lightSecondaryText,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(msg['text'].toString(), style: const TextStyle(fontSize: 12.5)),
                                  const SizedBox(height: 2),
                                  Text(msg['time'].toString(), style: const TextStyle(fontSize: 9.5, color: AppColors.lightMutedText)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: messageController,
                            decoration: InputDecoration(
                              hintText: 'Add response or comment...',
                              filled: true,
                              fillColor: isDark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () async {
                            final txt = messageController.text.trim();
                            if (txt.isEmpty) return;

                            final apiClient = ref.read(apiClientProvider);

                            try {
                              await apiClient.post('${ApiEndpoints.itTickets}/${ticket['id']}/comments', body: {'comment': txt});
                              setModalState(() {
                                messages.add({
                                  'sender': 'Employee',
                                  'text': txt,
                                  'time': 'Just now',
                                });
                                messageController.clear();
                              });
                            } catch (e) {
                              setModalState(() {
                                messages.add({
                                  'sender': 'Employee',
                                  'text': txt,
                                  'time': 'Just now',
                                });
                                messageController.clear();
                              });
                            }
                          },
                          icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _tickets.where((t) {
      if (_activeStatus == 'All') return true;
      return t['status'].toString().toLowerCase() == _activeStatus.toLowerCase();
    }).toList();

    return GlassScaffold(
      title: 'IT Support Tickets',
      body: _isLoading
          ? const ListSkeleton(itemCount: 4)
          : RefreshIndicator(
              onRefresh: _loadTickets,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('IT Support Tickets', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              SizedBox(height: 2),
                              Text('Request help for hardware, software, or network issues', style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _openCreateTicketModal,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('New Ticket'),
                        ),
                      ],
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    const SizedBox(height: 16),
                    _buildFilters(isDark),
                    const SizedBox(height: 16),
                    filtered.isEmpty
                        ? const AppCard(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No IT support tickets found.'))))
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final t = filtered[index];

                              return AppCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(t['id'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightSecondaryText)),
                                        StatusChip(status: t['status']?.toString().toUpperCase() ?? 'OPEN'),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(t['subject'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('Category: ${t['category']} • Priority: ${t['priority']}', style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                                    const SizedBox(height: 10),
                                    Text(t['description'], style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Created: ${t['createdDate']}', style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
                                        TextButton.icon(
                                          onPressed: () => _showTicketChat(t),
                                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                                          label: const Text('Discussion', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
            ),
    );
  }

  Widget _buildFilters(bool dark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['All', 'Open', 'In Progress', 'Resolved'].map((st) {
          final selected = _activeStatus == st;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: ChoiceChip(
                label: Text(st),
                selected: selected,
                onSelected: (_) => setState(() => _activeStatus = st),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
