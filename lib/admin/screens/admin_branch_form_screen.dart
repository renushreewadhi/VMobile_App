import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/errors/api_exception.dart';
import '../../core/storage/storage_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';

class AdminBranchFormScreen extends ConsumerStatefulWidget {
  final String? branchId;
  final Map<String, dynamic>? initialData;

  const AdminBranchFormScreen({super.key, this.branchId, this.initialData});

  @override
  ConsumerState<AdminBranchFormScreen> createState() => _AdminBranchFormScreenState();
}

class _AdminBranchFormScreenState extends ConsumerState<AdminBranchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _countryController = TextEditingController(text: 'India');
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();

  String _status = 'Active';

  bool get _isEdit => widget.branchId != null || widget.initialData != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _populateData(widget.initialData!);
    } else if (_isEdit && widget.branchId != null) {
      _loadDetail();
    }
  }

  void _populateData(Map<String, dynamic> data) {
    _nameController.text = data['name']?.toString() ?? '';
    _codeController.text = data['code']?.toString() ?? '';
    _addressController.text = data['address']?.toString() ?? '';
    _cityController.text = data['city']?.toString() ?? '';
    _stateController.text = data['state']?.toString() ?? '';
    _countryController.text = data['country']?.toString() ?? 'India';
    _phoneController.text = data['phone']?.toString() ?? '';
    _emailController.text = data['email']?.toString() ?? '';
    _imageUrlController.text = data['imageUrl']?.toString() ?? data['image']?.toString() ?? '';

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
      final res = await ref.read(apiClientProvider).get(ApiEndpoints.branches);
      dynamic rawData = res;
      if (res is Map<String, dynamic> && res.containsKey('data')) {
        rawData = res['data'];
      }
      if (rawData is List) {
        final b = rawData.firstWhere((item) => (item['id'] ?? item['_id'])?.toString() == widget.branchId, orElse: () => null);
        if (b != null && b is Map<String, dynamic>) _populateData(b);
      }
    } catch (_) {
      if (widget.initialData != null) {
        _populateData(widget.initialData!);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;

    final length = await file.length();
    if (length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File size exceeds 5MB limit.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() => _isUploadingImage = true);

    final storageService = ref.read(storageServiceProvider);
    final token = await storageService.getToken();
    final apiClient = ref.read(apiClientProvider);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${apiClient.baseUrl}${ApiEndpoints.branchUploadImage}'),
      );

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body);
        final rawData = json is Map<String, dynamic> && json.containsKey('data') ? json['data'] : json;
        final url = rawData['imageUrl']?.toString() ?? rawData['url']?.toString();
        if (url != null && url.isNotEmpty) {
          setState(() {
            _imageUrlController.text = url;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Building photo uploaded successfully')),
            );
          }
        }
      } else {
        throw ApiException('Failed to upload image (Status: ${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim(),
      'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      'city': _cityController.text.trim(),
      'state': _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
      'country': _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      'imageUrl': _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
      'status': _status,
    };

    try {
      if (_isEdit && widget.branchId != null) {
        await apiClient.put('${ApiEndpoints.branches}/${widget.branchId}', body: payload);
      } else {
        await apiClient.post(ApiEndpoints.branches, body: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Branch updated successfully' : 'Branch created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : 'Failed to save branch.';
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

    if (_isLoading) {
      return GlassScaffold(
        appBar: GlassHeader(title: _isEdit ? 'Edit Branch' : 'Add New Branch'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return GlassScaffold(
      appBar: GlassHeader(
        title: _isEdit ? 'Edit Branch' : 'Add New Branch',
      ),
      body: SingleChildScrollView(
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
                    Icon(Icons.business_rounded, color: AppColors.primary, size: 22),
                    SizedBox(width: 8),
                    Text('Branch Office Details', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 20),

                // Branch Name
                const Text('Branch Name *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  enabled: !_isSaving,
                  decoration: InputDecoration(
                    hintText: 'e.g. Adajan Surat',
                    prefixIcon: const Icon(Icons.apartment_rounded, size: 18, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Branch name is required' : null,
                ),
                const SizedBox(height: 16),

                // Branch Code
                const Text('Branch Code *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _codeController,
                  enabled: !_isSaving,
                  decoration: InputDecoration(
                    hintText: 'e.g. AS-0946',
                    prefixIcon: const Icon(Icons.tag_rounded, size: 18, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Branch code is required' : null,
                ),
                const SizedBox(height: 16),

                // Street Address
                const Text('Street Address', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressController,
                  enabled: !_isSaving,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'e.g. Green Atria Society, Anand Mahal Rd...',
                    filled: true,
                    fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 16),

                // City & State
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('City *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _cityController,
                            enabled: !_isSaving,
                            decoration: InputDecoration(
                              hintText: 'e.g. Surat',
                              prefixIcon: const Icon(Icons.location_city_rounded, size: 18, color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'City is required' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('State / Province', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _stateController,
                            enabled: !_isSaving,
                            decoration: InputDecoration(
                              hintText: 'e.g. Gujarat',
                              prefixIcon: const Icon(Icons.map_rounded, size: 18, color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Country & Phone
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Country', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _countryController,
                            enabled: !_isSaving,
                            decoration: InputDecoration(
                              hintText: 'e.g. India',
                              prefixIcon: const Icon(Icons.public_rounded, size: 18, color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Phone Number', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _phoneController,
                            enabled: !_isSaving,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: '1800-000-0000',
                              prefixIcon: const Icon(Icons.phone_rounded, size: 18, color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Contact Email & Status
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Contact Email', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            enabled: !_isSaving,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'adajansurat@...',
                              prefixIcon: const Icon(Icons.email_rounded, size: 18, color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            validator: (val) {
                              if (val != null && val.trim().isNotEmpty) {
                                final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                                if (!emailRegex.hasMatch(val.trim())) return 'Invalid email address';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                            onChanged: _isSaving ? null : (val) => setState(() => _status = val ?? 'Active'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Branch Building Photo (Dashed Upload Box)
                const Text('Branch Building Photo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                InkWell(
                  onTap: (_isSaving || _isUploadingImage) ? null : _pickAndUploadImage,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isUploadingImage
                            ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2))
                            : Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.cloud_upload_outlined, color: Color(0xFFD97706), size: 22),
                              ),
                        const SizedBox(height: 10),
                        const Text('Upload Building Photo', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        const SizedBox(height: 3),
                        const Text('Or paste an image URL below', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Image URL (Optional)
                const Text('Image URL (Optional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _imageUrlController,
                  enabled: !_isSaving,
                  decoration: InputDecoration(
                    hintText: 'https://images.unsplash.com/...',
                    prefixIcon: const Icon(Icons.link_rounded, size: 18, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 28),

                // Cancel & Update/Create Branch buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check, size: 18),
                          label: Text(_isEdit ? 'Update Branch' : 'Create Branch', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
