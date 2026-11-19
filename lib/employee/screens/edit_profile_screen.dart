import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/employee_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../widgets/form_section_card.dart';
import '../widgets/authenticated_image.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Personal Information
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _nationalityController = TextEditingController();

  // Address & Work Location
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _regionController = TextEditingController();
  final _workLocationController = TextEditingController();

  // Financial & Bank Details
  final _bankNameController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _ifscController = TextEditingController();

  // Identity & Tax Details
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();
  final _taxIdController = TextEditingController();

  // Emergency Contact
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationController = TextEditingController();

  bool _loading = false;
  bool _saving = false;
  String? _error;

  String? _gender = 'Male';
  String? _maritalStatus = 'SINGLE';
  String? _bloodGroup = 'O+';

  @override
  void initState() {
    super.initState();
    final user = ref.read(authServiceProvider).user;
    if (user != null) {
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
    }
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final user = ref.read(authServiceProvider).user;
    if (user == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final employeeService = ref.read(employeeServiceProvider);
      Map<String, dynamic> data = {};

      final identifiers = [
        user.id,
        user.employeeId,
      ].where((id) => id != null && id.trim().isNotEmpty).toList();

      for (final id in identifiers) {
        try {
          final res = await employeeService.getEmployeeDetail(id!);
          final resMap = res is Map<String, dynamic> ? (res['data'] ?? res) : null;
          if (resMap is Map<String, dynamic> && resMap.isNotEmpty) {
            data = resMap;
            break;
          }
        } catch (_) {}
      }

      if (data.isEmpty) {
        try {
          final meRes = await employeeService.getCurrentUser().catchError((_) => null);
          if (meRes is Map<String, dynamic>) {
            data = meRes['data'] ?? meRes;
          }
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        if (data.containsKey('firstName') && data['firstName'] != null) _firstNameController.text = data['firstName'].toString();
        if (data.containsKey('lastName') && data['lastName'] != null) _lastNameController.text = data['lastName'].toString();
        if (data.containsKey('email') && data['email'] != null) _emailController.text = data['email'].toString();
        if (data.containsKey('phone') && data['phone'] != null) _phoneController.text = data['phone'].toString();

        final rawDob = data['dateOfBirth']?.toString() ?? data['dob']?.toString();
        if (rawDob != null && rawDob.isNotEmpty) {
          try {
            final parsed = DateTime.parse(rawDob);
            _dobController.text = "${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}";
          } catch (_) {
            _dobController.text = rawDob.split('T')[0];
          }
        }

        final g = data['gender']?.toString().toUpperCase();
        if (g != null && (g == 'MALE' || g == 'FEMALE' || g == 'OTHER')) {
          _gender = g == 'MALE' ? 'Male' : (g == 'FEMALE' ? 'Female' : 'Other');
        }

        final ms = data['maritalStatus']?.toString().toUpperCase();
        if (ms != null && ['SINGLE', 'MARRIED', 'DIVORCED', 'WIDOWED'].contains(ms)) {
          _maritalStatus = ms;
        }

        if (data['nationality'] != null) _nationalityController.text = data['nationality'].toString();

        final bg = data['bloodGroup']?.toString();
        if (bg != null && ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].contains(bg)) {
          _bloodGroup = bg;
        }

        if (data['address'] != null) _addressController.text = data['address'].toString();
        if (data['city'] != null) _cityController.text = data['city'].toString();
        if (data['state'] != null) _stateController.text = data['state'].toString();
        if (data['country'] != null) _countryController.text = data['country'].toString();
        if (data['zipCode'] != null) _zipCodeController.text = data['zipCode'].toString();
        if (data['region'] != null) _regionController.text = data['region'].toString();
        if (data['workLocation'] != null) _workLocationController.text = data['workLocation'].toString();
        if (data['aadhaarNumber'] != null) _aadhaarController.text = data['aadhaarNumber'].toString();
        if (data['panNumber'] != null) _panController.text = data['panNumber'].toString();
        if (data['taxId'] != null) _taxIdController.text = data['taxId'].toString();
        if (data['bankName'] != null) _bankNameController.text = data['bankName'].toString();
        if (data['bankAccountNumber'] != null) _bankAccountController.text = data['bankAccountNumber'].toString();
        if (data['ifscCode'] != null) _ifscController.text = data['ifscCode'].toString();
        if (data['emergencyContactName'] != null) _emergencyNameController.text = data['emergencyContactName'].toString();
        if (data['emergencyContactPhone'] != null) _emergencyPhoneController.text = data['emergencyContactPhone'].toString();
        if (data['emergencyContactRelation'] != null) _emergencyRelationController.text = data['emergencyContactRelation'].toString();

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _nationalityController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _zipCodeController.dispose();
    _regionController.dispose();
    _workLocationController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _taxIdController.dispose();
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _ifscController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final user = ref.read(authServiceProvider).user;

    bool isGuid(String? str) {
      if (str == null || str.trim().isEmpty) return false;
      final clean = str.trim();
      return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(clean) ||
          RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(clean);
    }

    String? targetGuid;
    if (isGuid(user?.id)) {
      targetGuid = user!.id;
    } else if (isGuid(user?.employeeId)) {
      targetGuid = user!.employeeId;
    }

    if (targetGuid == null || targetGuid.isEmpty) {
      setState(() {
        _saving = false;
        _error = 'Valid User GUID not found in session.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valid User GUID not found in session.'), backgroundColor: AppColors.error),
      );
      return;
    }

    String? formattedDob;
    if (_dobController.text.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(_dobController.text.trim());
      if (parsed != null) {
        formattedDob = parsed.toUtc().toIso8601String();
      }
    }

    final payload = <String, dynamic>{
      'id': targetGuid,
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      if (user?.email != null && user!.email.isNotEmpty) 'email': user.email,
      if (_phoneController.text.trim().isNotEmpty) 'phone': _phoneController.text.trim(),
      if (formattedDob != null) 'dateOfBirth': formattedDob,
      if (_gender != null && _gender!.isNotEmpty) 'gender': _gender!.toUpperCase(),
      if (_maritalStatus != null && _maritalStatus!.isNotEmpty) 'maritalStatus': _maritalStatus!.toUpperCase(),
      if (_nationalityController.text.trim().isNotEmpty) 'nationality': _nationalityController.text.trim(),
      if (_bloodGroup != null && _bloodGroup!.isNotEmpty) 'bloodGroup': _bloodGroup,
      if (_addressController.text.trim().isNotEmpty) 'address': _addressController.text.trim(),
      if (_cityController.text.trim().isNotEmpty) 'city': _cityController.text.trim(),
      if (_stateController.text.trim().isNotEmpty) 'state': _stateController.text.trim(),
      if (_countryController.text.trim().isNotEmpty) 'country': _countryController.text.trim(),
      if (_zipCodeController.text.trim().isNotEmpty) 'zipCode': _zipCodeController.text.trim(),
      if (_regionController.text.trim().isNotEmpty) 'region': _regionController.text.trim(),
      if (_workLocationController.text.trim().isNotEmpty) 'workLocation': _workLocationController.text.trim(),
      if (_emergencyNameController.text.trim().isNotEmpty) 'emergencyContactName': _emergencyNameController.text.trim(),
      if (_emergencyPhoneController.text.trim().isNotEmpty) 'emergencyContactPhone': _emergencyPhoneController.text.trim(),
      if (_emergencyRelationController.text.trim().isNotEmpty) 'emergencyContactRelation': _emergencyRelationController.text.trim(),
    };

    try {
      final apiClient = ref.read(apiClientProvider);
      try {
        await apiClient.put('${ApiEndpoints.employees}/$targetGuid', body: payload);
      } catch (err) {
        await apiClient.put('/users/$targetGuid', body: payload);
      }

      await ref.read(authServiceProvider.notifier).refreshCurrentUser();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      setState(() {
        _saving = false;
        _error = errStr;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $errStr'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  bool _isUploadingAvatar = false;
  String? _avatarUrl;

  String _resolveAvatarUrl(dynamic avatar) {
    if (avatar == null || avatar.toString().trim().isEmpty) return '';
    final url = avatar.toString().trim();
    if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('data:')) {
      return url;
    }
    const baseUrl = 'https://hrms.etaprise.ai';
    if (url.startsWith('/')) {
      return '$baseUrl$url';
    }
    return '$baseUrl/$url';
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Change Profile Picture', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final image = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 800, maxHeight: 800);
      if (image == null) return;

      setState(() => _isUploadingAvatar = true);

      final employeeService = ref.read(employeeServiceProvider);
      final res = await employeeService.uploadAvatar(image);

      String? uploadedUrl;
      if (res is String) {
        uploadedUrl = res;
      } else if (res is Map<String, dynamic>) {
        final data = res['data'];
        if (data is String) {
          uploadedUrl = data;
        } else if (data is Map<String, dynamic>) {
          uploadedUrl = data['url']?.toString() ??
              data['avatarUrl']?.toString() ??
              data['avatar']?.toString() ??
              data['path']?.toString() ??
              data['fileUrl']?.toString();
        }
        uploadedUrl ??= res['url']?.toString() ??
            res['avatarUrl']?.toString() ??
            res['avatar']?.toString() ??
            res['path']?.toString() ??
            res['fileUrl']?.toString();
      }

      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        final user = ref.read(authServiceProvider).user;
        bool isGuid(String? str) {
          if (str == null || str.trim().isEmpty) return false;
          final clean = str.trim();
          return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(clean) ||
              RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(clean);
        }
        String? targetGuid;
        if (isGuid(user?.id)) {
          targetGuid = user!.id;
        } else if (isGuid(user?.employeeId)) {
          targetGuid = user!.employeeId;
        }

        if (targetGuid != null && targetGuid.isNotEmpty) {
          try {
            await employeeService.updateEmployee(targetGuid, {
              'id': targetGuid,
              'avatar': uploadedUrl,
            });
          } catch (_) {}
        }
      }

      await ref.read(authServiceProvider.notifier).refreshCurrentUser();

      if (!mounted) return;

      setState(() {
        _isUploadingAvatar = false;
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          _avatarUrl = uploadedUrl;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Return uploaded URL back to previous screen
      Navigator.pop(context, uploadedUrl);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      final errStr = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload profile picture: $errStr'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildAvatarBlock(bool isDark) {
    final user = ref.read(authServiceProvider).user;
    final fullName = user?.fullName ?? 'User Profile';
    final effectiveAvatarUrl = _resolveAvatarUrl(_avatarUrl ?? user?.avatar);

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: GestureDetector(
          onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
          child: Stack(
            children: [
              Semantics(
                label: 'Profile avatar',
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    border: Border.all(color: isDark ? AppColors.darkMainSurface : Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: ClipOval(
                    child: _isUploadingAvatar
                        ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : (effectiveAvatarUrl.isNotEmpty
                            ? AuthenticatedImage(
                                imageUrl: effectiveAvatarUrl,
                                fit: BoxFit.cover,
                                placeholder: (c) => Container(
                                  color: AppColors.primary.withAlpha(50),
                                  child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                                ),
                                errorWidget: (c) => Center(
                                  child: Text(
                                    fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              )),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Semantics(
                  button: true,
                  label: 'Change profile picture',
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? AppColors.darkMainSurface : Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField(
    bool dark,
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    bool required = false,
    bool readOnly = false,
    String? helperText,
    String? prefixText,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    final inputBg = readOnly
        ? (dark ? AppColors.darkSecondarySurface : const Color(0xFFF1F5F9))
        : (dark ? AppColors.darkMainSurface : Colors.white);
    final borderColor = dark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        label: label,
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          textInputAction: textInputAction,
          style: TextStyle(
            color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            labelText: label,
            helperText: helperText,
            prefixText: prefixText,
            prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            suffixIcon: readOnly ? const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey) : null,
            labelStyle: TextStyle(color: dark ? AppColors.darkMutedText : AppColors.lightMutedText, fontSize: 12),
            filled: true,
            fillColor: inputBg,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: (value) {
            if (required && (value == null || value.trim().isEmpty)) {
              return '$label is required';
            }
            if (label == 'Email' && value != null && value.trim().isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
              return 'Enter a valid email address';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _datePickerField(bool dark, String label, TextEditingController controller) {
    final borderColor = dark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        label: label,
        button: true,
        child: TextFormField(
          controller: controller,
          readOnly: true,
          style: TextStyle(
            color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            labelText: label,
            helperText: 'Date format: YYYY-MM-DD',
            labelStyle: TextStyle(color: dark ? AppColors.darkMutedText : AppColors.lightMutedText, fontSize: 12),
            filled: true,
            fillColor: dark ? AppColors.darkMainSurface : Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            suffixIcon: const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 18),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onTap: () async {
            DateTime initial = DateTime.tryParse(controller.text) ?? DateTime(2000, 1, 1);
            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(1940),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              final formatted = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
              setState(() {
                controller.text = formatted;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _dropdown(bool dark, String label, String? value, List<String> options, ValueChanged<String?> onChanged) {
    final borderColor = dark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers;

    String formatOption(String option) {
      if (option.toUpperCase() == option && option.contains('_')) {
        final words = option.split('_');
        return words.map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');
      }
      if (option.toUpperCase() == option && option.length > 1) {
        return '${option[0].toUpperCase()}${option.substring(1).toLowerCase()}';
      }
      return option;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        label: label,
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          dropdownColor: dark ? AppColors.darkMainSurface : Colors.white,
          style: TextStyle(
            color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: dark ? AppColors.darkMutedText : AppColors.lightMutedText, fontSize: 12),
            filled: true,
            fillColor: dark ? AppColors.darkMainSurface : Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: options
              .map(
                (option) => DropdownMenuItem(
                  value: option,
                  child: Text(formatOption(option)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _gridPair(bool isCompact, Widget first, Widget second) {
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [first, second],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 340 || MediaQuery.textScalerOf(context).scale(1.0) > 1.3;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final navBottomInset = MediaQuery.paddingOf(context).bottom;

    if (_loading) {
      return const GlassScaffold(
        title: 'Edit Profile',
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return GlassScaffold(
      title: 'Edit Profile',
      body: Stack(
        children: [
          SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16, 16, 16, 100 + bottomInset + navBottomInset),
                children: [
                  // UI-ONLY: not wired (Visual avatar block)
                  _buildAvatarBlock(isDark),

                  FormSectionCard(
                    title: 'Personal Information',
                    subtitle: 'Identity and contact details',
                    icon: Icons.person_outline_rounded,
                    child: Column(
                      children: [
                        _gridPair(
                          isCompact,
                          _textField(isDark, 'First Name', _firstNameController, required: true),
                          _textField(isDark, 'Last Name', _lastNameController, required: true),
                        ),
                        _textField(isDark, 'Email', _emailController, keyboardType: TextInputType.emailAddress, required: true, readOnly: true),
                        _textField(isDark, 'Phone', _phoneController, keyboardType: TextInputType.phone, prefixText: '+91 '),
                        _datePickerField(isDark, 'Date of birth', _dobController),
                        _gridPair(
                          isCompact,
                          _dropdown(isDark, 'Gender', _gender, ['Male', 'Female', 'Other'], (v) => setState(() => _gender = v)),
                          _dropdown(isDark, 'Marital Status', _maritalStatus, ['SINGLE', 'MARRIED', 'DIVORCED', 'WIDOWED'], (v) => setState(() => _maritalStatus = v)),
                        ),
                        _gridPair(
                          isCompact,
                          _textField(isDark, 'Nationality', _nationalityController),
                          _dropdown(isDark, 'Blood Group', _bloodGroup, ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'], (v) => setState(() => _bloodGroup = v)),
                        ),
                      ],
                    ),
                  ),

                  FormSectionCard(
                    title: 'Address & Location',
                    subtitle: 'Residential and work address',
                    icon: Icons.location_on_outlined,
                    child: Column(
                      children: [
                        _textField(isDark, 'Address', _addressController),
                        _gridPair(
                          isCompact,
                          _textField(isDark, 'City', _cityController),
                          _textField(isDark, 'State', _stateController),
                        ),
                        _gridPair(
                          isCompact,
                          _textField(isDark, 'Country', _countryController),
                          _textField(isDark, 'ZIP Code', _zipCodeController, keyboardType: TextInputType.number),
                        ),
                        _gridPair(
                          isCompact,
                          _textField(isDark, 'Region', _regionController),
                          _textField(isDark, 'Work Location', _workLocationController),
                        ),
                      ],
                    ),
                  ),

                  FormSectionCard(
                    title: 'Identity & Tax Details',
                    subtitle: 'Government issued identity cards',
                    icon: Icons.badge_outlined,
                    child: Column(
                      children: [
                        _textField(isDark, 'Aadhaar Number', _aadhaarController, keyboardType: TextInputType.number, readOnly: true),
                        _gridPair(
                          isCompact,
                          _textField(isDark, 'PAN Card Number', _panController, readOnly: true),
                          _textField(isDark, 'Tax ID', _taxIdController),
                        ),
                      ],
                    ),
                  ),

                  FormSectionCard(
                    title: 'Financial & Bank Details',
                    subtitle: 'Bank accounts for salary disbursement',
                    icon: Icons.account_balance_outlined,
                    child: Column(
                      children: [
                        _textField(isDark, 'Bank Name', _bankNameController, readOnly: true),
                        _gridPair(
                          isCompact,
                          _textField(isDark, 'Bank Account Number', _bankAccountController, keyboardType: TextInputType.number, readOnly: true),
                          _textField(isDark, 'IFSC Code', _ifscController, readOnly: true, helperText: 'e.g. SBIN0001234'),
                        ),
                      ],
                    ),
                  ),

                  FormSectionCard(
                    title: 'Emergency Contact',
                    subtitle: 'Secondary contact for urgent needs',
                    icon: Icons.health_and_safety_outlined,
                    child: Column(
                      children: [
                        _gridPair(
                          isCompact,
                          _textField(isDark, 'Emergency Contact Name', _emergencyNameController),
                          _textField(isDark, 'Emergency Contact Relation', _emergencyRelationController),
                        ),
                        _textField(isDark, 'Emergency Contact Phone', _emergencyPhoneController, keyboardType: TextInputType.phone, prefixText: '+91 ', textInputAction: TextInputAction.done),
                      ],
                    ),
                  ),

                  if (_error != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Pinned Bottom Actions Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + navBottomInset),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkMainSurface : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 50 : 20),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                        side: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Save Changes',
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _saving
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
