import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/theme/app_colors.dart';
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

  String? get _effectiveDeptId => widget.deptId ?? widget.initialData?['id']?.toString() ?? widget.initialData?['_id']?.toString();
  bool get _isEdit => _effectiveDeptId != null && _effectiveDeptId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadEmployeesAndExistingCodes();
    if (widget.initialData != null) {
      _populateData(widget.initialData!);
    } else if (_isEdit && _effectiveDeptId != null) {
      _loadDetail();
    }
  }

  Future<void> _loadEmployeesAndExistingCodes() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final empRes = await apiClient.get('${ApiEndpoints.employeesAll}?limit=500').catchError((_) => null);
      List<dynamic> emps = [];
      if (empRes is List) {
        emps = empRes;
      } else if (empRes is Map) {
        emps = empRes['items'] ?? empRes['data'] ?? empRes['result'] ?? [];
      }

      List<Map<String, String>> empList = [];
      for (final e in emps) {
        if (e is Map<String, dynamic>) {
          final id = (e['id'] ?? e['employeeId'] ?? e['userId'])?.toString() ?? '';
          final fName = e['firstName']?.toString() ?? '';
          final lName = e['lastName']?.toString() ?? '';
          final fullName = e['fullName']?.toString() ?? '';
          final name = fullName.isNotEmpty ? fullName : ('$fName $lName'.trim().isNotEmpty ? '$fName $lName' : (e['name']?.toString() ?? 'Employee'));
          if (id.isNotEmpty) {
            empList.add({'id': id, 'name': name});
          }
        }
      }

      final deptRes = await apiClient.get(ApiEndpoints.departments).catchError((_) => null);
      List<dynamic> depts = deptRes is List ? deptRes : (deptRes is Map ? (deptRes['items'] ?? deptRes['data'] ?? []) : []);

      final currentId = _effectiveDeptId;
      List<String> codes = [];
      for (final d in depts) {
        if (d is Map<String, dynamic>) {
          final c = (d['code'] ?? '').toString().toUpperCase();
          final id = (d['id'] ?? d['_id'] ?? '').toString();
          if (c.isNotEmpty && (currentId == null || id != currentId)) {
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

  bool _isCodeManuallyEdited = false;

  String _computeDeptCode(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';

    const customMap = {
      'human resource management': 'HRM',
      'human resources': 'HR',
      'human resource': 'HR',
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

    final lower = trimmed.toLowerCase();
    if (customMap.containsKey(lower)) {
      return customMap[lower]!;
    }

    final cleaned = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9\s&]'), '').trim();
    final stopWords = {'and', 'of', 'the', 'for', 'in'};
    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && !stopWords.contains(w.toLowerCase())).toList();

    if (words.isEmpty) {
      if (cleaned.length >= 3) return cleaned.substring(0, 3).toUpperCase();
      return cleaned.toUpperCase();
    }

    if (words.length == 1) {
      final w = words[0].toUpperCase();
      if (w.length <= 4) return w;
      return w.substring(0, 3);
    } else if (words.length == 2) {
      final w1 = words[0].toUpperCase();
      final w2 = words[1].toUpperCase();
      if (w1.length >= 2 && w2.isNotEmpty) {
        return '${w1[0]}${w1[1]}${w2[0]}';
      }
      return '${w1[0]}${w2[0]}';
    } else {
      return words.map((w) => w == '&' ? '&' : w[0]).take(4).join('').toUpperCase();
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_isUploadingImage) return;
    setState(() => _isUploadingImage = true);

    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) {
        if (mounted) setState(() => _isUploadingImage = false);
        return;
      }

      final fileLength = await file.length();
      if (fileLength > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File size exceeds 10 MB limit.'), backgroundColor: Colors.red),
          );
        }
        if (mounted) setState(() => _isUploadingImage = false);
        return;
      }

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
    final targetId = _effectiveDeptId;

    final payload = {
      'name': _nameController.text.trim(),
      'code': codeVal,
      'description': _descController.text.trim(),
      'imageUrl': _imageUrlController.text.trim().isNotEmpty ? _imageUrlController.text.trim() : null,
      'headId': _selectedHeadId.isNotEmpty ? _selectedHeadId : null,
      'status': _status.toUpperCase(),
    };

    try {
      if (_isEdit && targetId != null && targetId.isNotEmpty) {
        await apiClient.put('${ApiEndpoints.departments}/$targetId', data: payload).catchError((_) async {
          return await apiClient.put('/departments/$targetId', data: payload);
        });
      } else {
        await apiClient.post(ApiEndpoints.departments, data: payload).catchError((_) async {
          return await apiClient.post('/departments', data: payload);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Department updated successfully' : 'Department created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : 'Failed to save department: $e';
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = dark ? AppColors.darkMainSurface : Colors.white;
    final borderColor = dark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB);

    return GlassScaffold(
      appBar: GlassHeader(
        title: _isEdit ? 'Edit Department' : 'Add New Department',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F6B63)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              child: Form(
                key: _formKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 1),
                    boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.04), blurRadius: 16, offset: Offset(0, 4))],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: 32px icon tile + title
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F4F1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.apartment_rounded, color: Color(0xFF0F6B63), size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text('Department Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFE5E7EB)),
                      const SizedBox(height: 16),

                      // Department Name *
                      Row(
                        children: const [
                          Text('Department Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
                          Text(' *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.red)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        child: Row(
                          children: [
                            const Icon(Icons.apartment_rounded, size: 18, color: Color(0xFF64748B)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _nameController,
                                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                decoration: const InputDecoration(
                                  hintText: 'e.g. Engineering',
                                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w400),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (val) {
                                  if (!_isEdit && !_isCodeManuallyEdited) {
                                    final autoCode = _computeDeptCode(val);
                                    if (autoCode.isNotEmpty) {
                                      setState(() {
                                        _codeController.text = autoCode;
                                      });
                                    }
                                  }
                                },
                                validator: (val) => (val == null || val.trim().isEmpty) ? 'Department name is required' : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Department Code * with Auto Generate chip
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Text('Department Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
                              Text(' *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.red)),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              final generated = _computeDeptCode(_nameController.text);
                              if (generated.isNotEmpty) {
                                setState(() {
                                  _codeController.text = generated;
                                  _isCodeManuallyEdited = false;
                                });
                              }
                            },
                            child: Container(
                              height: 28,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F4F1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.auto_fix_high, size: 14, color: Color(0xFF0F6B63)),
                                  SizedBox(width: 4),
                                  Text('Auto Generate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F6B63))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        child: Row(
                          children: [
                            const Icon(Icons.tag_rounded, size: 18, color: Color(0xFF64748B)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _codeController,
                                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w500, fontFamily: 'monospace'),
                                decoration: const InputDecoration(
                                  hintText: 'e.g. ENG',
                                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w400),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (_) => _isCodeManuallyEdited = true,
                                validator: (val) => (val == null || val.trim().isEmpty) ? 'Department code is required' : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Auto-generated from department name', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                      const SizedBox(height: 14),

                      // Department Head (HOD)
                      const Text('Department Head (HOD)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF64748B)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedHeadId,
                                  isExpanded: true,
                                  style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0F6B63), size: 20),
                                  items: [
                                    const DropdownMenuItem(value: '', child: Text('-- Unassigned --', style: TextStyle(fontSize: 14))),
                                    ..._employeesList.map((e) => DropdownMenuItem(value: e['id'], child: Text(e['name']!, style: const TextStyle(fontSize: 14)))),
                                  ],
                                  onChanged: (val) => setState(() => _selectedHeadId = val ?? ''),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Status
                      const Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _status.toLowerCase() == 'active' ? const Color(0xFF047857) : const Color(0xFF64748B),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _status,
                                  isExpanded: true,
                                  style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0F6B63), size: 20),
                                  items: const [
                                    DropdownMenuItem(value: 'Active', child: Text('Active', style: TextStyle(fontSize: 14))),
                                    DropdownMenuItem(value: 'Inactive', child: Text('Inactive', style: TextStyle(fontSize: 14))),
                                  ],
                                  onChanged: (val) => setState(() => _status = val ?? 'Active'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Department Cover Banner (Upload Area)
                      const Text('Department Cover Banner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _isUploadingImage ? null : _pickAndUploadImage,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4FAF9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _isUploadingImage
                                  ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F6B63)))
                                  : Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(color: const Color(0xFFE6F4F1), borderRadius: BorderRadius.circular(10)),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF0F6B63), size: 20),
                                    ),
                              const SizedBox(height: 6),
                              const Text('Click to upload department cover banner', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                              const SizedBox(height: 2),
                              const Text('Supports PNG, JPG, WebP (Recommended ratio 16:9 or 3:1)', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                              const SizedBox(height: 8),
                              Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF0F6B63), width: 1),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.folder_open_rounded, size: 16, color: Color(0xFF0F6B63)),
                                    SizedBox(width: 6),
                                    Text('Browse File', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF0F6B63))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Or paste direct image URL
                      const Text('Or paste direct image URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        child: Row(
                          children: [
                            const Icon(Icons.link_rounded, size: 18, color: Color(0xFF64748B)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _imageUrlController,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                decoration: const InputDecoration(
                                  hintText: 'https://images.unsplash.com/photo-...',
                                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w400),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Description
                      const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(minHeight: 96),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: TextFormField(
                          controller: _descController,
                          maxLines: 4,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w500, height: 1.5),
                          decoration: const InputDecoration(
                            hintText: 'Scope, purpose, and responsibilities of this department...',
                            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w400),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Create Department / Save Changes button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                          label: Text(
                            _isSaving ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create Department'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F6B63),
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: const Color.fromRGBO(15, 107, 99, 0.22),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
