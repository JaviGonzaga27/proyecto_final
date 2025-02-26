import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/parking_service.dart';

class ScanPlateScreen extends StatefulWidget {
  const ScanPlateScreen({Key? key}) : super(key: key);

  @override
  _ScanPlateScreenState createState() => _ScanPlateScreenState();
}

class _ScanPlateScreenState extends State<ScanPlateScreen> {
  bool _isInitialized = false;
  bool _isProcessing = false;
  CameraController? _cameraController;
  final textRecognizer = TextRecognizer();
  String _scannedText = '';
  String? _detectedPlate;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    textRecognizer.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _scannedText = '';
      _detectedPlate = null;
    });

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      final text = recognizedText.text;

      setState(() {
        _scannedText = text;
        // Intentar detectar un patrón de placa
        _detectedPlate = _extractPlateNumber(text);
      });
    } catch (e) {
      print('Error processing image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String? _extractPlateNumber(String text) {
    // Este es un ejemplo simple de detección de placa
    // Ajusta el regex según el formato de placas de tu país
    final RegExp platePattern = RegExp(r'[A-Z]{3}[-\s]?\d{3,4}');
    final match = platePattern.firstMatch(text);
    return match?.group(0);
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final XFile photo = await _cameraController!.takePicture();

      setState(() {
        _imageFile = File(photo.path);
      });

      final inputImage = InputImage.fromFile(_imageFile!);
      await _processImage(inputImage);
    } catch (e) {
      print('Error taking picture: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) return;

      setState(() {
        _imageFile = File(pickedFile.path);
      });

      final inputImage = InputImage.fromFile(_imageFile!);
      await _processImage(inputImage);
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _registerPlate() async {
    if (_detectedPlate == null) return;

    final parkingService = ParkingService();
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Registrando placa...'),
              ],
            ),
          ),
    );

    try {
      // En un caso real, aquí enviarías la placa al backend
      await Future.delayed(const Duration(seconds: 2)); // Simulación

      // Cerrar diálogo de carga
      Navigator.of(context).pop();

      // Mostrar resultado
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Placa registrada'),
              content: Text(
                'La placa $_detectedPlate ha sido registrada correctamente.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Aceptar'),
                ),
              ],
            ),
      );
    } catch (e) {
      // Cerrar diálogo de carga
      Navigator.of(context).pop();

      // Mostrar error
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Error'),
              content: Text('No se pudo registrar la placa: ${e.toString()}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Aceptar'),
                ),
              ],
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear placa')),
      body: Column(
        children: [Expanded(child: _buildCameraPreview()), _buildBottomPanel()],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_imageFile != null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Image.file(
            _imageFile!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    }

    return CameraPreview(_cameraController!);
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_detectedPlate != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryColor),
              ),
              child: Column(
                children: [
                  const Text(
                    'Placa detectada',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _detectedPlate!,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _registerPlate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                    ),
                    child: const Text('Registrar placa'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else if (_scannedText.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: const Column(
                children: [
                  Text(
                    'No se detectó ninguna placa',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Intenta tomar otra foto o seleccionar una imagen diferente',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _imageFile != null ? _initializeCamera : _takePicture,
                  icon: Icon(
                    _imageFile != null ? Icons.refresh : Icons.camera_alt,
                  ),
                  label: Text(_imageFile != null ? 'Nueva foto' : 'Tomar foto'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galería'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
