import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/storage/storage_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';

class AdminDepartmentFormScreen extends ConsumerStatefulWidget {
  final String? deptId;
  final Map<String, dynamic>? initialData;

  const AdminDepartmentFormScreen({super.key, this.deptId, this.initialData});

  @override
  ConsumerState<AdminDepartmentFormScreen> createState() => _AdminDepartmentFormScreenState();
}

class _AdminDepartmentFormScreenState extends ConsumerState<AdminDepartmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();

  String _status = 'Active';
  String _selectedHeadId = '';
  List<Map<String, String>> _employeesList = [];
  List<String> _existingCodes = [];

  bool get _isEdit => widget.deptId != null || widget.initialData != null;

  @override
  void initState() {
    super.initState();
    _loadEmployeesAndExistingCodes();
    if (widget.initialData != null) {
      _populateData(widget.initialData!);
    } else if (_isEdit && widget.deptId != null) {
      _loadDetail();
    }
  }

  Future<void> _loadEmployeesAndExistingCodes() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final empRes = await apiClient.get(ApiEndpoints.employees).catchError((_) => null);
      List<dynamic> emps = empRes is List ? empRes : (empRes is Map ? (empRes['items'] ?? empRes['data'] ?? []) : []);

      List<Map<String, String>> empList = [];
      for (final e in emps) {
        if (e is Map<String, dynamic>) {
          final id = (e['id'] ?? e['employeeId'])?.toString() ?? '';
          final fName = e['firstName']?.toString() ?? '';
          final lName = e['lastName']?.toString() ?? '';
          final name = '$fName $lName'.trim().isNotEmpty ? '$fName $lName' : (e['name']?.toString() ?? 'Employee');
          if (id.isNotEmpty) {
            empList.add({'id': id, 'name': name});
          }
        }
      }

      final deptRes = await apiClient.get(ApiEndpoints.departments).catchError((_) => null);
      List<dynamic> depts = deptRes is List ? deptRes : (deptRes is Map ? (deptRes['items'] ?? deptRes['data'] ?? []) : []);

      List<String> codes = [];
      for (final d in depts) {
        if (d is Map<String, dynamic>) {
          final c = (d['code'] ?? '').toString().toUpperCase();
          final id = (d['id'] ?? '').toString();
          if (c.isNotEmpty && id != widget.deptId) {
            codes.add(c);
          }
        }
      }

      if (mounted) {
        setState(() {
          _employeesList = empList;
          _existingCodes = codes;
        });
      }
    } catch (_) {}
  }

  void _populateData(Map<String, dynamic> data) {
    _nameController.text = data['name']?.toString() ?? '';
    _codeController.text = data['code']?.toString() ?? '';
    _descController.text = data['description']?.toString() ?? '';
    _imageUrlController.text = data['imageUrl']?.toString() ?? '';
    _selectedHeadId = data['headId']?.toString() ?? '';

    final allowedStatuses = ['Active', 'Inactive'];
    final rawStatus = data['status']?.toString() ?? 'Active';
    _status = allowedStatuses.firstWhere(
      (s) => s.toLowerCase() == rawStatus.toLowerCase(),
      orElse: () => 'Active',
    );
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(apiClientProvider).get(ApiEndpoints.departments);
      if (res is List) {
        final d = res.firstWhere((item) => item['id'] == widget.deptId, orElse: () => null);
        if (d != null) _populateData(d);
      }
    } catch (_) {
      if (widget.initialData != null) {
        _populateData(widget.initialData!);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _computeDeptCode(String name) {
    if (name.trim().isEmpty) return '';

    const customMap = {
      'human resource management': 'HRM',
      'human resources': 'HR',
      'information technology': 'IT',
      'research & development': 'R&D',
      'research and development': 'R&D',
      'quality assurance': 'QA',
      'customer support': 'CS',
      'sales and marketing': 'SM',
      'sales & marketing': 'SM',
      'marketing': 'MKT',
      'engineering': 'ENG',
      'finance': 'FIN',
      'accounting': 'ACC',
      'operations': 'OPS',
      'administration': 'ADM',
      'management': 'MGT',
      'business development': 'BD',
      'public relations': 'PR',
      'supply chain': 'SC',
      'legal': 'LGL',
    };

    final lower = name.toLowerCase().trim();
    if (customMap.containsKey(lower)) {
      return customMap[lower]!;
    }

    final cleaned = name.replaceAll(RegExp(r'[^a-zA-Z0-9\s&]'), '').trim();
    final stopWords = {'and', 'of', 'the', 'for', 'in'};
    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && !stopWords.contains(w.toLowerCase())).toList();

    if (words.isEmpty) return '';

    if (words.length == 1) {
      final w = words[0];
      if (w.length <= 4) return w.toUpperCase();
      return w.substring(0, 3).toUpperCase();
    } else {
      return words.map((w) => w == '&' ? '&' : w[0]).join('').toUpperCase();
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final fileLength = await file.length();
    if (fileLength > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File size exceeds 10 MB limit.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() => _isUploadingImage = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final storageService = ref.read(storageServiceProvider);
      final token = await storageService.getToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${apiClient.baseUrl}${ApiEndpoints.departmentsUploadImage}'),
      );

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = String.fromCharCodes(response.bodyBytes);
        if (body.contains('imageUrl')) {
          final regex = RegExp(r'"imageUrl"\s*:\s*"([^"]+)"');
          final match = regex.firstMatch(body);
          if (match != null && match.group(1) != null) {
            _imageUrlController.text = match.group(1)!;
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cover image uploaded successfully')),
          );
        }
      } else {
        throw 'Upload failed with status ${response.statusCode}';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final codeVal = _codeController.text.trim().toUpperCase();
    if (_existingCodes.contains(codeVal)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Department code "$codeVal" already exists. Please choose a unique code.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'name': _nameController.text.trim(),
      'code': codeVal,
      'description': _descController.text.trim(),
      'imageUrl': _imageUrlController.text.trim().isNotEmpty ? _imageUrlController.text.trim() : null,
      'headId': _selectedHeadId.isNotEmpty ? _selectedHeadId : null,
      'status': _status,
    };

    try {
      if (_isEdit && widget.deptId != null) {
        await apiClient.put('${ApiEndpoints.departments}/${widget.deptId}', data: payload);
      } else {
        await apiClient.post(ApiEndpoints.departments, data: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Department updated successfully' : 'Department created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save department: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      appBar: GlassHeader(
        title: _isEdit ? 'Edit Department' : 'Add New Department',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.apartment_rounded, color: AppColors.primary, size: 22),
                          SizedBox(width: 8),
                          Text('Department Information', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 20),

                      // Department Name
                      const Text('Department Name *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Engineering',
                          prefixIcon: const Icon(Icons.apartment_rounded, size: 18, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        onChanged: (val) {
                          if (!_isEdit && _codeController.text.trim().isEmpty) {
                            final autoCode = _computeDeptCode(val);
                            if (autoCode.isNotEmpty) {
                              _codeController.text = autoCode;
                            }
                          }
                        },
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Department name is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Department Code with Auto Generate badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Department Code *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          InkWell(
                            onTap: () {
                              final generated = _computeDeptCode(_nameController.text);
                              if (generated.isNotEmpty) {
                                setState(() => _codeController.text = generated);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFC7D2FE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.auto_fix_high, size: 12, color: Color(0xFF4338CA)),
                                  SizedBox(width: 4),
                                  Text('Auto Generate', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4338CA))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          hintText: 'e.g. ENG',
                          prefixIcon: const Icon(Icons.tag_rounded, size: 18, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Department code is required' : null,
                      ),
                      const SizedBox(height: 4),
                      const Text('Auto-generated from department name', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 16),

                      // Department Head (HOD)
                      const Text('Department Head (HOD)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedHeadId,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('-- Unassigned --', style: TextStyle(fontSize: 13))),
                          ..._employeesList.map((e) => DropdownMenuItem(value: e['id'], child: Text(e['name']!, style: const TextStyle(fontSize: 13)))),
                        ],
                        onChanged: (val) => setState(() => _selectedHeadId = val ?? ''),
                      ),
                      const SizedBox(height: 16),

                      // Status
                      const Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _status,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.toggle_on_rounded, size: 18, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Active', child: Text('Active', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'Inactive', child: Text('Inactive', style: TextStyle(fontSize: 13))),
                        ],
                        onChanged: (val) => setState(() => _status = val ?? 'Active'),
                      ),
                      const SizedBox(height: 20),

                      // Department Cover Banner (Dashed Upload Box)
                      const Text('Department Cover Banner', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _isUploadingImage ? null : _pickAndUploadImage,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          decoration: BoxDecoration(
                            color: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _isUploadingImage
                                  ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(color: const Color(0xFFE0EDFF), borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF2563EB), size: 22),
                                    ),
                              const SizedBox(height: 12),
                              const Text('Click to upload department cover banner', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              const SizedBox(height: 4),
                              const Text('Supports PNG, JPG, WebP (Recommended ratio 16:9 or 3:1)', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                  boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 4, offset: Offset(0, 2))],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.folder_open_rounded, size: 14, color: Color(0xFF334155)),
                                    SizedBox(width: 6),
                                    Text('Browse File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Or paste direct image URL
                      const Text('Or paste direct image URL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _imageUrlController,
                        decoration: InputDecoration(
                          hintText: 'https://images.unsplash.com/photo-...',
                          prefixIcon: const Icon(Icons.link_rounded, size: 18, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      const Text('Description', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Scope, purpose, and responsibilities of this department...',
                          filled: true,
                          fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Create Department button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check, size: 18),
                          label: Text(_isSaving ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create Department'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
