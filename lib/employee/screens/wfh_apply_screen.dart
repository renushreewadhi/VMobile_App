import '../../core/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_text_field.dart';

class WfhApplyScreen extends ConsumerStatefulWidget {
  const WfhApplyScreen({super.key});

  @override
  ConsumerState<WfhApplyScreen> createState() => _WfhApplyScreenState();
}

class _WfhApplyScreenState extends ConsumerState<WfhApplyScreen> {
  final _reasonController = TextEditingController();
  final _dateController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitWfh() async {
    if (_dateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter target date'), backgroundColor: AppColors.warning),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post('/attendance/correction-request', body: {
        'type': 'WFH',
        'date': _dateController.text.trim(),
        'reason': _reasonController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WFH request submitted successfully!'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Work From Home (WFH) Application')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Request WFH Day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Date (YYYY-MM-DD)',
                hint: '2026-10-25',
                controller: _dateController,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Reason',
                hint: 'Reason for working from home...',
                controller: _reasonController,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Submit WFH Request',
                isLoading: _isSubmitting,
                onPressed: _submitWfh,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
