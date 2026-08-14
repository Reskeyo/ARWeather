import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

/// Widget that displays the device's camera feed as a full-screen background.
///
/// Features robust lifecycle management for instant pause/resume without hanging,
/// and simultaneous permission prompts.
class CameraLayer extends StatefulWidget {
  const CameraLayer({super.key});

  @override
  State<CameraLayer> createState() => _CameraLayerState();
}

class _CameraLayerState extends State<CameraLayer> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _permissionDenied = false;
  String? _errorMessage;
  bool _inProgress = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeoutTimer?.cancel();
    _disposeCamera();
    super.dispose();
  }

  Future<void> _disposeCamera() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {}
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Pause camera and release hardware lock
      if (mounted) {
        setState(() => _isInitialized = false);
      }
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      // Small delay allows the Android Activity window to fully regain focus
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          _initializeAll();
        }
      });
    }
  }

  Future<void> _initializeAll() async {
    if (_inProgress) return;
    _inProgress = true;

    // Safety timeout: reset if hanging longer than 5 seconds
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isInitialized) {
        setState(() {
          _inProgress = false;
          _errorMessage = 'Camera took too long to respond. Tap to retry.';
        });
      }
    });

    try {
      final cameraStatus = await Permission.camera.status;
      final locationStatus = await Permission.locationWhenInUse.status;

      if (!cameraStatus.isGranted || !locationStatus.isGranted) {
        final statuses = await [
          Permission.camera,
          Permission.locationWhenInUse,
        ].request();

        if (statuses[Permission.camera]?.isDenied == true ||
            statuses[Permission.camera]?.isPermanentlyDenied == true) {
          if (mounted) {
            setState(() {
              _permissionDenied = true;
              _inProgress = false;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() => _permissionDenied = false);
      }

      await _setupCameraController();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Camera initialization failed: $e');
      }
    } finally {
      _timeoutTimer?.cancel();
      _inProgress = false;
    }
  }

  Future<void> _setupCameraController() async {
    await _disposeCamera();

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (mounted) setState(() => _errorMessage = 'No camera found on device');
      return;
    }

    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await controller.initialize();

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _controller = controller;
      _isInitialized = true;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return _buildPermissionRequest();
    }

    if (_errorMessage != null) {
      return _buildFallback(_errorMessage!);
    }

    if (!_isInitialized || _controller == null || !_controller!.value.isInitialized) {
      return _buildLoading();
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.previewSize!.height,
          height: _controller!.value.previewSize!.width,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  Widget _buildPermissionRequest() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  size: 48,
                  color: Color(0xFF818CF8),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Camera & Location Access',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'AR Weather needs Camera and Location access to show 3D weather radar elements over your real-world camera view.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () async {
                  final status = await Permission.camera.status;
                  if (status.isPermanentlyDenied) {
                    await openAppSettings();
                  } else {
                    await _initializeAll();
                  }
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Grant Access'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF818CF8),
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 16),
            const Text(
              'Starting AR Camera…',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _initializeAll,
              child: Text(
                'Taking too long? Tap to reload',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback(String error) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_outlined,
                size: 48,
                color: Colors.white.withOpacity(0.4),
              ),
              const SizedBox(height: 12),
              Text(
                error,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _errorMessage = null);
                  _initializeAll();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Restart Camera'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
