import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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

class AdminCandidateDetailScreen extends ConsumerStatefulWidget {
  final String candidateId;
  final bool showAppBar;

  const AdminCandidateDetailScreen({super.key, required this.candidateId, this.showAppBar = true});

  @override
  ConsumerState<AdminCandidateDetailScreen> createState() => _AdminCandidateDetailScreenState();
}

class _AdminCandidateDetailScreenState extends ConsumerState<AdminCandidateDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _candidate = {};
  final TextEditingController _newNoteController = TextEditingController();
  bool _isAddingNote = false;

  int _requestId = 0;
  String? _currentUserId;

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
    _requestId++; // Immediately invalidate any in-flight requests
    final authState = ref.read(authServiceProvider);
    final user = authState.user;

    if (user == null || !authState.isAuthenticated) {
      if (!mounted) return;
      _resetState();
      setState(() {
        _isLoading = false;
        _errorMessage = 'No authenticated user found.';
      });
      return;
    }

    if (_currentUserId != user.id) {
      _currentUserId = user.id;
      _resetState();
    }

    final userRole = user.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    if (!isAuthorized) {
      if (!mounted) return;
      _resetState();
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    _loadCandidateDetail();
  }

  void _resetState() {
    _candidate = {};
    _newNoteController.clear();
    _isAddingNote = false;
  }

  Future<void> _loadCandidateDetail() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get(ApiEndpoints.candidateDetail(widget.candidateId));
      if (!mounted || currentReq != _requestId) return;

      dynamic rawData = res is Map<String, dynamic> && res.containsKey('data') ? res['data'] : res;
      if (rawData is Map<String, dynamic>) {
        setState(() {
          _candidate = rawData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Candidate record not found.';
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _errorMessage = 'Failed to load candidate profile. Please check network connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _addNote() async {
    final text = _newNoteController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter note text.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isAddingNote = true);
    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post('${ApiEndpoints.candidateDetail(widget.candidateId)}/notes', body: {
        'text': text,
        'author': 'HR Admin',
      });

      if (!mounted || currentReq != _requestId) return;

      _newNoteController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evaluation note added successfully!')),
      );
      _loadCandidateDetail();
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      final msg = e is ApiException ? e.message : 'Failed to add evaluation note.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isAddingNote = false);
    }
  }

  Future<void> _downloadResume() async {
    final resumeUrl = _candidate['resumeUrl']?.toString();
    if (resumeUrl == null || resumeUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No resume attachment available for this candidate.'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final uri = Uri.parse(resumeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $resumeUrl';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download resume: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDate(String? d) {
    if (d == null || d.trim().isEmpty) return '—';
    try {
      final dt = DateTime.parse(d).toLocal();
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return d;
    }
  }

  int _getPipelineStepIndex(String status) {
    final s = status.toUpperCase();
    if (s == 'NEW' || s == 'APPLIED') return 0;
    if (s == 'SHORTLISTED' || s == 'SCREENING') return 1;
    if (s == 'INTERVIEW_SCHEDULED' || s == 'INTERVIEWED') return 2;
    if (s == 'OFFER_EXTENDED' || s == 'OFFERED') return 3;
    if (s == 'HIRED') return 4;
    return 0; // Default to step 0
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    // Account switching listener
    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    final authState = ref.watch(authServiceProvider);
    final userRole = authState.user?.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    final firstName = _candidate['firstName']?.toString() ?? '';
    final lastName = _candidate['lastName']?.toString() ?? '';
    final fullName = firstName.isNotEmpty || lastName.isNotEmpty ? '$firstName $lastName'.trim() : (_candidate['name']?.toString() ?? 'Candidate');

    final status = (_candidate['status']?.toString() ?? 'NEW').toUpperCase();
    final pipelineIdx = _getPipelineStepIndex(status);

    final bodyContent = !isAuthorized
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: AppCard(
                  backgroundColor: cardBgColor,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 48, color: Color(0xFFEF4444)),
                      const SizedBox(height: 16),
                      Text('Access Restricted', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      const SizedBox(height: 8),
                      Text('You do not have administrative permissions to view candidate details.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadCandidateDetail,
              child: _buildMainContent(glass, cardBgColor, fullName, status, pipelineIdx),
            );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: bodyContent);

    return GlassScaffold(
      appBar: GlassHeader(
        title: fullName,
        actions: [
          if (isAuthorized && _errorMessage == null && !_isLoading) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Candidate',
              onPressed: () {
                // Navigate to Edit candidate
              },
            ),
          ],
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor, String fullName, String status, int pipelineIdx) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text('Unable to Load Candidate Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadCandidateDetail),
            ],
          ),
        ),
      );
    }

    final notes = _candidate['notesList'] as List? ?? [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Hero Banner Card
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF0F6B66).withAlpha(30),
                  child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : 'C', style: const TextStyle(fontSize: 22, color: Color(0xFF0F6B66), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fullName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      Text('${_candidate['jobTitle'] ?? _candidate['position'] ?? 'Position'} • ${_candidate['departmentName'] ?? _candidate['department'] ?? 'General'}', style: TextStyle(color: glass.textSecondary, fontSize: 12)),
                      Text('Applied: ${_formatDate(_candidate['createdAt']?.toString())}', style: TextStyle(color: glass.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'HIRED' ? const Color(0xFF10B981).withAlpha(30) : (status == 'REJECTED' ? const Color(0xFFEF4444).withAlpha(30) : const Color(0xFF2563EB).withAlpha(30)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: status == 'HIRED' ? const Color(0xFF10B981) : (status == 'REJECTED' ? const Color(0xFFEF4444) : const Color(0xFF2563EB))),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Recruitment Pipeline Tracker Card
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recruitment Pipeline Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPipelineStep('1. Applied', pipelineIdx >= 0),
                      _buildPipelineStep('2. Shortlisted', pipelineIdx >= 1),
                      _buildPipelineStep('3. Interview', pipelineIdx >= 2),
                      _buildPipelineStep('4. Offer', pipelineIdx >= 3),
                      _buildPipelineStep('5. Hired', pipelineIdx >= 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Contact & Applicant Details
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Contact & Applicant Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                const Divider(height: 16),
                _buildInfoRow(glass, 'Email Address', _candidate['email']?.toString() ?? '—'),
                _buildInfoRow(glass, 'Phone Number', _candidate['phone']?.toString() ?? '—'),
                _buildInfoRow(glass, 'Years of Experience', _candidate['experience']?.toString() ?? '—'),
                _buildInfoRow(glass, 'Notice Period', _candidate['noticePeriod']?.toString() ?? '—'),
                _buildInfoRow(glass, 'Expected Salary', _candidate['salaryExpectation']?.toString() ?? '—'),
                _buildInfoRow(glass, 'Location', _candidate['location']?.toString() ?? '—'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Resume & Attachments
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_candidate['resumeUrl'] != null ? 'Resume_Document.pdf' : 'No Resume Attached', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: glass.textPrimary)),
                      Text('PDF File Attachment', style: TextStyle(fontSize: 11, color: glass.textSecondary)),
                    ],
                  ),
                ),
                if (_candidate['resumeUrl'] != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Download', style: TextStyle(fontSize: 12)),
                    onPressed: _downloadResume,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Recruiter Notes & Evaluation History
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recruiter Notes & Evaluation History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                const SizedBox(height: 12),
                TextField(
                  controller: _newNoteController,
                  enabled: !_isAddingNote,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Type interview evaluation or screening notes...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
                    label: 'Add Note',
                    width: 120,
                    isLoading: _isAddingNote,
                    onPressed: _isAddingNote ? null : _addNote,
                  ),
                ),
                const Divider(height: 20),
                notes.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: Text('No evaluation notes added yet.', style: TextStyle(fontSize: 12, color: glass.textSecondary))),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: notes.length,
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(note['author']?.toString() ?? 'Recruiter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: glass.textPrimary)),
                                Text(note['text']?.toString() ?? '', style: TextStyle(fontSize: 12, color: glass.textSecondary)),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineStep(String label, bool isReached) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isReached ? const Color(0xFF0F6B66).withAlpha(30) : Colors.grey.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isReached ? const Color(0xFF0F6B66) : Colors.grey),
        ),
      ),
    );
  }

  Widget _buildInfoRow(GlassTheme glass, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: glass.textSecondary)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glass.textPrimary)),
        ],
      ),
    );
  }
}
