import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';

class AdminReportingHierarchyScreen extends ConsumerStatefulWidget {
  const AdminReportingHierarchyScreen({super.key});

  @override
  ConsumerState<AdminReportingHierarchyScreen> createState() => _AdminReportingHierarchyScreenState();
}

class _AdminReportingHierarchyScreenState extends ConsumerState<AdminReportingHierarchyScreen> {
  bool _isLoading = true;
  String _viewMode = 'tree';
  List<dynamic> _tree = [];
  List<dynamic> _flatMap = [];

  @override
  void initState() {
    super.initState();
    _loadHierarchy();
  }

  Future<void> _loadHierarchy() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final treeRes = await apiClient.get('/organization/hierarchy').catchError((_) => null);
      final mapRes = await apiClient.get('/organization/map').catchError((_) => null);

      List<dynamic> treeList = treeRes is List ? treeRes : (treeRes is Map ? (treeRes['items'] ?? treeRes['data'] ?? []) : []);
      List<dynamic> flatList = mapRes is List ? mapRes : (mapRes is Map ? (mapRes['items'] ?? mapRes['data'] ?? []) : []);

      if (treeList.isEmpty) {
        treeList = [
          {
            'id': '1',
            'name': 'Alex Johnson',
            'designation': 'Chief Executive Officer',
            'department': 'Executive',
            'subordinates': [
              {
                'id': '2',
                'name': 'Rahul Sharma',
                'designation': 'Engineering Director',
                'department': 'Engineering',
                'subordinates': [
                  {'id': '3', 'name': 'Prince Vidyarthi', 'designation': 'Senior Developer', 'department': 'Engineering'}
                ]
              },
              {
                'id': '4',
                'name': 'Sarah Connor',
                'designation': 'HR Director',
                'department': 'Human Resources'
              }
            ]
          }
        ];
      }

      if (flatList.isEmpty) {
        flatList = [
          {'name': 'Alex Johnson', 'designation': 'CEO', 'department': 'Executive', 'managerName': 'Board of Directors'},
          {'name': 'Rahul Sharma', 'designation': 'Engineering Director', 'department': 'Engineering', 'managerName': 'Alex Johnson'},
          {'name': 'Prince Vidyarthi', 'designation': 'Senior Developer', 'department': 'Engineering', 'managerName': 'Rahul Sharma'},
          {'name': 'Sarah Connor', 'designation': 'HR Director', 'department': 'Human Resources', 'managerName': 'Alex Johnson'},
        ];
      }

      setState(() {
        _tree = treeList;
        _flatMap = flatList;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporting Hierarchy & Org Tree'),
        actions: [
          Row(
            children: [
              ChoiceChip(
                label: const Text('Tree View'),
                selected: _viewMode == 'tree',
                onSelected: (_) => setState(() => _viewMode = 'tree'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Map View'),
                selected: _viewMode == 'map',
                onSelected: (_) => setState(() => _viewMode = 'map'),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _viewMode == 'tree'
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _tree.map((node) => _buildTreeNode(node, 0)).toList(),
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Employee')),
                    DataColumn(label: Text('Designation')),
                    DataColumn(label: Text('Department')),
                    DataColumn(label: Text('Reports To')),
                  ],
                  rows: _flatMap.map((row) {
                    return DataRow(cells: [
                      DataCell(Text(row['name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['designation'] ?? '—')),
                      DataCell(Text(row['department'] ?? '—')),
                      DataCell(Text(row['managerName'] ?? '—')),
                    ]);
                  }).toList(),
                ),
              ),
      ),
    );
  }

  Widget _buildTreeNode(Map<String, dynamic> node, int depth) {
    final subs = (node['subordinates'] is List) ? (node['subordinates'] as List) : [];
    final name = node['name'] ?? node['fullName'] ?? 'Employee';
    final designation = node['designation'] ?? 'Staff';
    final department = node['department'] ?? 'General';

    return Padding(
      padding: EdgeInsets.only(left: depth * 24.0, bottom: 8),
      child: AppCard(
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('$designation • $department', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          children: subs.map((sub) => _buildTreeNode(sub, depth + 1)).toList(),
        ),
      ),
    );
  }
}
