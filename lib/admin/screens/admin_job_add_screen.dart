import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/errors/api_exception.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';

class AdminJobAddScreen extends ConsumerStatefulWidget {
  final String? jobId;
  final Map<String, dynamic>? initialData;

  const AdminJobAddScreen({
    super.key,
    this.jobId,
    this.initialData,
  });

  @override
  ConsumerState<AdminJobAddScreen> createState() => _AdminJobAddScreenState();
}

class _AdminJobAddScreenState extends ConsumerState<AdminJobAddScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController(text: '₹12,00,000 - ₹18,00,000 / yr');
  final TextEditingController _vacanciesController = TextEditingController(text: '1');
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _reqController = TextEditingController();

  String? _selectedDepartmentId;
  String? _selectedDesignationId;
  String? _selectedBranchId;
  String? _selectedTeamId;

  String _employmentType = 'Full-time';
  String _visibility = 'PUBLIC';

  List<Map<String, String>> _departments = [];
  List<Map<String, String>> _designations = [];
  List<Map<String, String>> _branches = [];
  List<Map<String, String>> _teams = [];

  final List<String> _employmentTypes = ['Full-time', 'Part-time', 'Contract', 'Internship'];
  final List<String> _visibilityOptions = ['PUBLIC', 'INTERNAL', 'DEPARTMENT', 'TEAM'];

  bool get isEdit => (widget.jobId != null && widget.jobId!.isNotEmpty) || widget.initialData != null;

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final deptRes = await apiClient.get(ApiEndpoints.departments).catchError((_) => []);
      final desigRes = await apiClient.get(ApiEndpoints.designations).catchError((_) => []);
      final branchRes = await apiClient.get(ApiEndpoints.branches).catchError((_) => []);
      final teamRes = await apiClient.get(ApiEndpoints.teams).catchError((_) => []);

      List<Map<String, String>> depts = [];
      dynamic rawDepts = deptRes is Map<String, dynamic> && deptRes.containsKey('data') ? deptRes['data'] : deptRes;
      if (rawDepts is List) {
        for (final d in rawDepts) {
          if (d is Map<String, dynamic>) {
            final id = (d['id'] ?? d['_id'])?.toString() ?? '';
            final name = (d['name'] ?? d['departmentName'])?.toString() ?? 'Department';
            if (id.isNotEmpty) depts.add({'id': id, 'name': name});
          }
        }
      }

      List<Map<String, String>> desigs = [];
      dynamic rawDesigs = desigRes is Map<String, dynamic> && desigRes.containsKey('data') ? desigRes['data'] : desigRes;
      if (rawDesigs is List) {
        for (final des in rawDesigs) {
          if (des is Map<String, dynamic>) {
            final id = (des['id'] ?? des['_id'])?.toString() ?? '';
            final title = (des['title'] ?? des['name'])?.toString() ?? 'Designation';
            if (id.isNotEmpty) desigs.add({'id': id, 'title': title});
          }
        }
      }

      List<Map<String, String>> branches = [];
      dynamic rawBranches = branchRes is Map<String, dynamic> && branchRes.containsKey('data') ? branchRes['data'] : branchRes;
      if (rawBranches is List) {
        for (final b in rawBranches) {
          if (b is Map<String, dynamic>) {
            final id = (b['id'] ?? b['_id'])?.toString() ?? '';
            final name = (b['name'] ?? b['branchName'])?.toString() ?? 'Branch';
            if (id.isNotEmpty) branches.add({'id': id, 'name': name});
          }
        }
      }

      List<Map<String, String>> teams = [];
      dynamic rawTeams = teamRes is Map<String, dynamic> && teamRes.containsKey('data') ? teamRes['data'] : teamRes;
      if (rawTeams is List) {
        for (final t in rawTeams) {
          if (t is Map<String, dynamic>) {
            final id = (t['id'] ?? t['_id'])?.toString() ?? '';
            final name = (t['name'] ?? t['teamName'])?.toString() ?? 'Team';
            if (id.isNotEmpty) teams.add({'id': id, 'name': name});
          }
        }
      }

      if (mounted) {
        setState(() {
          _departments = depts;
          _designations = desigs;
          _branches = branches;
          _teams = teams;

          if (!isEdit) {
            if (depts.isNotEmpty) _selectedDepartmentId = depts[0]['id'];
            if (desigs.isNotEmpty) _selectedDesignationId = desigs[0]['id'];
            if (branches.isNotEmpty) _selectedBranchId = branches[0]['id'];
            if (teams.isNotEmpty) _selectedTeamId = teams[0]['id'];
          }
        });
      }

      if (isEdit) {
        if (widget.initialData != null) {
          _applyInitialData(widget.initialData!);
        }
        final effectiveJobId = widget.jobId ?? (widget.initialData?['id'] ?? widget.initialData?['_id'])?.toString();
        if (effectiveJobId != null && effectiveJobId.isNotEmpty) {
          try {
            final fetched = await apiClient.get('/recruitment/jobs/$effectiveJobId').catchError((_) => null) ??
                await apiClient.get('${ApiEndpoints.jobs}/$effectiveJobId').catchError((_) => null);
            if (fetched is Map<String, dynamic>) {
              dynamic item = fetched.containsKey('data') ? fetched['data'] : fetched;
              if (item is Map<String, dynamic>) {
                _applyInitialData(item);
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyInitialData(Map<String, dynamic> data) {
    if (!mounted) return;

    final title = (data['title'] ?? data['jobTitle'] ?? '').toString();
    final salary = (data['salaryRange'] ?? '').toString();
    final vacancies = (data['vacancies'] ?? 1).toString();
    final desc = (data['description'] ?? data['jobDescription'] ?? '').toString();
    final req = (data['requirements'] ?? data['skills'] ?? '').toString();

    if (title.isNotEmpty) _titleController.text = title;
    if (salary.isNotEmpty) _salaryController.text = salary;
    if (vacancies.isNotEmpty) _vacanciesController.text = vacancies;
    if (desc.isNotEmpty) _descController.text = desc;
    if (req.isNotEmpty) _reqController.text = req;

    final empType = data['employmentType']?.toString();
    if (empType != null && _employmentTypes.contains(empType)) {
      _employmentType = empType;
    }

    final vis = data['visibility']?.toString();
    if (vis != null && _visibilityOptions.contains(vis.toUpperCase())) {
      _visibility = vis.toUpperCase();
    }

    // Match Department
    final deptId = data['departmentId']?.toString();
    final deptName = (data['departmentName'] ?? data['department'])?.toString();
    if (deptId != null && _departments.any((d) => d['id'] == deptId)) {
      _selectedDepartmentId = deptId;
    } else if (deptName != null) {
      final match = _departments.firstWhere(
        (d) => (d['name'] ?? '').toLowerCase() == deptName.toLowerCase(),
        orElse: () => {},
      );
      if (match.containsKey('id')) _selectedDepartmentId = match['id'];
    }

    // Match Designation
    final desigId = data['designationId']?.toString();
    final desigTitle = (data['designationName'] ?? data['designation'])?.toString();
    if (desigId != null && _designations.any((d) => d['id'] == desigId)) {
      _selectedDesignationId = desigId;
    } else if (desigTitle != null) {
      final match = _designations.firstWhere(
        (d) => (d['title'] ?? '').toLowerCase() == desigTitle.toLowerCase(),
        orElse: () => {},
      );
      if (match.containsKey('id')) _selectedDesignationId = match['id'];
    }

    // Match Branch
    final branchId = (data['branchId'] ?? data['locationId'])?.toString();
    final branchName = (data['branchName'] ?? data['location'])?.toString();
    if (branchId != null && _branches.any((b) => b['id'] == branchId)) {
      _selectedBranchId = branchId;
    } else if (branchName != null) {
      final match = _branches.firstWhere(
        (b) => (b['name'] ?? '').toLowerCase() == branchName.toLowerCase(),
        orElse: () => {},
      );
      if (match.containsKey('id')) _selectedBranchId = match['id'];
    }

    // Match Team
    final teamId = data['teamId']?.toString();
    final teamName = (data['teamName'] ?? data['team'])?.toString();
    if (teamId != null && _teams.any((t) => t['id'] == teamId)) {
      _selectedTeamId = teamId;
    } else if (teamName != null) {
      final match = _teams.firstWhere(
        (t) => (t['name'] ?? '').toLowerCase() == teamName.toLowerCase(),
        orElse: () => {},
      );
      if (match.containsKey('id')) _selectedTeamId = match['id'];
    }

    setState(() {});
  }

  Future<void> _saveJob(String status) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDepartmentId == null || _selectedDepartmentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Department.'), backgroundColor: Colors.red),
      );
      return;
    }

    final vacanciesInt = int.tryParse(_vacanciesController.text.trim()) ?? 1;
    if (vacanciesInt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vacancies must be a valid positive integer.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'title': _titleController.text.trim(),
      'departmentId': _selectedDepartmentId,
      if (_selectedDesignationId != null) 'designationId': _selectedDesignationId,
      if (_selectedBranchId != null) 'branchId': _selectedBranchId,
      'teamId': _visibility == 'TEAM' ? _selectedTeamId : null,
      'employmentType': _employmentType,
      'salaryRange': _salaryController.text.trim(),
      'description': _descController.text.trim().isNotEmpty ? _descController.text.trim() : _titleController.text.trim(),
      'requirements': _reqController.text.trim(),
      'vacancies': vacanciesInt,
      'visibility': _visibility,
      'status': status,
    };

    try {
      final effectiveJobId = widget.jobId ?? (widget.initialData?['id'] ?? widget.initialData?['_id'])?.toString();
      if (isEdit && effectiveJobId != null && effectiveJobId.isNotEmpty) {
        try {
          await apiClient.put('/recruitment/jobs/$effectiveJobId', body: payload);
        } catch (_) {
          await apiClient.put('${ApiEndpoints.jobs}/$effectiveJobId', body: payload);
        }
      } else {
        await apiClient.post(ApiEndpoints.jobs, body: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? 'Job updated successfully!'
                  : (status == 'DRAFT' ? 'Job saved as draft!' : 'Job published successfully!'),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : 'Could not save the job opening. Please check details and try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;

    if (_isLoading) {
      return GlassScaffold(
        appBar: GlassHeader(title: isEdit ? 'Edit Job Opening' : 'Post New Job Opening'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return GlassScaffold(
      appBar: GlassHeader(
        title: isEdit ? 'Edit Job Opening' : 'Post New Job Opening',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isEdit ? Icons.edit_rounded : Icons.work_outline_rounded, color: const Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? 'Edit Job Opening Details' : 'Job Opening Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary),
                  ),
                ],
              ),
              if (isEdit) ...[
                const SizedBox(height: 4),
                Text(
                  'Update job details, salary range, location, and requirements',
                  style: TextStyle(fontSize: 12, color: glass.textSecondary),
                ),
              ],
              const SizedBox(height: 16),

              // Job Title
              TextFormField(
                controller: _titleController,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  labelText: 'Job Title *',
                  hintText: 'e.g. Senior Full Stack Developer',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Job title is required' : null,
              ),
              const SizedBox(height: 16),

              // Department & Designation
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedDepartmentId,
                      decoration: InputDecoration(
                        labelText: 'Department *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _departments.map((dept) {
                        return DropdownMenuItem<String>(
                          value: dept['id']!,
                          child: Text(dept['name']!),
                        );
                      }).toList(),
                      onChanged: _isSaving ? null : (val) => setState(() => _selectedDepartmentId = val),
                      validator: (val) => (val == null || val.isEmpty) ? 'Department is required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedDesignationId,
                      decoration: InputDecoration(
                        labelText: 'Designation',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _designations.map((des) {
                        return DropdownMenuItem<String>(
                          value: des['id']!,
                          child: Text(des['title']!),
                        );
                      }).toList(),
                      onChanged: _isSaving ? null : (val) => setState(() => _selectedDesignationId = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Branch & Employment Type
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedBranchId,
                      decoration: InputDecoration(
                        labelText: 'Branch / Location',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _branches.map((b) {
                        return DropdownMenuItem<String>(
                          value: b['id']!,
                          child: Text(b['name']!),
                        );
                      }).toList(),
                      onChanged: _isSaving ? null : (val) => setState(() => _selectedBranchId = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _employmentType,
                      decoration: InputDecoration(
                        labelText: 'Employment Type',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _employmentTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: _isSaving ? null : (val) => setState(() => _employmentType = val ?? 'Full-time'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Salary Range & Vacancies
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _salaryController,
                      enabled: !_isSaving,
                      decoration: InputDecoration(
                        labelText: 'Salary Range (INR ₹)',
                        hintText: 'e.g. ₹12,00,000 - ₹18,00,000 / yr',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _vacanciesController,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Vacancies / Positions',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        final num = int.tryParse(val.trim());
                        if (num == null || num <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Visibility & Target Team
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _visibility,
                      decoration: InputDecoration(
                        labelText: 'Visibility',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _visibilityOptions.map((vis) {
                        return DropdownMenuItem<String>(
                          value: vis,
                          child: Text(vis),
                        );
                      }).toList(),
                      onChanged: _isSaving ? null : (val) => setState(() => _visibility = val ?? 'PUBLIC'),
                    ),
                  ),
                  if (_visibility == 'TEAM') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedTeamId,
                        decoration: InputDecoration(
                          labelText: 'Target Team',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _teams.map((t) {
                          return DropdownMenuItem<String>(
                            value: t['id']!,
                            child: Text(t['name']!),
                          );
                        }).toList(),
                        onChanged: _isSaving ? null : (val) => setState(() => _selectedTeamId = val),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Description & Requirements
              TextFormField(
                controller: _descController,
                enabled: !_isSaving,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Job Description',
                  hintText: 'Enter key responsibilities, role overview, and objectives...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _reqController,
                enabled: !_isSaving,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Skills & Requirements',
                  hintText: 'e.g. Flutter, Dart, REST APIs, 4+ years experience...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),

              // Footer Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    label: isEdit ? 'Publish Opening' : 'Publish',
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : () => _saveJob('OPEN'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.save_outlined, size: 16),
                          label: const Text('Save Draft'),
                          onPressed: _isSaving ? null : () => _saveJob('DRAFT'),
                        ),
                      ),
                    ],
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
