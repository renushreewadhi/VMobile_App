import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';

class AdminEmployeeFormScreen extends ConsumerStatefulWidget {
  final String? employeeId;
  final Map<String, dynamic>? initialData;

  const AdminEmployeeFormScreen({super.key, this.employeeId, this.initialData});

  @override
  ConsumerState<AdminEmployeeFormScreen> createState() => _AdminEmployeeFormScreenState();
}

class _AdminEmployeeFormScreenState extends ConsumerState<AdminEmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;
  int _currentStep = 1; // 4-step wizard matching Angular reference

  // Step 1: Personal Information
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _panController = TextEditingController();
  final TextEditingController _nationalityController = TextEditingController(text: 'Indian');
  final TextEditingController _bloodGroupController = TextEditingController();
  final TextEditingController _religionController = TextEditingController();
  final TextEditingController _avatarUrlController = TextEditingController();
  String _gender = 'Male';
  String _maritalStatus = 'Single';

  // Step 2: Contact Information
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _countryController = TextEditingController(text: 'India');
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _emergencyNameController = TextEditingController();
  final TextEditingController _emergencyPhoneController = TextEditingController();
  final TextEditingController _emergencyRelationshipController = TextEditingController();

  // Step 3: Job & Organizational Details
  final TextEditingController _employeeCodeController = TextEditingController();
  final TextEditingController _joiningDateController = TextEditingController();
  final TextEditingController _reportingManagerController = TextEditingController();
  final TextEditingController _shiftController = TextEditingController(text: 'General Shift');
  String? _department;
  String? _designation;
  String? _branch;
  String _employmentType = 'Full-Time';

  // Step 4: Compensation & Bank Details
  final TextEditingController _salaryController = TextEditingController(text: '120000');
  final TextEditingController _allowancesController = TextEditingController(text: '15000');
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _ifscController = TextEditingController();

  List<String> _departmentsList = ['Engineering', 'Human Resources', 'Sales', 'Finance', 'Marketing', 'Operations'];
  List<String> _designationsList = ['Software Engineer', 'Senior Developer', 'HR Manager', 'Account Executive', 'Product Manager'];
  List<String> _branchesList = ['Main Office', 'Pune Office', 'Bangalore Office', 'Delhi Office'];

  // Request ID guard
  int _requestId = 0;
  String? _currentUserId;

  bool get _isEdit => widget.employeeId != null || widget.initialData != null;

  final List<Map<String, String>> _steps = [
    {'title': 'Personal Info', 'subtitle': 'Basic details'},
    {'title': 'Contact Info', 'subtitle': 'How to reach'},
    {'title': 'Job Details', 'subtitle': 'Role & Department'},
    {'title': 'Salary & Bank', 'subtitle': 'Compensation'},
  ];

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
      });
      return;
    }

    if (_currentUserId != user.id) {
      _currentUserId = user.id;
    }

    _loadLookupsAndDetail();
  }

  Future<void> _loadLookupsAndDetail() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() => _isLoading = true);

    final apiClient = ref.read(apiClientProvider);

    try {
      try {
        final deptRes = await apiClient.get(ApiEndpoints.departments);
        if (!mounted || currentReq != _requestId) return;
        if (deptRes is List) {
          _departmentsList = deptRes.map((d) => (d['name'] ?? '').toString()).where((n) => n.isNotEmpty).toList();
        }
      } catch (_) {}

      try {
        final desigRes = await apiClient.get(ApiEndpoints.designations);
        if (!mounted || currentReq != _requestId) return;
        if (desigRes is List) {
          _designationsList = desigRes.map((d) => (d['title'] ?? '').toString()).where((n) => n.isNotEmpty).toList();
        }
      } catch (_) {}

      try {
        final branchRes = await apiClient.get(ApiEndpoints.branches);
        if (!mounted || currentReq != _requestId) return;
        if (branchRes is List) {
          _branchesList = branchRes.map((b) => (b['name'] ?? '').toString()).where((n) => n.isNotEmpty).toList();
        }
      } catch (_) {}

      if (!mounted || currentReq != _requestId) return;

      if (widget.initialData != null) {
        _populateData(widget.initialData!);
      } else if (_isEdit && widget.employeeId != null) {
        final res = await apiClient.get(ApiEndpoints.employeeDetail(widget.employeeId!));
        if (!mounted || currentReq != _requestId) return;
        dynamic rawData = res is Map<String, dynamic> && res.containsKey('data') ? res['data'] : res;
        if (rawData is Map<String, dynamic>) {
          _populateData(rawData);
        }
      } else {
        if (_departmentsList.isNotEmpty) _department = _departmentsList.first;
        if (_designationsList.isNotEmpty) _designation = _designationsList.first;
        if (_branchesList.isNotEmpty) _branch = _branchesList.first;
      }
    } catch (e) {
      if (widget.initialData != null) {
        _populateData(widget.initialData!);
      }
    } finally {
      if (mounted && currentReq == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _populateData(Map<String, dynamic> data) {
    _firstNameController.text = data['firstName']?.toString() ?? '';
    _lastNameController.text = data['lastName']?.toString() ?? '';
    _emailController.text = data['email']?.toString() ?? '';
    _phoneController.text = data['phone']?.toString() ?? '';
    _addressController.text = data['address']?.toString() ?? '';
    _cityController.text = data['city']?.toString() ?? '';
    _stateController.text = data['state']?.toString() ?? '';
    _countryController.text = data['country']?.toString() ?? 'India';
    _postalCodeController.text = data['postalCode']?.toString() ?? '';
    _emergencyNameController.text = data['emergencyContactName']?.toString() ?? '';
    _emergencyPhoneController.text = data['emergencyContactPhone']?.toString() ?? '';
    _emergencyRelationshipController.text = data['emergencyContactRelationship']?.toString() ?? '';
    _employeeCodeController.text = data['employeeId']?.toString() ?? data['code']?.toString() ?? '';
    _joiningDateController.text = data['joiningDate']?.toString() ?? '';
    _dobController.text = data['dateOfBirth']?.toString() ?? '';
    _aadhaarController.text = data['aadhaar']?.toString() ?? '';
    _panController.text = data['pan']?.toString() ?? '';
    _nationalityController.text = data['nationality']?.toString() ?? 'Indian';
    _bloodGroupController.text = data['bloodGroup']?.toString() ?? '';
    _religionController.text = data['religion']?.toString() ?? '';
    _avatarUrlController.text = data['avatar']?.toString() ?? data['avatarUrl']?.toString() ?? '';
    _reportingManagerController.text = data['reportingManager']?.toString() ?? '';
    _shiftController.text = data['shift']?.toString() ?? 'General Shift';

    _salaryController.text = '${data['salary'] ?? data['basicSalary'] ?? 120000}';
    _allowancesController.text = '${data['allowances'] ?? 15000}';
    _bankNameController.text = data['bankName']?.toString() ?? '';
    _accountNumberController.text = data['accountNumber']?.toString() ?? '';
    _ifscController.text = data['ifscCode']?.toString() ?? '';

    _gender = data['gender']?.toString() ?? 'Male';
    _maritalStatus = data['maritalStatus']?.toString() ?? 'Single';

    final dept = data['department']?.toString();
    if (dept != null && _departmentsList.contains(dept)) {
      _department = dept;
    } else if (_departmentsList.isNotEmpty) {
      _department = _departmentsList.first;
    }

    final desig = data['designation']?.toString();
    if (desig != null && _designationsList.contains(desig)) {
      _designation = desig;
    } else if (_designationsList.isNotEmpty) {
      _designation = _designationsList.first;
    }

    final br = data['branch']?.toString();
    if (br != null && _branchesList.contains(br)) {
      _branch = br;
    } else if (_branchesList.isNotEmpty) {
      _branch = _branchesList.first;
    }

    _employmentType = data['employmentType']?.toString() ?? 'Full-Time';
  }

  bool _validateCurrentStep() {
    if (_currentStep == 1) {
      if (_firstNameController.text.trim().isEmpty || _lastNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill required fields: First Name, Last Name.')),
        );
        return false;
      }
    } else if (_currentStep == 2) {
      if (_emailController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill required fields: Email Address, Phone Number.')),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _saveEmployee() async {
    if (!_validateCurrentStep()) return;

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'gender': _gender,
      'maritalStatus': _maritalStatus,
      'dateOfBirth': _dobController.text.trim().isEmpty ? null : _dobController.text.trim(),
      'aadhaar': _aadhaarController.text.trim().isEmpty ? null : _aadhaarController.text.trim(),
      'pan': _panController.text.trim().isEmpty ? null : _panController.text.trim(),
      'nationality': _nationalityController.text.trim().isEmpty ? null : _nationalityController.text.trim(),
      'bloodGroup': _bloodGroupController.text.trim().isEmpty ? null : _bloodGroupController.text.trim(),
      'religion': _religionController.text.trim().isEmpty ? null : _religionController.text.trim(),
      'avatar': _avatarUrlController.text.trim().isEmpty ? null : _avatarUrlController.text.trim(),
      'address': _addressController.text.trim(),
      'city': _cityController.text.trim(),
      'state': _stateController.text.trim(),
      'country': _countryController.text.trim(),
      'postalCode': _postalCodeController.text.trim(),
      'emergencyContactName': _emergencyNameController.text.trim(),
      'emergencyContactPhone': _emergencyPhoneController.text.trim(),
      'emergencyContactRelationship': _emergencyRelationshipController.text.trim(),
      'employeeId': _employeeCodeController.text.trim().isEmpty ? null : _employeeCodeController.text.trim(),
      'joiningDate': _joiningDateController.text.trim().isEmpty ? null : _joiningDateController.text.trim(),
      'department': _department,
      'designation': _designation,
      'branch': _branch,
      'employmentType': _employmentType,
      'reportingManager': _reportingManagerController.text.trim().isEmpty ? null : _reportingManagerController.text.trim(),
      'shift': _shiftController.text.trim().isEmpty ? null : _shiftController.text.trim(),
      'salary': double.tryParse(_salaryController.text.trim()) ?? 120000,
      'allowances': double.tryParse(_allowancesController.text.trim()) ?? 15000,
      'bankName': _bankNameController.text.trim().isEmpty ? null : _bankNameController.text.trim(),
      'accountNumber': _accountNumberController.text.trim().isEmpty ? null : _accountNumberController.text.trim(),
      'ifscCode': _ifscController.text.trim().isEmpty ? null : _ifscController.text.trim(),
    };

    try {
      if (_isEdit && widget.employeeId != null) {
        await apiClient.put(ApiEndpoints.employeeDetail(widget.employeeId!), body: payload);
      } else {
        await apiClient.post(ApiEndpoints.employees, body: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Employee updated successfully' : 'Employee created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : 'Failed to save employee.';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    if (_isLoading) {
      return GlassScaffold(
        appBar: GlassHeader(title: _isEdit ? 'Edit Employee Record' : 'Add New Employee'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return GlassScaffold(
      appBar: GlassHeader(
        title: _isEdit ? 'Edit Employee Details' : 'Add New Employee',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Hero Header Banner
              _buildHeroHeaderBanner(),
              const SizedBox(height: 20),

              // 2. Stepper Progress Component
              _buildStepperProgressBar(),
              const SizedBox(height: 20),

              // 3. Step Content Panel
              Container(
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.03), blurRadius: 16, offset: Offset(0, 4))],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentStep == 1) _buildStep1Personal(glass),
                    if (_currentStep == 2) _buildStep2Contact(glass),
                    if (_currentStep == 3) _buildStep3Job(glass),
                    if (_currentStep == 4) _buildStep4Compensation(glass),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. Footer Actions Navigation Bar
              _buildFooterActionsBar(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7FF)),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(99, 102, 241, 0.05), blurRadius: 20, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ONBOARDING PORTAL',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFEA580C), letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isEdit ? 'Edit Employee Details' : 'Add New Employee',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Create a new employee record and complete the onboarding details.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [BoxShadow(color: Color.fromRGBO(37, 99, 235, 0.06), blurRadius: 10, offset: Offset(0, 2))],
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: const Color(0xFFE0EDFF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(height: 6),
                const Text('Build A Stronger Team', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 2),
                Container(width: 32, height: 3, decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(2))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(_steps.length, (index) {
              final stepNum = index + 1;
              final isCompleted = _currentStep > stepNum;
              final isActive = _currentStep == stepNum;

              return Expanded(
                child: InkWell(
                  onTap: () {
                    if (stepNum < _currentStep || _validateCurrentStep()) {
                      setState(() => _currentStep = stepNum);
                    }
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isCompleted || isActive ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: isCompleted
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : Text(
                                '$stepNum',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _steps[index]['title']!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                                color: isActive ? const Color(0xFF2563EB) : const Color(0xFF334155),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _steps[index]['subtitle']!,
                              style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (index < _steps.length - 1)
                        Container(
                          width: 16,
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: isCompleted ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader(String title, String subtitle, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: const Color(0xFFE0EDFF), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, size: 12, color: Color(0xFF2563EB)),
                  SizedBox(width: 4),
                  Text('Fields marked with * are required', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStep1Personal(GlassTheme glass) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('Personal Information', 'Enter the basic details of the employee', Icons.person_outline_rounded),
        Row(
          children: [
            Expanded(
              child: _buildInputField('First Name *', _firstNameController, Icons.person_outline, 'Enter first name'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputField('Last Name *', _lastNameController, Icons.person_outline, 'Enter last name'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Gender *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildGenderCard('Male')),
            const SizedBox(width: 12),
            Expanded(child: _buildGenderCard('Female')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildInputField('Date of Birth *', _dobController, Icons.calendar_today_outlined, 'YYYY-MM-DD'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdownField('Marital Status', _maritalStatus, ['Single', 'Married', 'Divorced', 'Widowed'], (val) {
                setState(() => _maritalStatus = val ?? 'Single');
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildInputField('Nationality', _nationalityController, Icons.flag_outlined, 'Indian'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputField('Blood Group', _bloodGroupController, Icons.invert_colors_outlined, 'e.g. B+'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildInputField('Aadhaar Number', _aadhaarController, Icons.badge_outlined, 'e.g. 4545-6343-6547'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputField('PAN Number', _panController, Icons.credit_card_outlined, 'e.g. ABCDE1234F'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildInputField('Image URL', _avatarUrlController, Icons.link_rounded, 'https://example.com/photo.jpg'),
      ],
    );
  }

  Widget _buildStep2Contact(GlassTheme glass) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('Contact Information', 'How to reach the employee and emergency contacts', Icons.phone_in_talk_outlined),
        Row(
          children: [
            Expanded(
              child: _buildInputField('Email Address *', _emailController, Icons.mail_outline_rounded, 'Enter email address', isEmail: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputField('Phone Number *', _phoneController, Icons.phone_outlined, 'Enter phone number', isPhone: true),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildInputField('Street Address', _addressController, Icons.location_on_outlined, 'Enter street address'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildInputField('City', _cityController, Icons.location_city_outlined, 'Enter city')),
            const SizedBox(width: 12),
            Expanded(child: _buildInputField('State', _stateController, Icons.map_outlined, 'Enter state')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildInputField('Country', _countryController, Icons.public_outlined, 'Enter country')),
            const SizedBox(width: 12),
            Expanded(child: _buildInputField('Postal Code', _postalCodeController, Icons.markunread_mailbox_outlined, 'Enter postal code')),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Emergency Contact Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 12),
        _buildInputField('Contact Person', _emergencyNameController, Icons.person_outline, 'Enter contact name'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildInputField('Emergency Phone', _emergencyPhoneController, Icons.phone_outlined, 'Enter phone', isPhone: true)),
            const SizedBox(width: 12),
            Expanded(child: _buildInputField('Relationship', _emergencyRelationshipController, Icons.people_outline, 'Relationship')),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3Job(GlassTheme glass) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('Job & Organizational Details', 'Assign department, designation, branch, and role parameters', Icons.work_outline_rounded),
        Row(
          children: [
            Expanded(child: _buildInputField('Employee ID', _employeeCodeController, Icons.badge_outlined, 'e.g. EMP-26-0009')),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdownField('Department *', _department, _departmentsList, (val) => setState(() => _department = val)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField('Designation *', _designation, _designationsList, (val) => setState(() => _designation = val)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdownField('Branch Location *', _branch, _branchesList, (val) => setState(() => _branch = val)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildInputField('Joining Date *', _joiningDateController, Icons.calendar_today_outlined, 'YYYY-MM-DD')),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdownField('Employment Type', _employmentType, ['Full-Time', 'Part-Time', 'Contract', 'Internship'], (val) {
                setState(() => _employmentType = val ?? 'Full-Time');
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildInputField('Reporting Manager', _reportingManagerController, Icons.person_outline, 'Manager name')),
            const SizedBox(width: 12),
            Expanded(child: _buildInputField('Shift', _shiftController, Icons.access_time_rounded, 'Shift name')),
          ],
        ),
      ],
    );
  }

  Widget _buildStep4Compensation(GlassTheme glass) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('Compensation & Bank Details', 'Set basic salary structure and payroll accounts', Icons.account_balance_wallet_outlined),
        Row(
          children: [
            Expanded(child: _buildInputField('Basic Salary (₹) *', _salaryController, Icons.currency_rupee_rounded, '0.00', isNumber: true)),
            const SizedBox(width: 12),
            Expanded(child: _buildInputField('Allowances (₹)', _allowancesController, Icons.currency_rupee_rounded, '0.00', isNumber: true)),
          ],
        ),
        const SizedBox(height: 16),
        _buildInputField('Bank Name', _bankNameController, Icons.account_balance_outlined, 'Enter bank name'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildInputField('Account Number', _accountNumberController, Icons.credit_card_outlined, 'Enter account number')),
            const SizedBox(width: 12),
            Expanded(child: _buildInputField('IFSC Code', _ifscController, Icons.code_rounded, 'Enter IFSC code')),
          ],
        ),
      ],
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon, String hint, {bool isEmail = false, bool isPhone = false, bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF64748B)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !_isSaving,
                  keyboardType: isEmail ? TextInputType.emailAddress : (isPhone || isNumber ? TextInputType.number : TextInputType.text),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String? selectedValue, List<String> options, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: options.contains(selectedValue) ? selectedValue : (options.isNotEmpty ? options.first : null),
              isExpanded: true,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
              items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
              onChanged: _isSaving ? null : onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderCard(String value) {
    final isSelected = _gender == value;
    return InkWell(
      onTap: _isSaving ? null : () => setState(() => _gender = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0), width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterActionsBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
        ),
        Row(
          children: [
            if (_currentStep > 1) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSaving ? null : () => setState(() => _currentStep--),
              ),
              const SizedBox(width: 12),
            ],
            if (_currentStep < 4) ...[
              ElevatedButton.icon(
                icon: const Text('Next'),
                label: const Icon(Icons.arrow_forward_rounded, size: 16),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  if (_validateCurrentStep()) {
                    setState(() => _currentStep++);
                  }
                },
              ),
            ] else ...[
              ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(_isEdit ? 'Save Changes' : 'Submit Employee'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: _isSaving ? null : _saveEmployee,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
