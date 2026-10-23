import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';

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
    final empId = user?.employeeId ?? user?.id ?? '';

    final payload = <String, dynamic>{
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'dateOfBirth': _dobController.text.trim(),
      'gender': _gender,
      'maritalStatus': _maritalStatus,
      'nationality': _nationalityController.text.trim(),
      'bloodGroup': _bloodGroup,
      'address': _addressController.text.trim(),
      'city': _cityController.text.trim(),
      'state': _stateController.text.trim(),
      'country': _countryController.text.trim(),
      'zipCode': _zipCodeController.text.trim(),
      'region': _regionController.text.trim(),
      'workLocation': _workLocationController.text.trim(),
      'aadhaarNumber': _aadhaarController.text.trim(),
      'panNumber': _panController.text.trim(),
      'taxId': _taxIdController.text.trim(),
      'bankName': _bankNameController.text.trim(),
      'bankAccountNumber': _bankAccountController.text.trim(),
      'ifscCode': _ifscController.text.trim(),
      'emergencyContactName': _emergencyNameController.text.trim(),
      'emergencyContactPhone': _emergencyPhoneController.text.trim(),
      'emergencyContactRelation': _emergencyRelationController.text.trim(),
    };

    try {
      final apiClient = ref.read(apiClientProvider);
      if (empId.isNotEmpty) {
        await apiClient.put('${ApiEndpoints.employees}/$empId', body: payload);
      }

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _textField(
    bool dark,
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
          color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: dark ? AppColors.darkMutedText : AppColors.lightMutedText, fontSize: 12),
          filled: true,
          fillColor: dark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: dark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
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
    );
  }

  Widget _datePickerField(bool dark, String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        style: TextStyle(
          color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: dark ? AppColors.darkMutedText : AppColors.lightMutedText, fontSize: 12),
          filled: true,
          fillColor: dark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: dark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          suffixIcon: const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 18),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
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
    );
  }

  Widget _dropdown(bool dark, String label, String? value, List<String> options, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        dropdownColor: dark ? AppColors.darkMainSurface : Colors.white,
        style: TextStyle(
          color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: dark ? AppColors.darkMutedText : AppColors.lightMutedText, fontSize: 12),
          filled: true,
          fillColor: dark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: dark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem(
                value: option,
                child: Text(option),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _sectionHeader(bool dark, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _sectionHeader(isDark, 'Personal Information', Icons.person_outline_rounded),
              _textField(isDark, 'First Name', _firstNameController, required: true),
              _textField(isDark, 'Last Name', _lastNameController, required: true),
              _textField(isDark, 'Email', _emailController, keyboardType: TextInputType.emailAddress, required: true),
              _textField(isDark, 'Phone', _phoneController, keyboardType: TextInputType.phone),
              _datePickerField(isDark, 'Date of Birth (YYYY-MM-DD)', _dobController),
              _dropdown(isDark, 'Gender', _gender, ['Male', 'Female', 'Other'], (v) => setState(() => _gender = v)),
              _dropdown(isDark, 'Marital Status', _maritalStatus, ['SINGLE', 'MARRIED', 'DIVORCED', 'WIDOWED'], (v) => setState(() => _maritalStatus = v)),
              _textField(isDark, 'Nationality', _nationalityController),
              _dropdown(isDark, 'Blood Group', _bloodGroup, ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'], (v) => setState(() => _bloodGroup = v)),

              const SizedBox(height: 8),
              _sectionHeader(isDark, 'Address & Location', Icons.location_on_outlined),
              _textField(isDark, 'Address', _addressController),
              _textField(isDark, 'City', _cityController),
              _textField(isDark, 'State', _stateController),
              _textField(isDark, 'Country', _countryController),
              _textField(isDark, 'ZIP Code', _zipCodeController),
              _textField(isDark, 'Region', _regionController),
              _textField(isDark, 'Work Location', _workLocationController),

              const SizedBox(height: 8),
              _sectionHeader(isDark, 'Identity & Tax Details', Icons.badge_outlined),
              _textField(isDark, 'Aadhaar Number', _aadhaarController, keyboardType: TextInputType.number),
              _textField(isDark, 'PAN Card Number', _panController),
              _textField(isDark, 'Tax ID', _taxIdController),

              const SizedBox(height: 8),
              _sectionHeader(isDark, 'Financial & Bank Details', Icons.account_balance_outlined),
              _textField(isDark, 'Bank Name', _bankNameController),
              _textField(isDark, 'Bank Account Number', _bankAccountController, keyboardType: TextInputType.number),
              _textField(isDark, 'IFSC Code', _ifscController),

              const SizedBox(height: 8),
              _sectionHeader(isDark, 'Emergency Contact', Icons.health_and_safety_outlined),
              _textField(isDark, 'Emergency Contact Name', _emergencyNameController),
              _textField(isDark, 'Emergency Contact Phone', _emergencyPhoneController, keyboardType: TextInputType.phone),
              _textField(isDark, 'Emergency Contact Relation', _emergencyRelationController),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Changes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
