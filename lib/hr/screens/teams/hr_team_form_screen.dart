import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class HrTeamFormScreen extends ConsumerStatefulWidget {
  final String? teamId;
  final Map<String, dynamic>? initialData;

  const HrTeamFormScreen({super.key, this.teamId, this.initialData});

  @override
  ConsumerState<HrTeamFormScreen> createState() => _HrTeamFormScreenState();
}

class _HrTeamFormScreenState extends ConsumerState<HrTeamFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  String _status = 'Active';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData ?? {};
    _nameController = TextEditingController(text: d['name'] ?? '');
    _descController = TextEditingController(text: d['description'] ?? '');
    final allowedStatuses = ['Active', 'Inactive'];
    final rawStatus = d['status'] ?? 'Active';
    _status = allowedStatuses.firstWhere(
      (s) => s.toLowerCase() == rawStatus.toString().toLowerCase(),
      orElse: () => 'Active',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _saveTeam() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'name': _nameController.text.trim(),
      'description': _descController.text.trim(),
      'status': _status,
      'departmentId': 'd1',
    };

    try {
      if (widget.teamId != null) {
        await apiClient.put('/departments/teams/${widget.teamId}', body: payload);
      } else {
        await apiClient.post('/departments/teams', body: payload);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team saved successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save team: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.teamId != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Team' : 'Create Team')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Team Name *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Team name is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: ['Active', 'Inactive'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => _status = val ?? 'Active'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveTeam,
                  child: Text(_isSaving ? 'Saving...' : (isEdit ? 'Update Team' : 'Create Team')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
