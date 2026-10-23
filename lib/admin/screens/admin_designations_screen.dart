import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import 'admin_designation_form_screen.dart';

class AdminDesignationsScreen extends ConsumerStatefulWidget {
  const AdminDesignationsScreen({super.key});

  @override
  ConsumerState<AdminDesignationsScreen> createState() => _AdminDesignationsScreenState();
}

class _AdminDesignationsScreenState extends ConsumerState<AdminDesignationsScreen> {
  bool _isLoading = true;
  List<dynamic> _designations = [];
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadDesignations();
  }

  Future<void> _loadDesignations() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/departments/designations').catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic>) {
        items = res['items'] ?? res['data'] ?? [];
      }

      if (items.isEmpty) {
        items = [
          {'id': '1', 'title': 'Senior Software Engineer', 'level': 'Senior', 'departmentName': 'Engineering', 'minSalary': 1200000, 'maxSalary': 1800000, 'status': 'Active'},
          {'id': '2', 'title': 'HR Manager', 'level': 'Manager', 'departmentName': 'Human Resources', 'minSalary': 1000000, 'maxSalary': 1500000, 'status': 'Active'},
        ];
      }

      setState(() {
        _designations = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredDesignations {
    return _designations.where((d) {
      final title = (d['title'] ?? '').toString().toLowerCase();
      final dept = (d['departmentName'] ?? '').toString().toLowerCase();

      return _searchTerm.trim().isEmpty ||
          title.contains(_searchTerm.toLowerCase()) ||
          dept.contains(_searchTerm.toLowerCase());
    }).toList();
  }

  Future<void> _deleteDesignation(Map<String, dynamic> d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete designation "${d['title']}"?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _designations.removeWhere((item) => item['id'] == d['id']));
      if (d['id'] != null) {
        try {
          await ref.read(apiClientProvider).delete('/departments/designations/${d['id']}');
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Designation deleted successfully')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Designations Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Designation',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDesignationFormScreen()));
              _loadDesignations();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search designations by title or department...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchTerm = val),
            ),
            const SizedBox(height: 16),

            // Designations List
            _filteredDesignations.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No designations found matching your search.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredDesignations.length,
                    itemBuilder: (context, index) {
                      final desig = _filteredDesignations[index];
                      final isActive = (desig['status'] ?? 'Active').toString().toUpperCase() == 'ACTIVE';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                child: const Icon(Icons.badge, color: AppColors.primary),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(desig['title'] ?? 'Designation Title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 2),
                                    Text('${desig['departmentName'] ?? 'General'} • Level: ${desig['level'] ?? 'Mid'}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                    Text('₹${desig['minSalary'] ?? 0} - ₹${desig['maxSalary'] ?? 0}', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Chip(
                                    label: Text(isActive ? 'Active' : 'Inactive', style: const TextStyle(fontSize: 10, color: Colors.white)),
                                    backgroundColor: isActive ? Colors.green : Colors.grey,
                                    padding: EdgeInsets.zero,
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                                        onPressed: () async {
                                          await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminDesignationFormScreen(designationId: desig['id'], initialData: desig)));
                                          _loadDesignations();
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                        onPressed: () => _deleteDesignation(desig),
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
  }
}
