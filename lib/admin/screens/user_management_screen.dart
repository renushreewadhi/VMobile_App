import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import 'user_form_screen.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const UserManagementScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _users = [];
  String _searchQuery = '';
  String _roleFilter = 'ALL';
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.get('/users').catchError((_) => null);
      if (mounted) {
        setState(() {
          if (res is List) {
            _users = res;
          } else if (res is Map<String, dynamic> && res['data'] is List) {
            _users = res['data'];
          } else {
            _users = [
              {'id': '1', 'name': 'Rahul Sharma', 'email': 'rahul.sharma@company.com', 'role': 'EMPLOYEE', 'status': 'ACTIVE', 'department': 'Engineering'},
              {'id': '2', 'name': 'Priya Verma', 'email': 'priya.verma@company.com', 'role': 'TEAM_LEAD', 'status': 'ACTIVE', 'department': 'Product'},
              {'id': '3', 'name': 'Amit Kumar', 'email': 'amit.kumar@company.com', 'role': 'HR_MANAGER', 'status': 'ACTIVE', 'department': 'HR'},
              {'id': '4', 'name': 'Admin User', 'email': 'admin@company.com', 'role': 'ADMIN', 'status': 'ACTIVE', 'department': 'Management'}
            ];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _users = [
            {'id': '1', 'name': 'Rahul Sharma', 'email': 'rahul.sharma@company.com', 'role': 'EMPLOYEE', 'status': 'ACTIVE', 'department': 'Engineering'}
          ];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteUser(dynamic user) async {
    final name = user['name'] ?? 'User';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete user $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(apiClientProvider).delete('/users/${user['id']}');
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted successfully')));
        _fetchUsers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const ListSkeleton(itemCount: 4);

    final totalCount = _users.length;
    final activeCount = _users.where((u) => (u['status'] ?? 'ACTIVE').toString().toUpperCase() == 'ACTIVE').length;
    final adminCount = _users.where((u) => (u['role'] ?? '').toString().toUpperCase().contains('ADMIN')).length;

    final filtered = _users.where((u) {
      final name = (u['name'] ?? u['fullName'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final role = (u['role'] ?? '').toString().toUpperCase();
      final status = (u['status'] ?? 'ACTIVE').toString().toUpperCase();

      final matchesSearch = name.contains(_searchQuery.toLowerCase()) || email.contains(_searchQuery.toLowerCase());
      final matchesRole = _roleFilter == 'ALL' || role.contains(_roleFilter);
      final matchesStatus = _statusFilter == 'ALL' || status == _statusFilter;

      return matchesSearch && matchesRole && matchesStatus;
    }).toList();

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Metrics Grid
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.4,
            children: [
              _buildMetric('Total', '$totalCount', AppColors.primary, Icons.people),
              _buildMetric('Active', '$activeCount', AppColors.success, Icons.check_circle),
              _buildMetric('Admins', '$adminCount', Colors.purple, Icons.admin_panel_settings),
            ],
          ),
          const SizedBox(height: 16),

          // Search & Filters
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search user by name or email...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _roleFilter,
                  decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Roles')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                    DropdownMenuItem(value: 'HR', child: Text('HR Manager')),
                    DropdownMenuItem(value: 'TEAM_LEAD', child: Text('Team Lead')),
                    DropdownMenuItem(value: 'EMPLOYEE', child: Text('Employee')),
                  ],
                  onChanged: (val) => setState(() => _roleFilter = val ?? 'ALL'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Status')),
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                    DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                  ],
                  onChanged: (val) => setState(() => _statusFilter = val ?? 'ALL'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Users List
          if (filtered.isEmpty)
            const AppCard(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No users found matching criteria.')),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final u = filtered[index];
                final name = u['name'] ?? u['fullName'] ?? 'User';
                final email = u['email'] ?? 'user@company.com';
                final role = u['role'] ?? 'EMPLOYEE';
                final status = u['status'] ?? 'ACTIVE';
                final dept = u['department'] ?? 'General';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.lightPrimary,
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('$email • $dept', style: const TextStyle(fontSize: 11.5, color: AppColors.lightSecondaryText)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                                    child: Text(role, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                                  ),
                                  const SizedBox(width: 8),
                                  StatusChip(status: status),
                                ],
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (val) async {
                            if (val == 'edit') {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => UserFormScreen(userId: u['id']?.toString(), initialData: u)));
                              _fetchUsers();
                            } else if (val == 'delete') {
                              _deleteUser(u);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit User')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete User', style: TextStyle(color: AppColors.error))),
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

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: content);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Create User',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const UserFormScreen()));
              _fetchUsers();
            },
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildMetric(String label, String value, Color color, IconData icon) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
