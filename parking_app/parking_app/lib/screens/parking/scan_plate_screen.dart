import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/parking_service.dart';
import 'package:flutter/services.dart';

class ScanPlateScreen extends StatefulWidget {
  final String? spotId; // Opcional: ID del espacio si viene de reserva

  const ScanPlateScreen({Key? key, this.spotId}) : super(key: key);

  @override
  _ScanPlateScreenState createState() => _ScanPlateScreenState();
}

class _ScanPlateScreenState extends State<ScanPlateScreen>
    with WidgetsBindingObserver {
  bool _isInitialized = false;
  bool _isProcessing = false;
  CameraController? _cameraController;
  final textRecognizer = TextRecognizer();
  String _scannedText = '';
  String? _detectedPlate;
  File? _imageFile;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentZoom = 1.0;
  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _currentExposureOffset = 0.0;
  FlashMode _flashMode = FlashMode.auto;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    textRecognizer.close();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _isInitialized = false;
        });
        return;
      }

      _initCameraController(_cameras![_selectedCameraIndex]);
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _initCameraController(
    CameraDescription cameraDescription,
  ) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();

      // Forzar orientación vertical
      await _cameraController!.lockCaptureOrientation(
        DeviceOrientation.portraitUp,
      );

      // Configurar zoom y flash
      _minAvailableZoom = await _cameraController!.getMinZoomLevel();
      _maxAvailableZoom = await _cameraController!.getMaxZoomLevel();
      _currentZoom = 1.0;
      await _cameraController!.setZoomLevel(_currentZoom);
      await _cameraController!.setFlashMode(_flashMode);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing camera controller: $e');
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
      // Enfocar primero para obtener una imagen nítida
      await _cameraController!.setFocusMode(FocusMode.auto);
      await Future.delayed(const Duration(milliseconds: 300));

      // Asegurarse de que la orientación de captura esté bloqueada en modo vertical
      await _cameraController!.lockCaptureOrientation(
        DeviceOrientation.portraitUp,
      );

      final XFile photo = await _cameraController!.takePicture();

      setState(() {
        _imageFile = File(photo.path);
      });

      final inputImage = InputImage.fromFilePath(photo.path);
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
        imageQuality: 100, // Máxima calidad
      );

      if (pickedFile == null) return;

      setState(() {
        _imageFile = File(pickedFile.path);
      });

      final inputImage = InputImage.fromFilePath(pickedFile.path);
      await _processImage(inputImage);
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _registerPlate() async {
    if (_detectedPlate == null || _imageFile == null) return;

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
      bool success;

      // Si hay un spotId, registrar entrada para ese espacio
      if (widget.spotId != null) {
        success = await parkingService.registerEntry(
          widget.spotId!,
          _detectedPlate!,
          plateImage: _imageFile,
        );
      } else {
        // De lo contrario, solo registrar la placa para futuro uso
        success = await parkingService.addVehicle(
          _detectedPlate!,
          "Vehículo", // Valor por defecto
          "Desconocido", // Valor por defecto
          "Sin color", // Valor por defecto
        );
      }

      // Cerrar diálogo de carga
      Navigator.of(context).pop();

      // Mostrar resultado
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(
                widget.spotId != null
                    ? 'Entrada registrada'
                    : 'Placa registrada',
              ),
              content: Text(
                widget.spotId != null
                    ? 'La placa $_detectedPlate ha sido registrada y se ha registrado la entrada al parqueadero.'
                    : 'La placa $_detectedPlate ha sido registrada correctamente.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (widget.spotId != null) {
                      // Regresar a la pantalla anterior con resultado positivo
                      Navigator.of(context).pop(true);
                    }
                  },
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

  Future<void> _toggleCameraDirection() async {
    if (_cameras == null || _cameras!.length < 2) return;

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    await _initCameraController(_cameras![_selectedCameraIndex]);
  }

  Future<void> _setZoom(double zoom) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      await _cameraController!.setZoomLevel(zoom);
      setState(() {
        _currentZoom = zoom;
      });
    } catch (e) {
      print('Error setting zoom: $e');
    }
  }

  Future<void> _setExposure(double exposure) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      await _cameraController!.setExposureOffset(exposure);
      setState(() {
        _currentExposureOffset = exposure;
      });
    } catch (e) {
      print('Error setting exposure: $e');
    }
  }

  Future<void> _toggleFlashMode() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      FlashMode newMode;
      switch (_flashMode) {
        case FlashMode.auto:
          newMode = FlashMode.always;
          break;
        case FlashMode.always:
          newMode = FlashMode.off;
          break;
        case FlashMode.off:
          newMode = FlashMode.torch;
          break;
        case FlashMode.torch:
          newMode = FlashMode.auto;
          break;
      }

      await _cameraController!.setFlashMode(newMode);
      setState(() {
        _flashMode = newMode;
      });
    } catch (e) {
      print('Error toggling flash: $e');
    }
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.torch:
        return Icons.highlight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear placa'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [Expanded(child: _buildCameraPreview()), _buildBottomPanel()],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_imageFile != null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Image.file(
            _imageFile!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                setState(() {
                  _imageFile = null;
                  _scannedText = '';
                  _detectedPlate = null;
                });
              },
            ),
          ),
        ],
      );
    }

    // Usar un enfoque más simple para mostrar la cámara
    return GestureDetector(
      onTapDown: (details) {
        if (_cameraController == null) return;

        // Calcular punto de enfoque
        final size = MediaQuery.of(context).size;

        // Importante: invertir las coordenadas x e y para corregir la orientación
        // Esto es porque la cámara está en modo landscape internamente, aunque se muestre en portrait
        final double xp = details.localPosition.dy / size.height;
        final double yp = 1.0 - (details.localPosition.dx / size.width);

        // Establecer punto de enfoque con coordenadas corregidas
        if (xp >= 0 && xp <= 1 && yp >= 0 && yp <= 1) {
          _cameraController!.setFocusPoint(Offset(xp, yp));
          _cameraController!.setExposurePoint(Offset(xp, yp));
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Solución simple: usar Container con CameraPreview
          Container(
            color: Colors.black,
            child: Center(
              child: SizedBox(
                width: double.infinity,
                child: AspectRatio(
                  aspectRatio: 1 / _cameraController!.value.aspectRatio,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
          ),

          // Guía de alineación para la placa
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              height: MediaQuery.of(context).size.width * 0.2,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Alinee la placa aquí',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),

          // Controles de cámara
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                // Botón para cambiar de cámara
                if (_cameras != null && _cameras!.length > 1)
                  IconButton(
                    icon: const Icon(
                      Icons.flip_camera_ios,
                      color: Colors.white,
                    ),
                    onPressed: _toggleCameraDirection,
                  ),
                const SizedBox(height: 8),
                // Botón para flash
                IconButton(
                  icon: Icon(_getFlashIcon(), color: Colors.white),
                  onPressed: _toggleFlashMode,
                ),
              ],
            ),
          ),

          // Control de zoom
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.2,
            child: RotatedBox(
              quarterTurns: 3,
              child: SizedBox(
                width: 150,
                child: Slider(
                  value: _currentZoom,
                  min: _minAvailableZoom,
                  max: _maxAvailableZoom,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white30,
                  onChanged: (value) {
                    _setZoom(value);
                  },
                ),
              ),
            ),
          ),

          // Indicador de procesamiento
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black,
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
                    child: Text(
                      widget.spotId != null
                          ? 'Registrar Entrada'
                          : 'Registrar Placa',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else if (_scannedText.isNotEmpty && _imageFile != null) ...[
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Intenta tomar otra foto o seleccionar una imagen diferente',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
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
                      _imageFile != null
                          ? () {
                            setState(() {
                              _imageFile = null;
                              _scannedText = '';
                              _detectedPlate = null;
                            });
                          }
                          : _takePicture,
                  icon: Icon(
                    _imageFile != null ? Icons.refresh : Icons.camera_alt,
                  ),
                  label: Text(_imageFile != null ? 'Nueva foto' : 'Tomar foto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galería'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
