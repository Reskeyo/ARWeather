import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

/// Widget that displays the device's camera feed as a full-screen background.
///
/// Prompts for Camera & Location permissions simultaneously and handles
/// seamless app pause/resume lifecycle transitions without hanging.
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
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionsAndStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _isInitialized = false;
      controller?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _checkPermissionsAndStart();
    }
  }

  /// Requests Camera and Location permissions simultaneously.
  Future<void> _checkPermissionsAndStart() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      final cameraGranted = await Permission.camera.isGranted;
      final locationGranted = await Permission.locationWhenInUse.isGranted;

      if (!cameraGranted || !locationGranted) {
        // Batch request both permissions at the same time
        final statuses = await [
          Permission.camera,
          Permission.locationWhenInUse,
        ].request();

        if (statuses[Permission.camera]?.isDenied == true ||
            statuses[Permission.camera]?.isPermanentlyDenied == true) {
          if (mounted) {
            setState(() {
              _permissionDenied = true;
              _isInitializing = false;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() => _permissionDenied = false);
      }

      await _initCamera();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Camera setup error: $e');
      }
    } finally {
      _isInitializing = false;
    }
  }

  /// Initializes the camera controller with the back camera.
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _errorMessage = 'No camera device found');
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
      );

      _controller = controller;
      await controller.initialize();

      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _errorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Camera initialization failed: $e');
      }
    }
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
                    await _checkPermissionsAndStart();
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
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF818CF8),
              strokeWidth: 2.5,
            ),
            SizedBox(height: 16),
            Text(
              'Starting AR Camera…',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
                fontWeight: FontWeight.w500,
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
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _checkPermissionsAndStart,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry Camera'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
