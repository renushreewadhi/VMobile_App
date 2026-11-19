import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  CameraController? _cameraController;
  bool _isCameraInitializing = true;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      CameraDescription? frontCamera;
      for (final cam in cameras) {
        if (cam.lensDirection == CameraLensDirection.front) {
          frontCamera = cam;
          break;
        }
      }
      frontCamera ??= cameras.isNotEmpty ? cameras.first : null;

      if (frontCamera == null) {
        if (mounted) {
          setState(() {
            _isCameraInitializing = false;
            _cameraError = 'No camera available';
          });
        }
        return;
      }

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCameraInitializing = false;
        _cameraError = 'Camera initialization failed: $e';
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureSelfie() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;
    try {
      setState(() => _isCameraInitializing = true);
      final xFile = await _cameraController!.takePicture();
      final bytes = await xFile.readAsBytes();
      final base64Str = base64Encode(bytes);

      ref
          .read(punchControllerProvider.notifier)
          .setCapturedSelfie(xFile, base64Str);
      if (mounted) setState(() => _isCameraInitializing = false);
    } catch (e) {
      if (mounted) setState(() => _isCameraInitializing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture photo: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _retakeSelfie() {
    ref.read(punchControllerProvider.notifier).clearSelfie();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(punchControllerProvider);

    final bodyContent = SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  avatar: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 16,
                  ),
                  label: Text(
                    state.workMode == 'OFFICE'
                        ? 'Inside office area'
                        : 'Work from home',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: Colors.white.withOpacity(0.1),
                ),
                Chip(
                  avatar: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 16,
                  ),
                  label: const Text(
                    'Selfie required',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.white.withOpacity(0.1),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: ClipOval(
                child: Container(
                  width: 200,
                  height: 270,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    border: Border.all(
                      color: state.capturedSelfie != null
                          ? AppColors.success
                          : AppColors.primary,
                      width: 3.5,
                    ),
                  ),
                  child: _isCameraInitializing
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text(
                              'Opening front camera...',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : _cameraError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _cameraError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      : state.capturedSelfie != null
                      ? Image.file(
                          File(state.capturedSelfie!.path),
                          fit: BoxFit.cover,
                        )
                      : (_cameraController != null &&
                            _cameraController!.value.isInitialized)
                      ? AspectRatio(
                          aspectRatio: _cameraController!.value.aspectRatio,
                          child: CameraPreview(_cameraController!),
                        )
                      : const Center(
                          child: Text(
                            'Camera preview unavailable',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Look straight at the camera',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Keep your face inside the outline in good light. Your selfie is saved with this punch.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: state.capturedSelfie != null
                      ? _retakeSelfie
                      : _captureSelfie,
                  icon: Icon(
                    state.capturedSelfie != null
                        ? Icons.refresh_rounded
                        : Icons.camera_alt_rounded,
                    size: 26,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    padding: const EdgeInsets.all(14),
                  ),
                  tooltip: state.capturedSelfie != null
                      ? 'Retake Selfie'
                      : 'Capture Selfie',
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed:
                      state.capturedSelfieBase64 == null ||
                          state.isActionInProgress
                      ? null
                      : () async {
                          final controller = ref.read(
                            punchControllerProvider.notifier,
                          );
                          final success = await controller.clockIn(
                            workMode: state.workMode,
                            wfhReason: state.wfhReason,
                            selfieBase64: state.capturedSelfieBase64,
                            isGallery: false,
                          );
                          if (success && mounted) {
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ClockInSuccessScreen(),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: state.isActionInProgress
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Use photo & Clock in',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (!widget.showAppBar)
      return Material(color: Colors.transparent, child: bodyContent);

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
