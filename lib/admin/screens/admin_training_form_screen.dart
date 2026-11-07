import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';
import '../../hr/screens/training/hr_training_dashboard_screen.dart';

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
  String? _errorMessage;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _durationController = TextEditingController(text: '4 Weeks');
  final TextEditingController _tagsController = TextEditingController(text: 'Angular, RxJS, Performance');

  String _category = 'Backend Development';
  String _status = 'DRAFT';
  String _selectedTechLogo = 'Angular';

  bool _isMandatory = false;
  bool _autoIssueCertificate = true;
  bool _allowSelfEnrollment = true;
  bool _showInCatalog = true;

  final List<String> _categories = ['Backend Development', 'DevOps & Cloud', 'App Development', 'Figma & UI/UX Design', 'Security & Compliance'];
  final List<String> _techLogos = ['Angular', 'Flutter', 'DevOps', 'Figma', '.NET', 'Linux'];

  int _requestId = 0;
  String? _currentUserId;

  bool get _isEdit => widget.courseId != null || widget.initialData != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkUserAndLoad();
      }
    });
  }

  void _checkUserAndLoad() {
    _requestId++;
    final authState = ref.read(authServiceProvider);
    final user = authState.user;

    if (user == null || !authState.isAuthenticated) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No authenticated user found.';
      });
      return;
    }

    if (_currentUserId != user.id) {
      _currentUserId = user.id;
    }

    final userRole = user.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    if (!isAuthorized) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    if (widget.initialData != null) {
      _populateData(widget.initialData!);
      setState(() => _isLoading = false);
    } else if (_isEdit && widget.courseId != null) {
      _loadCourseDetail();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _populateData(Map<String, dynamic> data) {
    _titleController.text = data['title']?.toString() ?? '';
    _descController.text = data['description']?.toString() ?? '';
    _durationController.text = data['duration']?.toString() ?? '4 Weeks';
    _tagsController.text = data['tags'] is List ? (data['tags'] as List).join(', ') : (data['tags']?.toString() ?? 'Angular, Performance');
    
    final cat = data['categoryName']?.toString() ?? data['category']?.toString() ?? 'Backend Development';
    if (_categories.contains(cat)) {
      _category = cat;
    }

    _status = (data['status']?.toString() ?? 'DRAFT').toUpperCase();
    _isMandatory = data['isMandatory'] ?? false;
    _autoIssueCertificate = data['autoIssueCertificate'] ?? true;
    _allowSelfEnrollment = data['allowSelfEnrollment'] ?? true;
    _showInCatalog = data['showInCatalog'] ?? true;
  }

  Future<void> _loadCourseDetail() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.get(ApiEndpoints.trainingCourseDetail(widget.courseId!));
      if (!mounted || currentReq != _requestId) return;

      final data = res is Map<String, dynamic> ? (res['data'] ?? res) : {};
      _populateData(data);
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load course details.';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveCourse({bool publish = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'title': _titleController.text.trim(),
      'category': _category,
      'description': _descController.text.trim(),
      'duration': _durationController.text.trim(),
      'status': publish ? 'PUBLISHED' : _status,
      'tags': _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'techLogo': _selectedTechLogo,
      'isMandatory': _isMandatory,
      'autoIssueCertificate': _autoIssueCertificate,
      'allowSelfEnrollment': _allowSelfEnrollment,
      'showInCatalog': _showInCatalog,
    };

    try {
      if (_isEdit && widget.courseId != null) {
        await apiClient.put(ApiEndpoints.trainingCourseDetail(widget.courseId!), body: payload);
      } else {
        await apiClient.post(ApiEndpoints.trainingCourses, body: payload);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(publish ? 'Course created & published successfully!' : 'Course saved as draft!'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
      setState(() => _isSaving = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save course: $e'), backgroundColor: AppColors.error),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      appBar: GlassHeader(
        title: _isEdit ? 'Edit Training Course' : 'Create New Course',
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_isEdit ? 'Edit Course' : 'Create New Course', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: glass.textPrimary)),
                            const SizedBox(height: 2),
                            const Text('Build a comprehensive training course with lectures, quizzes, and learning resources', style: TextStyle(fontSize: 11.5, color: AppColors.lightSecondaryText)),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Back to Courses', style: TextStyle(fontSize: 11.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    buildHrTrainingSubNav(context, 3),
                    const SizedBox(height: 16),

                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Basic Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 14),

                          const Text('Course Title *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(hintText: 'e.g. Advanced Angular Architecture & Performance', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Please enter course title' : null,
                          ),
                          const SizedBox(height: 14),

                          const Text('Category *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _category,
                            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) => setState(() => _category = val ?? 'Backend Development'),
                          ),
                          const SizedBox(height: 14),

                          const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _descController,
                            maxLines: 3,
                            decoration: const InputDecoration(hintText: 'Describe what employees will learn from this course...', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12)),
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _durationController,
                                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Publishing Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: _status,
                                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                                      items: const [
                                        DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                                        DropdownMenuItem(value: 'PUBLISHED', child: Text('Published')),
                                      ],
                                      onChanged: (val) => setState(() => _status = val ?? 'DRAFT'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          const Text('Tags (comma separated)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _tagsController,
                            decoration: const InputDecoration(hintText: 'Angular, RxJS, Performance', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Course Thumbnail & Preset Tech Logo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 12),
                          const Text('Select Preset Tech Logo', style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _techLogos.map((logo) {
                              final isSelected = _selectedTechLogo == logo;
                              return ChoiceChip(
                                label: Text(logo),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.lightPrimaryText, fontSize: 12),
                                onSelected: (_) => setState(() => _selectedTechLogo = logo),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Settings & Visibility', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            title: const Text('Course is mandatory for assigned employees', style: TextStyle(fontSize: 13)),
                            value: _isMandatory,
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) => setState(() => _isMandatory = val ?? false),
                          ),
                          CheckboxListTile(
                            title: const Text('Issue completion certificate automatically', style: TextStyle(fontSize: 13)),
                            value: _autoIssueCertificate,
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) => setState(() => _autoIssueCertificate = val ?? true),
                          ),
                          CheckboxListTile(
                            title: const Text('Allow self-enrollment from course catalog', style: TextStyle(fontSize: 13)),
                            value: _allowSelfEnrollment,
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) => setState(() => _allowSelfEnrollment = val ?? true),
                          ),
                          CheckboxListTile(
                            title: const Text('Show in employee training catalog', style: TextStyle(fontSize: 13)),
                            value: _showInCatalog,
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) => setState(() => _showInCatalog = val ?? true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : () => _saveCourse(publish: false),
                            child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save as Draft'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : () => _saveCourse(publish: true),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                            child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create & Publish'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
