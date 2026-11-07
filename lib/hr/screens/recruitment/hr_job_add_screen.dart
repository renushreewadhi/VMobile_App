import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/widgets/glass_header.dart';
import '../../../core/widgets/glass_scaffold.dart';

class HrJobAddScreen extends ConsumerStatefulWidget {
  final String? jobId;
  final Map<String, dynamic>? initialData;

  const HrJobAddScreen({
    super.key,
    this.jobId,
    this.initialData,
  });

  @override
  ConsumerState<HrJobAddScreen> createState() => _HrJobAddScreenState();
}

class _HrJobAddScreenState extends ConsumerState<HrJobAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _vacanciesController = TextEditingController(text: '1');
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _requirementsController = TextEditingController();
  final TextEditingController _closingDateController = TextEditingController();

  String _departmentId = '';
  String _designationId = '';
  String _branchId = '';
  String _teamId = '';
  String _employmentType = 'Full-time';
  String _visibility = 'PUBLIC';

  List<dynamic> _departments = [];
  List<dynamic> _designations = [];
  List<dynamic> _branches = [];
  List<dynamic> _teams = [];
  bool _isLoadingDropdowns = true;
  String? _dropdownErrorMessage;
  bool _isSaving = false;

  int _requestId = 0;
  String? _currentUserId;

  bool get isEdit => (widget.jobId != null && widget.jobId!.isNotEmpty) || widget.initialData != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkUserAndLoad();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _codeController.dispose();
    _salaryController.dispose();
    _experienceController.dispose();
    _vacanciesController.dispose();
    _descController.dispose();
    _requirementsController.dispose();
    _closingDateController.dispose();
    super.dispose();
  }

  void _checkUserAndLoad() {
    final authState = ref.read(authServiceProvider);
    final user = authState.user;
    if (user == null || !authState.isAuthenticated) return;
    if (_currentUserId != user.id) {
      _currentUserId = user.id;
    }
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoadingDropdowns = true;
      _dropdownErrorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);
    try {
      final deptRes = await apiClient.get(ApiEndpoints.departments);
      final desigRes = await apiClient.get('/designations').catchError((_) => []);
      final branchRes = await apiClient.get('/branches').catchError((_) => []);
      final teamRes = await apiClient.get(ApiEndpoints.teams).catchError((_) => []);

      if (!mounted || currentReq != _requestId) return;

      List<dynamic> depts = deptRes is List ? deptRes : (deptRes is Map ? (deptRes['items'] ?? deptRes['data'] ?? []) : []);
      List<dynamic> desigs = desigRes is List ? desigRes : (desigRes is Map ? (desigRes['items'] ?? desigRes['data'] ?? []) : []);
      List<dynamic> branches = branchRes is List ? branchRes : (branchRes is Map ? (branchRes['items'] ?? branchRes['data'] ?? []) : []);
      List<dynamic> teams = teamRes is List ? teamRes : (teamRes is Map ? (teamRes['items'] ?? teamRes['data'] ?? []) : []);

      setState(() {
        _departments = depts;
        _designations = desigs;
        _branches = branches;
        _teams = teams;
        _isLoadingDropdowns = false;
        _dropdownErrorMessage = null;
      });

      if (isEdit) {
        if (widget.initialData != null) {
          _applyInitialData(widget.initialData!);
        }
        final effectiveJobId = widget.jobId ?? (widget.initialData?['id'] ?? widget.initialData?['_id'])?.toString();
        if (effectiveJobId != null && effectiveJobId.isNotEmpty) {
          try {
            final fetched = await apiClient.get('/recruitment/jobs/$effectiveJobId').catchError((_) => null);
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
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _dropdownErrorMessage = 'Failed to load form requirements: $e';
        _isLoadingDropdowns = false;
      });
    }
  }

  void _applyInitialData(Map<String, dynamic> data) {
    if (!mounted) return;

    final title = (data['title'] ?? data['jobTitle'] ?? '').toString();
    final code = (data['code'] ?? data['jobCode'] ?? '').toString();
    final salary = (data['salaryRange'] ?? '').toString();
    final exp = (data['experience'] ?? '').toString();
    final vacancies = (data['vacancies'] ?? 1).toString();
    final desc = (data['description'] ?? data['jobDescription'] ?? '').toString();
    final req = (data['requirements'] ?? data['skills'] ?? '').toString();
    final closing = (data['closingDate'] ?? '').toString();

    if (title.isNotEmpty) _titleController.text = title;
    if (code.isNotEmpty) _codeController.text = code;
    if (salary.isNotEmpty) _salaryController.text = salary;
    if (exp.isNotEmpty) _experienceController.text = exp;
    if (vacancies.isNotEmpty) _vacanciesController.text = vacancies;
    if (desc.isNotEmpty) _descController.text = desc;
    if (req.isNotEmpty) _requirementsController.text = req;
    if (closing.isNotEmpty) _closingDateController.text = closing;

    final empType = data['employmentType']?.toString();
    if (empType != null && empType.isNotEmpty) {
      _employmentType = empType;
    }

    final vis = data['visibility']?.toString();
    if (vis != null && vis.isNotEmpty) {
      _visibility = vis.toUpperCase();
    }

    final dId = data['departmentId']?.toString();
    if (dId != null && dId.isNotEmpty) {
      _departmentId = dId;
    }

    final desId = data['designationId']?.toString();
    if (desId != null && desId.isNotEmpty) {
      _designationId = desId;
    }

    final bId = (data['branchId'] ?? data['locationId'])?.toString();
    if (bId != null && bId.isNotEmpty) {
      _branchId = bId;
    }

    final tId = data['teamId']?.toString();
    if (tId != null && tId.isNotEmpty) {
      _teamId = tId;
    }

    setState(() {});
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _closingDateController.text = picked.toIso8601String().substring(0, 10);
      });
    }
  }

  Future<void> _saveJob({bool publish = true}) async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    if (_departmentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a department.'), backgroundColor: Colors.red));
      return;
    }
    if (_visibility == 'TEAM' && _teamId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a target team for TEAM visibility.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final selectedDept = _departments.firstWhere((d) => (d['id']?.toString() ?? '') == _departmentId, orElse: () => null);
    final selectedDesig = _designations.firstWhere((d) => (d['id']?.toString() ?? '') == _designationId, orElse: () => null);
    final selectedBranch = _branches.firstWhere((b) => (b['id']?.toString() ?? '') == _branchId, orElse: () => null);
    final selectedTeam = _teams.firstWhere((t) => (t['id']?.toString() ?? '') == _teamId, orElse: () => null);

    final payload = {
      'title': _titleController.text.trim(),
      if (_codeController.text.trim().isNotEmpty) 'code': _codeController.text.trim(),
      'departmentId': _departmentId,
      'departmentName': selectedDept != null ? (selectedDept['name'] ?? selectedDept['departmentName'] ?? '') : '',
      if (_designationId.isNotEmpty) 'designationId': _designationId,
      if (selectedDesig != null) 'designationName': selectedDesig['name'] ?? selectedDesig['title'] ?? '',
      if (_branchId.isNotEmpty) 'branchId': _branchId,
      if (selectedBranch != null) 'branchName': selectedBranch['name'] ?? selectedBranch['branchName'] ?? '',
      if (_visibility == 'TEAM' && _teamId.isNotEmpty) 'teamId': _teamId,
      if (_visibility == 'TEAM' && selectedTeam != null) 'teamName': selectedTeam['name'] ?? '',
      'employmentType': _employmentType,
      if (_experienceController.text.trim().isNotEmpty) 'experience': _experienceController.text.trim(),
      if (_salaryController.text.trim().isNotEmpty) 'salaryRange': _salaryController.text.trim(),
      'description': _descController.text.trim(),
      if (_requirementsController.text.trim().isNotEmpty) 'requirements': _requirementsController.text.trim(),
      'vacancies': int.tryParse(_vacanciesController.text.trim()) ?? 1,
      'status': publish ? 'OPEN' : 'DRAFT',
      'visibility': _visibility,
      'postedDate': DateTime.now().toIso8601String(),
      if (_closingDateController.text.trim().isNotEmpty) 'closingDate': _closingDateController.text.trim(),
    };

    try {
      final effectiveJobId = widget.jobId ?? (widget.initialData?['id'] ?? widget.initialData?['_id'])?.toString();
      if (isEdit && effectiveJobId != null && effectiveJobId.isNotEmpty) {
        await apiClient.put('/recruitment/jobs/$effectiveJobId', body: payload);
      } else {
        await apiClient.post('/recruitment/jobs', body: payload);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? 'Job updated successfully'
                  : (publish ? 'Job opening published successfully' : 'Job saved as draft'),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save job: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    final screenTitle = isEdit ? 'Edit Job Opening' : 'Post New Job Opening';

    if (_isLoadingDropdowns) {
      return GlassScaffold(
        appBar: GlassHeader(title: screenTitle),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_dropdownErrorMessage != null) {
      return GlassScaffold(
        appBar: GlassHeader(title: screenTitle),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 54, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Failed to Load Requirements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_dropdownErrorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 24),
                ElevatedButton.icon(onPressed: _loadDropdowns, icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    return GlassScaffold(
      appBar: GlassHeader(title: screenTitle),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'Edit Job Opening Details' : 'Job Opening Details',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (isEdit) ...[
                const SizedBox(height: 4),
                Text(
                  'Update job details, salary range, location, and requirements',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Job Title *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'Job title is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Job Code (Optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _departmentId.isEmpty ? null : _departmentId,
                decoration: const InputDecoration(labelText: 'Department *', border: OutlineInputBorder()),
                items: _departments.map((d) => DropdownMenuItem<String>(
                  value: d['id']?.toString(),
                  child: Text(d['name']?.toString() ?? d['departmentName'] ?? 'Department'),
                )).toList(),
                onChanged: (val) => setState(() => _departmentId = val ?? ''),
                validator: (val) => val == null || val.isEmpty ? 'Department is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _designationId.isEmpty ? null : _designationId,
                decoration: const InputDecoration(labelText: 'Designation', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('Unassigned / None')),
                  ..._designations.map((d) => DropdownMenuItem<String>(
                        value: d['id']?.toString(),
                        child: Text(d['name']?.toString() ?? d['title'] ?? 'Designation'),
                      )),
                ],
                onChanged: (val) => setState(() => _designationId = val ?? ''),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _branchId.isEmpty ? null : _branchId,
                decoration: const InputDecoration(labelText: 'Branch / Location', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('Unassigned / None')),
                  ..._branches.map((b) => DropdownMenuItem<String>(
                        value: b['id']?.toString(),
                        child: Text(b['name']?.toString() ?? b['branchName'] ?? 'Branch'),
                      )),
                ],
                onChanged: (val) => setState(() => _branchId = val ?? ''),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _employmentType,
                decoration: const InputDecoration(labelText: 'Employment Type', border: OutlineInputBorder()),
                items: ['Full-time', 'Part-time', 'Contract', 'Internship'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => _employmentType = val ?? 'Full-time'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _salaryController,
                decoration: const InputDecoration(labelText: 'Salary Range (e.g. ₹12L - ₹18L / yr)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _experienceController,
                decoration: const InputDecoration(labelText: 'Experience Required (e.g. 3-5 Years)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vacanciesController,
                decoration: const InputDecoration(labelText: 'Vacancies *', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Vacancies is required';
                  final v = int.tryParse(val.trim());
                  if (v == null || v < 1) return 'Vacancies must be at least 1';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _visibility,
                decoration: const InputDecoration(labelText: 'Visibility *', border: OutlineInputBorder()),
                items: ['PUBLIC', 'INTERNAL', 'DEPARTMENT', 'TEAM'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (val) => setState(() => _visibility = val ?? 'PUBLIC'),
              ),
              if (_visibility == 'TEAM') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _teamId.isEmpty ? null : _teamId,
                  decoration: const InputDecoration(labelText: 'Target Team *', border: OutlineInputBorder()),
                  items: _teams.map((t) => DropdownMenuItem<String>(
                    value: t['id']?.toString(),
                    child: Text(t['name']?.toString() ?? 'Team'),
                  )).toList(),
                  onChanged: (val) => setState(() => _teamId = val ?? ''),
                  validator: (val) => _visibility == 'TEAM' && (val == null || val.isEmpty) ? 'Team is required for TEAM visibility' : null,
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _closingDateController,
                decoration: InputDecoration(
                  labelText: 'Closing Date',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
                ),
                readOnly: true,
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Job Description *', border: OutlineInputBorder()),
                maxLines: 4,
                validator: (val) => val == null || val.trim().isEmpty ? 'Job description is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _requirementsController,
                decoration: const InputDecoration(labelText: 'Skills & Requirements', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: _isSaving ? null : () => _saveJob(publish: false),
                      child: const Text('Save as Draft'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: _isSaving ? null : () => _saveJob(publish: true),
                      child: Text(_isSaving ? 'Publishing...' : (isEdit ? 'Publish Opening' : 'Publish Opening')),
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
