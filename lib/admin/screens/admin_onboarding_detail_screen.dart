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
import 'admin_onboarding_form_screen.dart';

class AdminOnboardingDetailScreen extends ConsumerStatefulWidget {
  final String candidateId;

  const AdminOnboardingDetailScreen({super.key, required this.candidateId});

  @override
  ConsumerState<AdminOnboardingDetailScreen> createState() => _AdminOnboardingDetailScreenState();
}

class _AdminOnboardingDetailScreenState extends ConsumerState<AdminOnboardingDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _candidate = {};
  bool _isCompleting = false;

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
    _requestId++; // Immediately invalidate any pending requests
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
    _isCompleting = false;
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
      final res = await apiClient.get(ApiEndpoints.onboardingDetail(widget.candidateId));
      if (!mounted || currentReq != _requestId) return;

      dynamic rawData = res is Map<String, dynamic> && res.containsKey('data') ? res['data'] : res;
      if (rawData is Map<String, dynamic>) {
        setState(() {
          _candidate = rawData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Onboarding candidate not found.';
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
        _errorMessage = 'Failed to load onboarding details. Please check network connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Onboarding?'),
        content: const Text('This will finalize candidate onboarding and convert them to an active employee record.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCompleting = true);
    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.post(ApiEndpoints.onboardingComplete(widget.candidateId));
      if (!mounted || currentReq != _requestId) return;

      setState(() {
        _candidate['status'] = 'COMPLETED';
        _candidate['progress'] = 100;
        _isCompleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Onboarding completed successfully!')),
      );
      _loadCandidateDetail();
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() => _isCompleting = false);
      final msg = e is ApiException ? e.message : 'Failed to complete onboarding.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
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

    final name = _candidate['employeeName']?.toString() ?? _candidate['name']?.toString() ?? 'Candidate';
    final status = (_candidate['status']?.toString() ?? 'NOT_STARTED').toUpperCase();

    return GlassScaffold(
      appBar: GlassHeader(
        title: name,
        actions: [
          if (isAuthorized && _errorMessage == null && !_isLoading) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Onboarding',
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => AdminOnboardingFormScreen(candidateId: widget.candidateId, initialData: _candidate)),
                );
                if (updated == true) _loadCandidateDetail();
              },
            ),
            if (status != 'COMPLETED')
              IconButton(
                icon: _isCompleting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                    : const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
                tooltip: 'Complete Onboarding',
                onPressed: _isCompleting ? null : _completeOnboarding,
              ),
          ],
        ],
      ),
      body: !isAuthorized
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
                      Text('You do not have administrative permissions to view onboarding details.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadCandidateDetail,
              child: _buildMainContent(glass, cardBgColor, name, status),
            ),
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor, String name, String status) {
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
              Text('Unable to Load Onboarding Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadCandidateDetail),
            ],
          ),
        ),
      );
    }

    final progress = (_candidate['progress'] as num?)?.toDouble() ?? 0.0;
    final tasks = (_candidate['tasks'] is List) ? (_candidate['tasks'] as List) : [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header Card
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF0F6B66).withAlpha(30),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'C', style: const TextStyle(fontSize: 22, color: Color(0xFF0F6B66), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                      Text('${_candidate['jobPosition'] ?? 'Position'} • ${_candidate['departmentName'] ?? 'General'}', style: TextStyle(color: glass.textSecondary, fontSize: 12)),
                      Text('Joining Date: ${_candidate['startDate'] ?? '—'}', style: TextStyle(color: glass.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'COMPLETED' ? const Color(0xFF10B981).withAlpha(30) : const Color(0xFFF59E0B).withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: status == 'COMPLETED' ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Progress Section Card
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Onboarding Progress', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                    Text('${progress.toInt()}% Completed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F6B66))),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (progress / 100.0).clamp(0.0, 1.0),
                  backgroundColor: Colors.grey.withAlpha(40),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0F6B66)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Checklist Tasks Card
          AppCard(
            backgroundColor: cardBgColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Onboarding Checklist Tasks (${tasks.length})', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                const Divider(height: 16),
                if (tasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('No checklist tasks assigned.', style: TextStyle(fontSize: 13, color: glass.textSecondary))),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final isDone = task['isCompleted'] == true || task['done'] == true;
                      final taskId = task['id']?.toString();

                      return CheckboxListTile(
                        title: Text(
                          task['title']?.toString() ?? task['label']?.toString() ?? 'Task',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: glass.textPrimary,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        value: isDone,
                        activeColor: const Color(0xFF0F6B66),
                        onChanged: taskId == null ? null : (val) async {
                          setState(() {
                            task['isCompleted'] = val;
                          });
                          try {
                            await ref.read(apiClientProvider).put(ApiEndpoints.onboardingTask(taskId), body: {'isCompleted': val});
                          } catch (e) {
                            // Rollback optimization on failure
                            setState(() {
                              task['isCompleted'] = !val!;
                            });
                          }
                        },
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
}
