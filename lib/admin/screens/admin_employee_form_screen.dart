import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/errors/api_exception.dart';
import '../../core/theme/glass_theme.dart';
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
  String _region = 'All Regions';
  final List<String> _regionsList = ['All Regions', 'North', 'South', 'East', 'West', 'Central'];
  List<String> _countriesList = ['India', 'United States', 'United Kingdom', 'Canada', 'Australia', 'UAE', 'Singapore', 'Germany', 'France', 'Japan'];
  List<String> _allStatesList = [];
  List<String> _statesList = ['Tamil Nadu', 'Maharashtra', 'Karnataka', 'Delhi', 'Telangana', 'Gujarat', 'Uttar Pradesh', 'Other'];

  // Step 3: Job & Organizational Details
  final TextEditingController _employeeCodeController = TextEditingController();
  final TextEditingController _joiningDateController = TextEditingController();
  final TextEditingController _branchFromDateController = TextEditingController();
  final TextEditingController _branchToDateController = TextEditingController();
  final TextEditingController _workLocationController = TextEditingController();
  String? _department;
  String? _designation;
  String? _branch;
  String _employmentType = 'Full-Time';
  String? _reportingManager;
  String? _team;
  String? _shift = 'General Shift';

  final List<String> _employmentTypesList = ['Full-Time', 'Part-Time', 'Contract', 'Internship'];
  List<String> _shiftsList = ['General Shift', 'Morning Shift', 'Night Shift', 'Rotational Shift'];
  List<String> _teamsList = ['Engineering Team', 'Product Team', 'Sales Team', 'HR Team', 'Operations Team'];
  List<String> _managersList = ['Admin User', 'HR Manager', 'Tech Lead', 'Operations Manager'];

  // Step 4: Compensation & Bank Details
  final TextEditingController _salaryController = TextEditingController(text: '120000');
  final TextEditingController _allowancesController = TextEditingController(text: '15000');
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _ifscController = TextEditingController();
  final TextEditingController _taxIdController = TextEditingController();

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

  Future<void> _fetchCountriesApi() async {
    try {
      final response = await http.get(Uri.parse('https://countriesnow.space/api/v0.1/countries/iso')).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['data'] is List) {
          final list = (decoded['data'] as List)
              .map((c) => c is Map ? c['name']?.toString() : null)
              .whereType<String>()
              .where((n) => n.isNotEmpty)
              .toList();
          if (list.isNotEmpty && mounted) {
            setState(() {
              _countriesList = list..sort();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[AdminEmployeeForm] Countries API fetch exception: $e');
    }
  }

  Future<void> _fetchStatesForCountry(String country) async {
    if (country.trim().isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse('https://countriesnow.space/api/v0.1/countries/states'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'country': country}),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['data'] is Map && decoded['data']['states'] is List) {
          final fetchedStates = (decoded['data']['states'] as List)
              .map((s) => s is Map ? s['name']?.toString() : null)
              .whereType<String>()
              .where((n) => n.isNotEmpty)
              .toList();
          if (fetchedStates.isNotEmpty && mounted) {
            setState(() {
              _allStatesList = fetchedStates..sort();
              _updateFilteredStates();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[AdminEmployeeForm] States API fetch exception: $e');
    }
  }

  void _updateFilteredStates() {
    if (_allStatesList.isEmpty) return;

    List<String> filteredList = List.from(_allStatesList);

    if (_region == 'South') {
      final keywords = ['tamil nadu', 'kerala', 'karnataka', 'andhra', 'telangana', 'pondicherry', 'puducherry'];
      final matches = _allStatesList.where((s) => keywords.any((k) => s.toLowerCase().contains(k))).toList();
      if (matches.isNotEmpty) filteredList = matches;
    } else if (_region == 'North') {
      final keywords = ['delhi', 'punjab', 'haryana', 'himachal', 'uttar', 'jammu', 'kashmir', 'ladakh', 'uttarakhand', 'rajasthan'];
      final matches = _allStatesList.where((s) => keywords.any((k) => s.toLowerCase().contains(k))).toList();
      if (matches.isNotEmpty) filteredList = matches;
    } else if (_region == 'West') {
      final keywords = ['maharashtra', 'gujarat', 'goa', 'daman', 'diu'];
      final matches = _allStatesList.where((s) => keywords.any((k) => s.toLowerCase().contains(k))).toList();
      if (matches.isNotEmpty) filteredList = matches;
    } else if (_region == 'East') {
      final keywords = ['bengal', 'odisha', 'bihar', 'jharkhand', 'assam', 'sikkim', 'tripura', 'meghalaya', 'manipur', 'nagaland', 'mizoram', 'arunachal'];
      final matches = _allStatesList.where((s) => keywords.any((k) => s.toLowerCase().contains(k))).toList();
      if (matches.isNotEmpty) filteredList = matches;
    } else if (_region == 'Central') {
      final keywords = ['madhya pradesh', 'chhattisgarh'];
      final matches = _allStatesList.where((s) => keywords.any((k) => s.toLowerCase().contains(k))).toList();
      if (matches.isNotEmpty) filteredList = matches;
    }

    setState(() {
      _statesList = filteredList;
      if (_stateController.text.isEmpty || !_statesList.contains(_stateController.text)) {
        if (_statesList.isNotEmpty) {
          _stateController.text = _statesList.first;
        }
      }
    });
  }

  Future<void> _loadLookupsAndDetail() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() => _isLoading = true);

    final apiClient = ref.read(apiClientProvider);

    try {
      // Fetch Countries & States from countriesnow API
      _fetchCountriesApi();
      _fetchStatesForCountry(_countryController.text.isNotEmpty ? _countryController.text : 'India');

      try {
        final deptRes = await apiClient.get(ApiEndpoints.departments).catchError((_) => null);
        if (!mounted || currentReq != _requestId) return;
        final rawDepts = deptRes is List ? deptRes : (deptRes is Map ? (deptRes['data'] ?? deptRes['items'] ?? []) : []);
        if (rawDepts is List && rawDepts.isNotEmpty) {
          _departmentsList = rawDepts.map((d) => (d['name'] ?? d['departmentName'] ?? '').toString()).where((n) => n.isNotEmpty).toList();
        }
      } catch (_) {}

      try {
        final desigRes = await apiClient.get(ApiEndpoints.designations).catchError((_) => null);
        if (!mounted || currentReq != _requestId) return;
        final rawDesigs = desigRes is List ? desigRes : (desigRes is Map ? (desigRes['data'] ?? desigRes['items'] ?? []) : []);
        if (rawDesigs is List && rawDesigs.isNotEmpty) {
          _designationsList = rawDesigs.map((d) => (d['title'] ?? d['name'] ?? d['designationTitle'] ?? '').toString()).where((n) => n.isNotEmpty).toList();
        }
      } catch (_) {}

      try {
        final branchRes = await apiClient.get(ApiEndpoints.branches).catchError((_) => null);
        if (!mounted || currentReq != _requestId) return;
        final rawBranches = branchRes is List ? branchRes : (branchRes is Map ? (branchRes['data'] ?? branchRes['items'] ?? []) : []);
        if (rawBranches is List && rawBranches.isNotEmpty) {
          _branchesList = rawBranches.map((b) => (b['name'] ?? b['branchName'] ?? '').toString()).where((n) => n.isNotEmpty).toList();
        }
      } catch (_) {}

      try {
        final teamsRes = await apiClient.get(ApiEndpoints.teams).catchError((_) => null);
        if (!mounted || currentReq != _requestId) return;
        final rawTeams = teamsRes is List ? teamsRes : (teamsRes is Map ? (teamsRes['data'] ?? teamsRes['items'] ?? []) : []);
        if (rawTeams is List && rawTeams.isNotEmpty) {
          _teamsList = rawTeams.map((t) => (t['name'] ?? t['teamName'] ?? '').toString()).where((n) => n.isNotEmpty).toList();
        }
      } catch (_) {}

      try {
        final shiftsRes = await apiClient.get(ApiEndpoints.shifts).catchError((_) => null);
        if (!mounted || currentReq != _requestId) return;
        final rawShifts = shiftsRes is List ? shiftsRes : (shiftsRes is Map ? (shiftsRes['data'] ?? shiftsRes['items'] ?? []) : []);
        if (rawShifts is List && rawShifts.isNotEmpty) {
          _shiftsList = rawShifts.map((s) => (s['name'] ?? s['shiftName'] ?? s['title'] ?? '').toString()).where((n) => n.isNotEmpty).toList();
        }
      } catch (_) {}

      try {
        final managersRes = await apiClient.get(ApiEndpoints.teamLeads).catchError((_) async {
          return await apiClient.get(ApiEndpoints.employeesAll).catchError((_) => null);
        });
        if (!mounted || currentReq != _requestId) return;
        final rawMgrs = managersRes is List ? managersRes : (managersRes is Map ? (managersRes['data'] ?? managersRes['items'] ?? []) : []);
        if (rawMgrs is List && rawMgrs.isNotEmpty) {
          _managersList = rawMgrs.map((m) => (m['fullName'] ?? '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}' ?? m['name'] ?? '').toString().trim()).where((n) => n.isNotEmpty).toList();
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
        if (_teamsList.isNotEmpty) _team = _teamsList.first;
        if (_shiftsList.isNotEmpty) _shift = _shiftsList.first;
        if (_managersList.isNotEmpty) _reportingManager = _managersList.first;
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
    _branchFromDateController.text = data['branchFromDate']?.toString() ?? '';
    _branchToDateController.text = data['branchToDate']?.toString() ?? '';
    _workLocationController.text = data['workLocation']?.toString() ?? '';
    _dobController.text = data['dateOfBirth']?.toString() ?? '';
    _aadhaarController.text = data['aadhaar']?.toString() ?? '';
    _panController.text = data['pan']?.toString() ?? '';
    _nationalityController.text = data['nationality']?.toString() ?? 'Indian';
    _bloodGroupController.text = data['bloodGroup']?.toString() ?? '';
    _religionController.text = data['religion']?.toString() ?? '';
    _avatarUrlController.text = data['avatar']?.toString() ?? data['avatarUrl']?.toString() ?? '';
    _reportingManager = data['reportingManager']?.toString();
    _team = data['team']?.toString();
    _shift = data['shift']?.toString() ?? 'General Shift';

    _region = data['region']?.toString() ?? 'All Regions';
    if (!_regionsList.contains(_region)) _region = 'All Regions';

    _salaryController.text = '${data['salary'] ?? data['basicSalary'] ?? 120000}';
    _allowancesController.text = '${data['allowances'] ?? 15000}';
    _bankNameController.text = data['bankName']?.toString() ?? '';
    _accountNumberController.text = data['accountNumber']?.toString() ?? '';
    _ifscController.text = data['ifscCode']?.toString() ?? '';
    _taxIdController.text = data['taxId']?.toString() ?? '';

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
      if (_emailController.text.trim().isEmpty ||
          _phoneController.text.trim().isEmpty ||
          _addressController.text.trim().isEmpty ||
          _cityController.text.trim().isEmpty ||
          _countryController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill required fields: Email Address, Phone Number, Street Address, City, Country.')),
        );
        return false;
      }
    } else if (_currentStep == 3) {
      if (_joiningDateController.text.trim().isEmpty ||
          _department == null ||
          _designation == null ||
          _branch == null ||
          _employmentType.isEmpty ||
          _shift == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill required fields: Joining Date, Department, Designation, Branch, Employment Type, Shift.')),
        );
        return false;
      }
    } else if (_currentStep == 4) {
      if (_salaryController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill required field: Basic Salary.')),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F6B63),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final formatted = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      controller.text = formatted;
    }
  }

  Future<void> _uploadAvatarPicture() async {
    final controller = TextEditingController(text: _avatarUrlController.text);
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload Profile Picture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter image URL or select photo for profile picture:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'https://example.com/photo.jpg',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6B63), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (url != null && url.isNotEmpty) {
      setState(() => _avatarUrlController.text = url);
    }
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
      'region': _region,
      'postalCode': _postalCodeController.text.trim(),
      'emergencyContactName': _emergencyNameController.text.trim(),
      'emergencyContactPhone': _emergencyPhoneController.text.trim(),
      'emergencyContactRelationship': _emergencyRelationshipController.text.trim(),
      'employeeId': _employeeCodeController.text.trim().isEmpty ? null : _employeeCodeController.text.trim(),
      'joiningDate': _joiningDateController.text.trim().isEmpty ? null : _joiningDateController.text.trim(),
      'branchFromDate': _branchFromDateController.text.trim().isEmpty ? null : _branchFromDateController.text.trim(),
      'branchToDate': _branchToDateController.text.trim().isEmpty ? null : _branchToDateController.text.trim(),
      'workLocation': _workLocationController.text.trim().isEmpty ? null : _workLocationController.text.trim(),
      'department': _department,
      'designation': _designation,
      'branch': _branch,
      'employmentType': _employmentType,
      'reportingManager': _reportingManager,
      'team': _team,
      'shift': _shift,
      'salary': double.tryParse(_salaryController.text.trim().replaceAll(',', '')) ?? 120000,
      'allowances': double.tryParse(_allowancesController.text.trim().replaceAll(',', '')) ?? 15000,
      'bankName': _bankNameController.text.trim().isEmpty ? null : _bankNameController.text.trim(),
      'accountNumber': _accountNumberController.text.trim().isEmpty ? null : _accountNumberController.text.trim(),
      'ifscCode': _ifscController.text.trim().isEmpty ? null : _ifscController.text.trim(),
      'taxId': _taxIdController.text.trim().isEmpty ? null : _taxIdController.text.trim(),
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
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF0F6B63))),
      );
    }

    return GlassScaffold(
      appBar: GlassHeader(
        title: _isEdit ? 'Edit Employee Details' : 'Add New Employee',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 126),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Hero Header Banner
              _buildHeroHeaderBanner(),
              const SizedBox(height: 12),

              // 2. Stepper Progress Component
              _buildStepperProgressBar(),
              const SizedBox(height: 12),

              // 3. Step Content Panel (Form Card)
              Container(
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.04), blurRadius: 16, offset: Offset(0, 4))],
                ),
                padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 16),

              // 4. Footer Actions Navigation Bar
              _buildFooterActionsBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE6F4F1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 107, 99, 0.02), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4F1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'ONBOARDING PORTAL',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0F6B63), letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isEdit ? 'Edit Employee Details' : 'Add New Employee',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), letterSpacing: -0.5),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Create a new employee record and complete the onboarding details.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.04), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: const Color(0xFFE6F4F1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF0F6B63), size: 16),
                ),
                const SizedBox(height: 4),
                const Text('Build A Stronger Team', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Container(width: 20, height: 2, decoration: BoxDecoration(color: const Color(0xFF0F6B63), borderRadius: BorderRadius.circular(1))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperProgressBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(_steps.length, (index) {
            final stepNum = index + 1;
            final isCompleted = _currentStep > stepNum;
            final isActive = _currentStep == stepNum;
            final canTap = stepNum < _currentStep || isCompleted;

            return InkWell(
              onTap: () {
                if (canTap || _validateCurrentStep()) {
                  setState(() => _currentStep = stepNum);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF0F6B63)
                            : (isActive ? Colors.white : const Color(0xFFF1F5F9)),
                        shape: BoxShape.circle,
                        border: isActive ? Border.all(color: const Color(0xFF0F6B63), width: 2) : null,
                        boxShadow: isActive ? const [BoxShadow(color: Color.fromRGBO(15, 107, 99, 0.2), blurRadius: 0, spreadRadius: 4)] : null,
                      ),
                      alignment: Alignment.center,
                      child: isCompleted
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : Text(
                              '$stepNum',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isActive ? const Color(0xFF0F6B63) : const Color(0xFF64748B),
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _steps[index]['title']!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isActive ? const Color(0xFF0F6B63) : const Color(0xFF0F172A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _steps[index]['subtitle']!,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    if (index < _steps.length - 1)
                      Container(
                        width: 16,
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        color: isCompleted ? const Color(0xFF0F6B63) : const Color(0xFFE2E8F0),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStepHeader(String title, String subtitle, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4F1),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: const Color(0xFF0F6B63), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4F1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Step $_currentStep of 4',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F6B63)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        const SizedBox(height: 12),
        Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F4F1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.info_outline, size: 14, color: Color(0xFF0F6B63)),
              SizedBox(width: 4),
              Text(
                'Fields marked with * are required',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F6B63)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 14),
        _buildDropdownField('Gender *', _gender, ['Male', 'Female', 'Other'], (val) {
          setState(() => _gender = val ?? 'Male');
        }),
        const SizedBox(height: 14),
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
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField(
                'Nationality',
                _nationalityController.text.isNotEmpty ? _nationalityController.text : 'Indian',
                ['Indian', 'American', 'British', 'Canadian', 'Australian', 'Singaporean', 'Other'],
                (val) {
                  setState(() => _nationalityController.text = val ?? 'Indian');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputField('Blood Group', _bloodGroupController, Icons.invert_colors_outlined, 'e.g. B+'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildInputField('Aadhaar Number', _aadhaarController, Icons.badge_outlined, 'e.g. 4545-6343-6547', isNumber: true),
        const SizedBox(height: 14),
        _buildInputField('PAN Number', _panController, Icons.credit_card_outlined, 'e.g. ABCDE1234F'),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile Picture',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: _isSaving ? null : () => _uploadAvatarPicture(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.cloud_upload_rounded, size: 20, color: Color(0xFF0F172A)),
                    SizedBox(width: 8),
                    Text(
                      'Upload Profile Picture',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Or paste an image URL below',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        const SizedBox(height: 6),
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
            Expanded(child: _buildInputField('Email Address *', _emailController, Icons.mail_outline_rounded, 'Enter email address', isEmail: true)),
            const SizedBox(width: 12),
            Expanded(child: _buildInputField('Phone Number *', _phoneController, Icons.phone_outlined, 'Enter 10 digit phone number', isPhone: true)),
          ],
        ),
        const SizedBox(height: 14),
        _buildInputField('Street Address *', _addressController, Icons.location_on_outlined, 'Enter street address'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField(
                'Country *',
                _countryController.text.isNotEmpty ? _countryController.text : 'India',
                _countriesList,
                (val) {
                  if (val != null) {
                    setState(() => _countryController.text = val);
                    _fetchStatesForCountry(val);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdownField('Region', _region, _regionsList, (val) {
                if (val != null) {
                  setState(() => _region = val);
                  _updateFilteredStates();
                }
              }),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _statesList.isNotEmpty
                  ? _buildDropdownField(
                      'State / Province',
                      _statesList.contains(_stateController.text) ? _stateController.text : (_statesList.isNotEmpty ? _statesList.first : null),
                      _statesList,
                      (val) {
                        if (val != null) setState(() => _stateController.text = val);
                      },
                    )
                  : _buildInputField('State / Province', _stateController, Icons.map_outlined, 'Enter state'),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildInputField('City *', _cityController, Icons.location_city_outlined, 'Enter city')),
          ],
        ),
        const SizedBox(height: 14),
        _buildInputField('Postal Code', _postalCodeController, Icons.markunread_mailbox_outlined, 'Enter postal code', isNumber: true),
        const SizedBox(height: 20),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        const SizedBox(height: 16),
        Row(
          children: const [
            Icon(Icons.shield_outlined, size: 16, color: Color(0xFF0F6B63)),
            SizedBox(width: 8),
            Text('Emergency Contact Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildInputField('Emergency Contact Name', _emergencyNameController, Icons.person_outline, 'Enter emergency contact name')),
            const SizedBox(width: 12),
            Expanded(child: _buildInputField('Emergency Contact Phone', _emergencyPhoneController, Icons.phone_outlined, 'Enter 10 digit emergency contact phone', isPhone: true)),
          ],
        ),
        const SizedBox(height: 14),
        _buildInputField('Relationship', _emergencyRelationshipController, Icons.people_outline, 'e.g. Spouse, Parent, Sibling'),
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
            Expanded(
              child: _buildInputField(
                'Joining Date *',
                _joiningDateController,
                Icons.calendar_today_outlined,
                'mm/dd/yyyy',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdownField('Department *', _department, _departmentsList, (val) => setState(() => _department = val)),
            ),
          ],
        ),
        const SizedBox(height: 14),
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
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildInputField(
                'Branch From Date',
                _branchFromDateController,
                Icons.calendar_today_outlined,
                'mm/dd/yyyy',
                helperText: 'Effective start date for this branch assignment (defaults to joining date)',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputField(
                'Branch To Date (optional)',
                _branchToDateController,
                Icons.calendar_today_outlined,
                'mm/dd/yyyy',
                helperText: 'Updating the branch will automatically close the previous assignment record',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField('Employment Type *', _employmentType, _employmentTypesList, (val) {
                setState(() => _employmentType = val ?? 'Full-Time');
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdownField('Reporting Manager (TL / Manager)', _reportingManager, _managersList, (val) {
                setState(() => _reportingManager = val);
              }),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField('Team', _team, _teamsList, (val) => setState(() => _team = val)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputField('Work Location', _workLocationController, Icons.location_on_outlined, 'e.g. Office, Remote, Hybrid'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildDropdownField('Shift *', _shift, _shiftsList, (val) => setState(() => _shift = val)),
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
            Expanded(
              child: _buildInputField(
                'Basic Salary *',
                _salaryController,
                Icons.currency_rupee_rounded,
                '0.00',
                isCurrency: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputField(
                'Allowances & Bonuses',
                _allowancesController,
                Icons.monetization_on_outlined,
                '0.00',
                isCurrency: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildInputField(
                'Bank Name',
                _bankNameController,
                Icons.account_balance_outlined,
                'Enter bank name',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputField(
                'Account Number',
                _accountNumberController,
                Icons.credit_card_outlined,
                'Enter account number',
                isNumber: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildInputField(
                'IFSC / Routing Code',
                _ifscController,
                Icons.code_rounded,
                'Enter IFSC code',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputField(
                'Tax ID',
                _taxIdController,
                Icons.receipt_long_rounded,
                'Enter Tax ID',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    IconData icon,
    String hint, {
    bool isEmail = false,
    bool isPhone = false,
    bool isNumber = false,
    bool isCurrency = false,
    String? helperText,
  }) {
    final isDate = label.toLowerCase().contains('date');
    final isTabular = isNumber || isCurrency || isPhone || label.contains('Aadhaar') || label.contains('PAN') || label.contains('Employee ID') || label.contains('Account') || label.contains('IFSC');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label.replaceAll(' *', ''),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (label.contains('*'))
              const Text(' *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.red)),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: isDate ? () => _pickDate(controller) : null,
          child: Container(
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
                Icon(icon, size: 18, color: const Color(0xFF64748B)),
                const SizedBox(width: 10),
                if (isCurrency) ...[
                  const Text('₹ ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                ],
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !_isSaving && !isDate,
                    readOnly: isDate,
                    onTap: isDate ? () => _pickDate(controller) : null,
                    textInputAction: TextInputAction.next,
                    keyboardType: isEmail
                        ? TextInputType.emailAddress
                        : (isPhone || isNumber || isCurrency ? TextInputType.number : TextInputType.text),
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w500,
                      fontFamily: isTabular ? 'monospace' : null,
                      letterSpacing: isTabular ? 0.3 : 0,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w400),
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
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(helperText, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
        ],
      ],
    );
  }

  Widget _buildDropdownField(String label, String? selectedValue, List<String> options, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label.replaceAll(' *', ''),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (label.contains('*'))
              const Text(' *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.red)),
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
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: options.contains(selectedValue) ? selectedValue : (options.isNotEmpty ? options.first : null),
              isExpanded: true,
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0F6B63), size: 20),
              items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
              onChanged: _isSaving ? null : onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF475569),
                minimumSize: const Size(44, 44),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
          Row(
            children: [
              if (_currentStep > 1) ...[
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isSaving ? null : () => setState(() => _currentStep--),
                    child: const Text('Back', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (_currentStep < 4) ...[
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F6B63),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: const Color.fromRGBO(15, 107, 99, 0.22),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      if (_validateCurrentStep()) {
                        setState(() => _currentStep++);
                      }
                    },
                    child: const Text('Next', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ] else ...[
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                    label: Text(_isEdit ? 'Save Changes' : 'Submit Employee', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F6B63),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: const Color.fromRGBO(15, 107, 99, 0.22),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isSaving ? null : _saveEmployee,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
