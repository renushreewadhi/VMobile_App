import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/glass_header.dart';
import '../../../core/widgets/glass_scaffold.dart';

class HrOnboardingAddScreen extends ConsumerStatefulWidget {
  const HrOnboardingAddScreen({super.key});

  @override
  ConsumerState<HrOnboardingAddScreen> createState() => _HrOnboardingAddScreenState();
}

class _HrOnboardingAddScreenState extends ConsumerState<HrOnboardingAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _refCodeController = TextEditingController(text: 'JOB-102');
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _probationController = TextEditingController(text: '3');
  final TextEditingController _noticeController = TextEditingController(text: '30');
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _mentorController = TextEditingController();

  String _department = 'Engineering';
  String _designation = 'Developer';
  String _branch = 'Pune Office';
  String _manager = 'Praveen Singh';
  String _employmentType = 'Full Time';
  String _employeeType = 'Probation';
  DateTime _joiningDate = DateTime.now();

  bool _offerLetterProvided = false;
  bool _offerAccepted = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _positionController.dispose();
    _refCodeController.dispose();
    _salaryController.dispose();
    _probationController.dispose();
    _noticeController.dispose();
    _locationController.dispose();
    _mentorController.dispose();
    super.dispose();
  }

  Future<void> _saveOnboarding() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'employeeName': _nameController.text.trim(),
      'position': _positionController.text.trim(),
      'jobReferenceCode': _refCodeController.text.trim(),
      'department': _department,
      'designation': _designation,
      'branch': _branch,
      'reportingManager': _manager,
      'mentorName': _mentorController.text.trim(),
      'startDate': DateFormat('yyyy-MM-dd').format(_joiningDate),
      'employmentType': _employmentType,
      'employeeType': _employeeType,
      'salary': _salaryController.text.trim(),
      'probationMonths': int.tryParse(_probationController.text.trim()) ?? 3,
      'noticeDays': int.tryParse(_noticeController.text.trim()) ?? 30,
      'workLocation': _locationController.text.trim(),
      'offerLetterProvided': _offerLetterProvided,
      'offerAccepted': _offerAccepted,
      'status': 'In Progress',
      'progress': 25,
    };

    try {
      await apiClient.post('/onboarding', body: payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Onboarding candidate added successfully')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        final msg = e is ApiException ? e.message : 'Failed to add candidate.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      appBar: GlassHeader(title: 'Add Onboarding Candidate'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Candidate & Job Details
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.person_add_rounded, color: Color(0xFFD97706), size: 20),
                        SizedBox(width: 8),
                        Text('1. Candidate & Job Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Move a candidate into onboarding with full employment, offer & joining details', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const Divider(height: 16),

                    const Text('Candidate / Employee Name *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      enabled: !_isSaving,
                      decoration: InputDecoration(
                        hintText: 'e.g. Alice Cooper',
                        filled: true,
                        fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Job Position / Role *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _positionController,
                                enabled: !_isSaving,
                                decoration: InputDecoration(
                                  hintText: 'e.g. Senior Frontend Developer',
                                  filled: true,
                                  fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Job Reference Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _refCodeController,
                                enabled: !_isSaving,
                                decoration: InputDecoration(
                                  hintText: 'e.g. JOB-102',
                                  filled: true,
                                  fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Department', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _department,
                                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC)),
                                items: ['Engineering', 'Marketing', 'Sales', 'Design', 'Finance', 'Human Resources']
                                    .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: _isSaving ? null : (val) => setState(() => _department = val ?? 'Engineering'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Designation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _designation,
                                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC)),
                                items: ['Developer', 'Team Lead', 'Manager', 'Analyst', 'HR']
                                    .map((ds) => DropdownMenuItem(value: ds, child: Text(ds, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: _isSaving ? null : (val) => setState(() => _designation = val ?? 'Developer'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Branch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _branch,
                                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC)),
                                items: ['Pune Office', 'Head Office', 'Adajan Surat']
                                    .map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: _isSaving ? null : (val) => setState(() => _branch = val ?? 'Pune Office'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Reporting Manager', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _manager,
                                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC)),
                                items: ['Praveen Singh', 'Ajay Raja', 'HR Manager']
                                    .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: _isSaving ? null : (val) => setState(() => _manager = val ?? 'Praveen Singh'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Assigned Mentor', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _mentorController.text.isNotEmpty ? _mentorController.text : 'Praveen Singh',
                                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC)),
                                items: ['Praveen Singh', 'Ajay Raja', 'Mansi Borase']
                                    .map((mt) => DropdownMenuItem(value: mt, child: Text(mt, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: _isSaving ? null : (val) => setState(() => _mentorController.text = val ?? 'Praveen Singh'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Joining Date *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: _isSaving ? null : () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _joiningDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) setState(() => _joiningDate = picked);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                    borderRadius: BorderRadius.circular(12),
                                    color: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(DateFormat('dd/MM/yyyy').format(_joiningDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                      const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Employment Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _employmentType,
                                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC)),
                                items: ['Full Time', 'Part Time', 'Contract']
                                    .map((et) => DropdownMenuItem(value: et, child: Text(et, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: _isSaving ? null : (val) => setState(() => _employmentType = val ?? 'Full Time'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Employee Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _employeeType,
                                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC)),
                                items: ['Probation', 'Permanent', 'Intern']
                                    .map((ept) => DropdownMenuItem(value: ept, child: Text(ept, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: _isSaving ? null : (val) => setState(() => _employeeType = val ?? 'Probation'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section 2: Offer & Joining
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.description_rounded, color: Color(0xFFD97706), size: 20),
                        SizedBox(width: 8),
                        Text('2. Offer & Joining', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Salary package, probation, and contract terms', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const Divider(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Offer Salary / CTC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _salaryController,
                                enabled: !_isSaving,
                                decoration: InputDecoration(
                                  hintText: 'e.g. ₹ 12,00,000 / annum',
                                  filled: true,
                                  fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Probation Period (months)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _probationController,
                                enabled: !_isSaving,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Notice Period (days)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _noticeController,
                                enabled: !_isSaving,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Work Location', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _locationController,
                                enabled: !_isSaving,
                                decoration: InputDecoration(
                                  hintText: 'e.g. Pune / Remote',
                                  filled: true,
                                  fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    CheckboxListTile(
                      title: const Text('Offer Letter Provided', style: TextStyle(fontSize: 12.5)),
                      value: _offerLetterProvided,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      onChanged: _isSaving ? null : (val) => setState(() => _offerLetterProvided = val ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text('Offer Accepted', style: TextStyle(fontSize: 12.5)),
                      value: _offerAccepted,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      onChanged: _isSaving ? null : (val) => setState(() => _offerAccepted = val ?? false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Bottom Action Bar
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
                        onPressed: _isSaving ? null : _saveOnboarding,
                        icon: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check, size: 18),
                        label: const Text('Save Onboarding', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
    );
  }
}
