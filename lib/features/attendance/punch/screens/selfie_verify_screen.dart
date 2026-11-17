import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_scaffold.dart';
import '../../../../core/widgets/glass_header.dart';
import '../punch_controller.dart';
import 'clock_in_success_screen.dart';

class SelfieVerifyScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const SelfieVerifyScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<SelfieVerifyScreen> createState() => _SelfieVerifyScreenState();
}

class _SelfieVerifyScreenState extends ConsumerState<SelfieVerifyScreen> {
  bool _isCameraLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(punchControllerProvider).capturedSelfie == null) {
        _takeSelfie(ImageSource.camera);
      }
    });
  }

  Future<void> _takeSelfie(ImageSource source) async {
    setState(() => _isCameraLoading = true);
    final controller = ref.read(punchControllerProvider.notifier);
    await controller.takeSelfie(source);
    if (mounted) setState(() => _isCameraLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(punchControllerProvider);

    final bodyContent = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                  label: Text(
                    state.workMode == 'OFFICE' ? 'Inside office area' : 'Work from home',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.white.withOpacity(0.1),
                ),
                Chip(
                  avatar: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                  label: const Text(
                    'Selfie required',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.white.withOpacity(0.1),
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: ClipOval(
                child: Container(
                  width: 240,
                  height: 320,
                  color: Colors.black45,
                  child: _isCameraLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : state.capturedSelfie != null
                          ? Image.file(File(state.capturedSelfie!.path), fit: BoxFit.cover)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 80, color: Colors.white70),
                                const SizedBox(height: 12),
                                Text(
                                  'Position face in oval',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Look straight at the camera',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Keep your face inside the outline in good light. Your selfie is saved with this punch.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _takeSelfie(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 28),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    padding: const EdgeInsets.all(16),
                  ),
                  tooltip: 'Take Selfie',
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: state.capturedSelfieBase64 == null || state.isActionInProgress
                      ? null
                      : () async {
                          final controller = ref.read(punchControllerProvider.notifier);
                          final success = await controller.clockIn(
                            workMode: state.workMode,
                            wfhReason: state.wfhReason,
                            selfieBase64: state.capturedSelfieBase64,
                            isGallery: state.isGalleryUpload,
                          );
                          if (success && mounted) {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ClockInSuccessScreen()),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: state.isActionInProgress
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Use photo & Clock in', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(width: 20),
                IconButton(
                  onPressed: () => _takeSelfie(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 28),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    padding: const EdgeInsets.all(16),
                  ),
                  tooltip: 'Upload from Gallery',
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: bodyContent);

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Verify it\'s you',
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            ref.read(punchControllerProvider.notifier).clearSelfie();
            Navigator.pop(context);
          },
        ),
      ),
      body: bodyContent,
    );
  }
}
