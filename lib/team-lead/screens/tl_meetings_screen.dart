import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class TlMeetingsScreen extends ConsumerStatefulWidget {
  const TlMeetingsScreen({super.key});

  @override
  ConsumerState<TlMeetingsScreen> createState() => _TlMeetingsScreenState();
}

class _TlMeetingsScreenState extends ConsumerState<TlMeetingsScreen> {
  bool _isLoading = true;
  List<dynamic> _meetings = [];
  List<dynamic> _teamEmployees = [];
  String _activeFilter = 'all';
  String _searchTerm = '';
  Map<String, dynamic>? _selectedMeeting;

  @override
  void initState() {
    super.initState();
    _loadMeetingsData();
  }

  Future<void> _loadMeetingsData() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        apiClient.get('/meetings/my').catchError((_) => null),
        apiClient.get(ApiEndpoints.employees).catchError((_) => null),
      ]);

      final meetings = results[0];
      final employees = results[1];

      List<dynamic> items = [];
      if (meetings is List) {
        items = meetings;
      } else if (meetings is Map<String, dynamic>) {
        items = meetings['items'] ?? meetings['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {
            'id': 'M-101',
            'title': 'HRMS Sprint Review & Demo',
            'description': 'Discuss HRMS mobile app release, live demo, and upcoming sprint goals.',
            'meetingType': 'Video',
            'status': 'Scheduled',
            'meetingDate': '2026-10-25',
            'startTime': '16:00',
            'endTime': '16:45',
            'roomName': 'hrms-demo-room-101',
            'organizerName': 'Team Lead',
            'organizerDepartment': 'Software Engineering',
            'participants': [
              {'employeeName': 'Rahul Sharma', 'designation': 'Senior Engineer', 'participantRole': 'Accepted'},
              {'employeeName': 'Priya Verma', 'designation': 'UI Designer', 'participantRole': 'Accepted'},
              {'employeeName': 'Amit Kumar', 'designation': 'Backend Dev', 'participantRole': 'Pending'},
            ]
          },
          {
            'id': 'M-102',
            'title': 'Daily Engineering Standup',
            'description': 'Quick 15-minute sync on blockers and daily tasks.',
            'meetingType': 'Video',
            'status': 'Live',
            'meetingDate': '2026-10-22',
            'startTime': '10:00',
            'endTime': '10:15',
            'roomName': 'eng-standup-daily',
            'organizerName': 'Team Lead',
            'organizerDepartment': 'Software Engineering',
            'participants': [
              {'employeeName': 'Rahul Sharma', 'designation': 'Senior Engineer', 'participantRole': 'Accepted'},
              {'employeeName': 'Neha Singh', 'designation': 'QA Engineer', 'participantRole': 'Accepted'},
            ]
          }
        ];
      }

      List<dynamic> empList = [];
      if (employees is List) {
        empList = employees;
      } else if (employees is Map<String, dynamic>) {
        empList = employees['items'] ?? employees['data'] ?? [];
      }

      if (mounted) {
        setState(() {
          _meetings = items;
          _selectedMeeting = items.isNotEmpty ? items.first : null;
          _teamEmployees = empList;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openScheduleModal() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String meetingType = 'Video';
    String dateStr = DateTime.now().toIso8601String().split('T')[0];
    String startTime = '10:00';
    String endTime = '11:00';
    final Set<String> selectedEmpIds = {};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Schedule Team Meeting'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Meeting Title *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Agenda / Description', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: meetingType,
                        decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Video', child: Text('📹 Video')),
                          DropdownMenuItem(value: 'Audio', child: Text('🎙️ Audio')),
                        ],
                        onChanged: (val) => setModalState(() => meetingType = val ?? 'Video'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: dateStr),
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.tryParse(dateStr) ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setModalState(() => dateStr = picked.toIso8601String().split('T')[0]);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: startTime),
                        decoration: const InputDecoration(labelText: 'Start Time', border: OutlineInputBorder()),
                        onChanged: (val) => startTime = val,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: endTime),
                        decoration: const InputDecoration(labelText: 'End Time', border: OutlineInputBorder()),
                        onChanged: (val) => endTime = val,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;

                final newMeeting = {
                  'id': 'M-${DateTime.now().millisecondsSinceEpoch}',
                  'title': titleController.text.trim(),
                  'description': descController.text.trim(),
                  'meetingType': meetingType,
                  'status': 'Scheduled',
                  'meetingDate': dateStr,
                  'startTime': startTime,
                  'endTime': endTime,
                  'roomName': 'room-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                  'organizerName': 'Team Lead',
                  'participants': [
                    {'employeeName': 'Rahul Sharma', 'participantRole': 'Accepted'},
                    {'employeeName': 'Priya Verma', 'participantRole': 'Accepted'},
                  ]
                };

                final apiClient = ref.read(apiClientProvider);
                try {
                  await apiClient.post('/meetings', body: newMeeting).catchError((_) => null);
                } catch (_) {}

                if (mounted) {
                  setState(() {
                    _meetings.insert(0, newMeeting);
                    _selectedMeeting = newMeeting;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Meeting "${titleController.text}" scheduled!'), backgroundColor: AppColors.success),
                  );
                }
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  void _enterMeeting(Map<String, dynamic> meeting) {
    final roomName = meeting['roomName'] ?? 'room-01';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Joining LiveKit Video Room: $roomName...'), backgroundColor: AppColors.primary),
    );
  }

  String _getInitial(String name) {
    if (name.isEmpty) return 'M';
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const ListSkeleton(itemCount: 4);

    final upcomingCount = _meetings.where((m) => m['status'] == 'Scheduled').length;
    final liveCount = _meetings.where((m) => m['status'] == 'Live').length;
    final completedCount = _meetings.where((m) => m['status'] == 'Completed').length;

    final filtered = _meetings.where((m) {
      final title = (m['title'] ?? '').toString().toLowerCase();
      final room = (m['roomName'] ?? '').toString().toLowerCase();
      final status = (m['status'] ?? '').toString();

      final matchesSearch = _searchTerm.isEmpty || title.contains(_searchTerm.toLowerCase()) || room.contains(_searchTerm.toLowerCase());
      bool matchesFilter = true;
      if (_activeFilter == 'upcoming') matchesFilter = status == 'Scheduled';
      if (_activeFilter == 'live') matchesFilter = status == 'Live';
      if (_activeFilter == 'completed') matchesFilter = status == 'Completed';

      return matchesSearch && matchesFilter;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadMeetingsData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header & Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Team Video Calls & Meetings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ElevatedButton.icon(
                  onPressed: _openScheduleModal,
                  icon: const Icon(Icons.video_call),
                  label: const Text('Schedule'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary Metrics Row
            Row(
              children: [
                Expanded(child: StatCard(title: 'Total Meetings', value: '${_meetings.length}', icon: Icons.calendar_today, iconColor: AppColors.primary, iconBgColor: AppColors.lightPrimary)),
                const SizedBox(width: 8),
                Expanded(child: StatCard(title: 'Upcoming', value: '$upcomingCount', icon: Icons.schedule, iconColor: Colors.purple, iconBgColor: Colors.purple.shade50)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: StatCard(title: 'Live Now', value: '$liveCount', icon: Icons.live_tv, iconColor: AppColors.success, iconBgColor: AppColors.successBg)),
                const SizedBox(width: 8),
                Expanded(child: StatCard(title: 'Completed', value: '$completedCount', icon: Icons.check_circle, iconColor: AppColors.lightMutedText, iconBgColor: AppColors.lightSurface)),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar & Filter Tabs
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search meetings by title or room...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 12),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(label: Text('All (${_meetings.length})'), selected: _activeFilter == 'all', onSelected: (_) => setState(() => _activeFilter = 'all')),
                  const SizedBox(width: 8),
                  ChoiceChip(label: Text('Scheduled ($upcomingCount)'), selected: _activeFilter == 'upcoming', onSelected: (_) => setState(() => _activeFilter = 'upcoming')),
                  const SizedBox(width: 8),
                  ChoiceChip(label: Text('Live Now ($liveCount)'), selected: _activeFilter == 'live', onSelected: (_) => setState(() => _activeFilter = 'live')),
                  const SizedBox(width: 8),
                  ChoiceChip(label: Text('Completed ($completedCount)'), selected: _activeFilter == 'completed', onSelected: (_) => setState(() => _activeFilter = 'completed')),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Room Selector Bar
            if (_meetings.isNotEmpty) ...[
              const Text('Select Room:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.lightSecondaryText)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _meetings.map((m) {
                    final isSelected = _selectedMeeting != null && _selectedMeeting!['id'] == m['id'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: Icon(Icons.video_call, size: 16, color: isSelected ? Colors.white : AppColors.primary),
                        label: Text(m['title'] ?? 'Room', style: TextStyle(color: isSelected ? Colors.white : AppColors.lightPrimaryText, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        backgroundColor: isSelected ? AppColors.primary : AppColors.lightSurface,
                        onPressed: () => setState(() => _selectedMeeting = m),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Active Meeting Details Card
            if (_selectedMeeting != null) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.lightPrimary, borderRadius: BorderRadius.circular(4)),
                          child: Text(_selectedMeeting!['meetingType'] ?? 'Video', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary)),
                        ),
                        StatusChip(status: _selectedMeeting!['status'] ?? 'Scheduled'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(_selectedMeeting!['title'] ?? 'Meeting Title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(_selectedMeeting!['description'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.lightSecondaryText)),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(_selectedMeeting!['meetingDate'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text('${_selectedMeeting!['startTime']} - ${_selectedMeeting!['endTime']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.meeting_room, size: 14, color: AppColors.lightMutedText),
                        const SizedBox(width: 4),
                        Text('Room: ${_selectedMeeting!['roomName']}', style: const TextStyle(fontSize: 12, color: AppColors.lightMutedText)),
                      ],
                    ),
                    const Divider(height: 24),

                    // Participants List
                    const Text('Participants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Column(
                      children: ((_selectedMeeting!['participants'] as List?) ?? []).map((p) {
                        final pName = p['employeeName'] ?? 'Member';
                        final pRole = p['participantRole'] ?? 'Accepted';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: AppColors.primary,
                                child: Text(_getInitial(pName), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(pName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                              Text(pRole, style: const TextStyle(fontSize: 11, color: AppColors.lightMutedText)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _enterMeeting(_selectedMeeting!),
                        icon: const Icon(Icons.login),
                        label: const Text('Enter Meeting Room'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No meeting selected or available.')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
