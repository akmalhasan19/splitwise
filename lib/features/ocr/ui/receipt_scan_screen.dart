/// Layar kamera untuk scan struk — Phase 5, Fitur A, Task A4.
///
/// Alur:
/// 1. Buka kamera (kamera belakang default)
/// 2. User arahkan ke struk → tap tombol capture
/// 3. Proses OCR on-device → tampilkan layar review
///
/// Mendukung juga pilih foto dari galeri via `image_picker`.
library;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:debt_splitter/features/ocr/receipt_candidate_item.dart';
import 'package:debt_splitter/features/ocr/receipt_ocr_engine.dart';
import 'package:debt_splitter/features/ocr/receipt_parse_result.dart';
import 'package:debt_splitter/features/ocr/ui/receipt_review_sheet.dart';

class ReceiptScanScreen extends StatefulWidget {
  const ReceiptScanScreen({super.key});

  @override
  State<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends State<ReceiptScanScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String? _error;
  final ReceiptOcrEngine _ocrEngine = ReceiptOcrEngine();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'Tidak ada kamera yang tersedia.');
        return;
      }
      // Pilih kamera belakang
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal inisialisasi kamera: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _ocrEngine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Struk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            tooltip: 'Pilih dari galeri',
            onPressed: _isProcessing ? null : _pickFromGallery,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _ErrorView(
        message: _error!,
        onRetry: () {
          setState(() {
            _error = null;
            _isCameraInitialized = false;
          });
          _initCamera();
        },
      );
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              CameraPreview(_cameraController!),
              if (_isProcessing)
                Container(
                  color: Colors.black54,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        'Memproses struk…',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              // Panduan framing
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white70,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: AspectRatio(
                    aspectRatio: 0.7,
                    child: Container(),
                  ),
                ),
              ),
            ],
          ),
        ),
        _CaptureBar(
          isProcessing: _isProcessing,
          onCapture: _capturePhoto,
          onGallery: _pickFromGallery,
        ),
      ],
    );
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || _isProcessing) return;
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final xFile = await _cameraController!.takePicture();
      await _processImage(xFile.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = 'Gagal mengambil foto: $e';
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;
    try {
      final xFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (xFile == null) return; // user batal

      setState(() {
        _isProcessing = true;
        _error = null;
      });
      await _processImage(xFile.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = 'Gagal memilih foto: $e';
        });
      }
    }
  }

  Future<void> _processImage(String filePath) async {
    try {
      final result = await _ocrEngine.scanReceipt(filePath);
      if (!mounted) return;

      setState(() => _isProcessing = false);

      // Tampilkan layar review dan kembalikan item yang dipilih
      final items = await _showReviewSheet(result);
      if (items != null && mounted) {
        Navigator.of(context).pop<List<ReceiptCandidateItem>>(items);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = 'Gagal memproses OCR: $e';
        });
      }
    }
  }

  Future<List<ReceiptCandidateItem>?> _showReviewSheet(
    ReceiptParseResult result,
  ) async {
    final items = await showModalBottomSheet<List<ReceiptCandidateItem>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ReceiptReviewSheet(result: result),
    );
    return items;
  }
}

class _CaptureBar extends StatelessWidget {
  const _CaptureBar({
    required this.isProcessing,
    required this.onCapture,
    required this.onGallery,
  });

  final bool isProcessing;
  final VoidCallback onCapture;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton.filled(
            onPressed: isProcessing ? null : onGallery,
            icon: const Icon(Icons.photo_library),
            tooltip: 'Galeri',
          ),
          // Tombol capture besar
          GestureDetector(
            onTap: isProcessing ? null : onCapture,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 4,
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isProcessing
                      ? Colors.grey
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          // Placeholder untuk keseimbangan
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
