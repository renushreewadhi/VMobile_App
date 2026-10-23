import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';

class AdminTrainingFormScreen extends ConsumerStatefulWidget {
  final String? courseId;
  final Map<String, dynamic>? initialData;

  const AdminTrainingFormScreen({super.key, this.courseId, this.initialData});

  @override
  ConsumerState<AdminTrainingFormScreen> createState() => _AdminTrainingFormScreenState();
}

class _AdminTrainingFormScreenState extends ConsumerState<AdminTrainingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _durationController = TextEditingController(text: '4 Weeks');
  final TextEditingController _capacityController = TextEditingController(text: '20');
  final TextEditingController _tagsController = TextEditingController(text: 'Angular, Frontend');

  String _category = 'Angular';
  String _status = 'DRAFT';

  final List<String> _categories = ['Angular', 'Flutter', 'DevOps', 'Figma', '.NET', 'Linux', 'Web Development', 'App Development'];

  bool get _isEdit => widget.courseId != null || widget.initialData != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _populateData(widget.initialData!);
    } else if (_isEdit && widget.courseId != null) {
      _loadCourseDetail();
    }
  }

  void _populateData(Map<String, dynamic> data) {
    _titleController.text = data['title'] ?? '';
    _descController.text = data['description'] ?? '';
    _durationController.text = data['duration'] ?? '4 Weeks';
    _capacityController.text = '${data['maxParticipants'] ?? data['capacity'] ?? 20}';
    _tagsController.text = data['tags'] is List ? (data['tags'] as List).join(', ') : (data['tags'] ?? 'General');
    _category = data['categoryName'] ?? data['category'] ?? 'Angular';
    _status = data['status'] ?? 'DRAFT';
  }

  Future<void> _loadCourseDetail() async {
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/training/courses/${widget.courseId}');
      if (res is Map<String, dynamic>) {
        _populateData(res);
      }
    } catch (_) {
      if (widget.initialData != null) {
        _populateData(widget.initialData!);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final tags = _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

    final payload = {
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'duration': _durationController.text.trim(),
      'category': _category,
      'tags': tags,
      'maxParticipants': int.tryParse(_capacityController.text) ?? 20,
      'status': _status,
    };

    try {
      if (_isEdit && widget.courseId != null) {
        await apiClient.put('/training/courses/${widget.courseId}', data: payload);
      } else {
        await apiClient.post('/training/courses', data: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Course updated successfully' : 'Course created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save course: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Training Course' : 'Create Training Course'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Course Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Course Title *', border: OutlineInputBorder()),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Course title is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _categories.contains(_category) ? _category : _categories[0],
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() => _category = val ?? 'Angular'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                  DropdownMenuItem(value: 'PUBLISHED', child: Text('Published')),
                ],
                onChanged: (val) => setState(() => _status = val ?? 'DRAFT'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _durationController,
                      decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _capacityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Capacity', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(labelText: 'Tags (comma separated)', border: OutlineInputBorder(), hintText: 'Angular, Frontend, Architecture'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveCourse,
                  icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.check),
                  label: Text(_isSaving ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create Course'), style: const TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
