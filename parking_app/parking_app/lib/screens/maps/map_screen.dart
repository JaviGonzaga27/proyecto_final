import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/parking_service.dart';
import '../../config/theme.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(0, 0);
  bool _isLoading = true;
  Map<MarkerId, Marker> _markers = {};

  final ParkingService _parkingService = ParkingService();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadParkingLocations();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Verificar si los servicios de ubicación están habilitados
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Los servicios de ubicación no están habilitados, mostrar diálogo al usuario
        bool serviceRequested = await Geolocator.openLocationSettings();
        if (!serviceRequested) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Verificar permisos de ubicación
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Obtener la posición actual
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      // Actualizar cámara a la posición actual
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition, zoom: 15),
        ),
      );
    } catch (e) {
      print('Error getting current location: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadParkingLocations() async {
    try {
      final spots = await _parkingService.getAllSpots();

      // Simular ubicaciones de parqueaderos para pruebas
      // En una app real, estas coordenadas vendrían de tu base de datos
      final List<Map<String, dynamic>> parkingLocations = [
        {
          'id': 'central',
          'name': 'Parqueadero Central',
          'latitude': _currentPosition.latitude + 0.001,
          'longitude': _currentPosition.longitude + 0.001,
          'availableSpots':
              spots
                  .where((s) => s.status == 'available' && s.section == 'A')
                  .length,
          'totalSpots': spots.where((s) => s.section == 'A').length,
        },
        {
          'id': 'north',
          'name': 'Parqueadero Norte',
          'latitude': _currentPosition.latitude + 0.003,
          'longitude': _currentPosition.longitude - 0.002,
          'availableSpots':
              spots
                  .where((s) => s.status == 'available' && s.section == 'B')
                  .length,
          'totalSpots': spots.where((s) => s.section == 'B').length,
        },
        {
          'id': 'south',
          'name': 'Parqueadero Sur',
          'latitude': _currentPosition.latitude - 0.002,
          'longitude': _currentPosition.longitude + 0.002,
          'availableSpots':
              spots
                  .where((s) => s.status == 'available' && s.section == 'C')
                  .length,
          'totalSpots': spots.where((s) => s.section == 'C').length,
        },
      ];

      _createMarkers(parkingLocations);
    } catch (e) {
      print('Error loading parking locations: $e');
    }
  }

  void _createMarkers(List<Map<String, dynamic>> parkingLocations) {
    final markers = <MarkerId, Marker>{};

    for (final parking in parkingLocations) {
      final markerId = MarkerId(parking['id']);

      // Determinar color del marcador según disponibilidad
      final BitmapDescriptor markerIcon =
          parking['availableSpots'] > 0
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

      final marker = Marker(
        markerId: markerId,
        position: LatLng(parking['latitude'], parking['longitude']),
        infoWindow: InfoWindow(
          title: parking['name'],
          snippet:
              '${parking['availableSpots']}/${parking['totalSpots']} espacios disponibles',
        ),
        icon: markerIcon,
        onTap: () {
          _showParkingDetails(parking);
        },
      );

      markers[markerId] = marker;
    }

    setState(() {
      _markers = markers;
    });
  }

  void _showParkingDetails(Map<String, dynamic> parking) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                parking['name'],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    parking['availableSpots'] > 0
                        ? Icons.check_circle
                        : Icons.cancel,
                    color:
                        parking['availableSpots'] > 0
                            ? Colors.green
                            : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${parking['availableSpots']}/${parking['totalSpots']} espacios disponibles',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Horario: 6:00 AM - 10:00 PM',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text('Tarifa: \$1.00/hora', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Implementar navegación
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.directions),
                      label: const Text('Navegar'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Redirigir a pantalla de detalles o reserva
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.bookmark_border),
                      label: const Text('Reservar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parqueaderos Cercanos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadParkingLocations();
              _getCurrentLocation();
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentPosition,
                  zoom: 15,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                markers: Set<Marker>.of(_markers.values),
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: _currentPosition, zoom: 15),
              ),
            );
          }
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
