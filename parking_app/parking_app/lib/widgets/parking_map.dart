import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/parking_service.dart';
import '../models/parking_spot_model.dart';
import 'loading_indicator.dart';

class ParkingMapWidget extends StatefulWidget {
  const ParkingMapWidget({Key? key}) : super(key: key);

  @override
  _ParkingMapWidgetState createState() => _ParkingMapWidgetState();
}

class _ParkingMapWidgetState extends State<ParkingMapWidget> {
  GoogleMapController? _mapController;
  bool _isLoading = true;
  Map<String, Marker> _markers = {};
  final LatLng _defaultCenter = const LatLng(
    -0.1807,
    -78.4678,
  ); // Ajustar a tu ubicación
  final ParkingService _parkingService = ParkingService();

  @override
  void initState() {
    super.initState();
    _loadParkingSpots();
  }

  Future<void> _loadParkingSpots() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final spots = await _parkingService.getAllSpots();
      _updateMarkers(spots);
    } catch (e) {
      print('Error loading parking spots: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateMarkers(List<ParkingSpot> spots) {
    final markers = <String, Marker>{};

    // Crear marcadores para cada parqueadero
    // Nota: Estos son marcadores de ejemplo. En una aplicación real,
    // tendrías que obtener las coordenadas reales de cada parqueadero.

    // Ejemplo de parqueadero central
    markers['central'] = Marker(
      markerId: const MarkerId('central'),
      position: _defaultCenter,
      infoWindow: InfoWindow(
        title: 'Parqueadero Central',
        snippet: '${_countAvailableSpots(spots, 'A')} espacios disponibles',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(
        _hasAvailableSpots(spots, 'A')
            ? BitmapDescriptor.hueGreen
            : BitmapDescriptor.hueRed,
      ),
    );

    // Ejemplo de parqueadero norte
    markers['north'] = Marker(
      markerId: const MarkerId('north'),
      position: LatLng(
        _defaultCenter.latitude + 0.01,
        _defaultCenter.longitude,
      ),
      infoWindow: InfoWindow(
        title: 'Parqueadero Norte',
        snippet: '${_countAvailableSpots(spots, 'B')} espacios disponibles',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(
        _hasAvailableSpots(spots, 'B')
            ? BitmapDescriptor.hueGreen
            : BitmapDescriptor.hueRed,
      ),
    );

    // Ejemplo de parqueadero sur
    markers['south'] = Marker(
      markerId: const MarkerId('south'),
      position: LatLng(
        _defaultCenter.latitude - 0.01,
        _defaultCenter.longitude,
      ),
      infoWindow: InfoWindow(
        title: 'Parqueadero Sur',
        snippet: '${_countAvailableSpots(spots, 'C')} espacios disponibles',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(
        _hasAvailableSpots(spots, 'C')
            ? BitmapDescriptor.hueGreen
            : BitmapDescriptor.hueRed,
      ),
    );

    setState(() {
      _markers = markers;
    });
  }

  bool _hasAvailableSpots(List<ParkingSpot> spots, String section) {
    return spots.any(
      (spot) => spot.section == section && spot.status == 'available',
    );
  }

  int _countAvailableSpots(List<ParkingSpot> spots, String section) {
    return spots
        .where((spot) => spot.section == section && spot.status == 'available')
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _defaultCenter,
            zoom: 13,
          ),
          markers: _markers.values.toSet(),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
          mapToolbarEnabled: false,
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
        ),
        if (_isLoading)
          Container(
            color: Colors.black26,
            child: const LoadingIndicator(message: 'Cargando parqueaderos...'),
          ),
        Positioned(
          top: 16,
          right: 16,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            child: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _loadParkingSpots,
          ),
        ),
      ],
    );
  }
}
