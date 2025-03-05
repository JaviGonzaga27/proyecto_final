import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/parking_spot_model.dart';
import '../../services/parking_service.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';
import '../parking/scan_plate_screen.dart';

class ParkingSpotScreen extends StatefulWidget {
  const ParkingSpotScreen({Key? key}) : super(key: key);

  @override
  _ParkingSpotScreenState createState() => _ParkingSpotScreenState();
}

class _ParkingSpotScreenState extends State<ParkingSpotScreen> {
  final ParkingService _parkingService = ParkingService();
  bool _isLoading = true;
  List<ParkingSpot> _spots = [];
  String _selectedFloor = 'Todos';
  String _selectedSection = 'Todos';
  bool _showMap = false; // Toggle between map and list view

  // Google Maps controller
  GoogleMapController? _mapController;

  // Default map position (you can adjust this to a location near you)
  final LatLng _defaultPosition = const LatLng(37.7749, -122.4194);
  LatLng _currentPosition = const LatLng(37.7749, -122.4194);

  // Map markers
  Map<MarkerId, Marker> _markers = {};

  List<String> _floors = ['Todos'];
  List<String> _sections = ['Todos'];

  @override
  void initState() {
    super.initState();
    _loadSpots();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      // Check for permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      // Update camera position
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _currentPosition, zoom: 15),
          ),
        );
      }
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  Future<void> _loadSpots() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final spots = await _parkingService.getAllSpots();

      // Extract unique floors and sections
      final floors =
          spots.map((spot) => spot.floor.toString()).toSet().toList();
      final sections = spots.map((spot) => spot.section).toSet().toList();

      setState(() {
        _spots = spots;
        _floors = ['Todos', ...floors];
        _sections = ['Todos', ...sections];
        _isLoading = false;
      });

      // Create markers for map
      _createMarkers(spots);
    } catch (e) {
      print('Error al cargar espacios: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar espacios: $e')));
    }
  }

  void _createMarkers(List<ParkingSpot> spots) {
    final Map<String, List<ParkingSpot>> spotsBySection = {};

    // Group spots by section
    for (var spot in spots) {
      if (!spotsBySection.containsKey(spot.section)) {
        spotsBySection[spot.section] = [];
      }
      spotsBySection[spot.section]!.add(spot);
    }

    // Create a marker for each section
    final Map<MarkerId, Marker> markers = {};
    double offsetLat = 0.001;
    double offsetLng = 0.001;

    spotsBySection.forEach((section, sectionSpots) {
      final availableSpots =
          sectionSpots.where((s) => s.status == 'available').length;
      final totalSpots = sectionSpots.length;
      final markerId = MarkerId(section);

      // Create positions around the current location
      final position = LatLng(
        _currentPosition.latitude +
            (offsetLat * (section.codeUnitAt(0) % 5 - 2)),
        _currentPosition.longitude +
            (offsetLng * (section.codeUnitAt(0) % 3 - 1)),
      );

      // Set marker color based on availability
      final BitmapDescriptor icon =
          availableSpots > 0
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

      // Create marker
      final marker = Marker(
        markerId: markerId,
        position: position,
        icon: icon,
        infoWindow: InfoWindow(
          title: 'Sección $section',
          snippet: '$availableSpots/$totalSpots espacios disponibles',
        ),
        onTap: () {
          // Filter spots by this section when tapped
          setState(() {
            _selectedSection = section;
            _showMap = false; // Switch to list view to see the spots
          });
        },
      );

      markers[markerId] = marker;
      offsetLat += 0.002;
      offsetLng += 0.002;
    });

    setState(() {
      _markers = markers;
    });
  }

  List<ParkingSpot> get filteredSpots {
    return _spots.where((spot) {
      // Filter by floor if one is selected
      if (_selectedFloor != 'Todos' &&
          spot.floor.toString() != _selectedFloor) {
        return false;
      }

      // Filter by section if one is selected
      if (_selectedSection != 'Todos' && spot.section != _selectedSection) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espacios de Parqueo'),
        actions: [
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            onPressed: () {
              setState(() {
                _showMap = !_showMap;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadSpots();
              if (_showMap) {
                _getCurrentLocation();
              }
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _showMap
              ? _buildMapView()
              : Column(
                children: [_buildFilters(), Expanded(child: _buildSpotsList())],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ScanPlateScreen()),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        GoogleMap(
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
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'location',
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () {
              _getCurrentLocation();
            },
            child: const Icon(Icons.my_location, color: AppTheme.primaryColor),
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Leyenda:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('Espacios disponibles'),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('Sin espacios disponibles'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtros',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Piso',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedFloor,
                  items:
                      _floors.map((floor) {
                        return DropdownMenuItem(
                          value: floor,
                          child: Text(floor),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedFloor = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Sección',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedSection,
                  items:
                      _sections.map((section) {
                        return DropdownMenuItem(
                          value: section,
                          child: Text(section),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSection = value!;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusIndicator('Disponible', Colors.green),
              _buildStatusIndicator('Ocupado', Colors.red),
              _buildStatusIndicator('Reservado', Colors.orange),
              _buildStatusIndicator('Mantenimiento', Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildSpotsList() {
    final spots = filteredSpots;

    if (spots.isEmpty) {
      return const Center(
        child: Text(
          'No hay espacios disponibles con los filtros seleccionados',
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: spots.length,
      itemBuilder: (context, index) {
        final spot = spots[index];
        return _buildSpotItem(spot);
      },
    );
  }

  Widget _buildSpotItem(ParkingSpot spot) {
    Color statusColor;
    IconData statusIcon;

    switch (spot.status) {
      case 'available':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'occupied':
        statusColor = Colors.red;
        statusIcon = Icons.directions_car;
        break;
      case 'reserved':
        statusColor = Colors.orange;
        statusIcon = Icons.bookmark;
        break;
      case 'maintenance':
        statusColor = Colors.grey;
        statusIcon = Icons.build;
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.help;
    }

    return InkWell(
      onTap: () => _showSpotDetails(spot),
      child: Container(
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(statusIcon, color: statusColor, size: 32),
            const SizedBox(height: 8),
            Text(
              spot.number,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text('Piso ${spot.floor}', style: const TextStyle(fontSize: 12)),
            Text(
              'Sección ${spot.section}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showSpotDetails(ParkingSpot spot) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _getStatusColor(
                      spot.status,
                    ).withOpacity(0.2),
                    child: Icon(
                      _getStatusIcon(spot.status),
                      color: _getStatusColor(spot.status),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Espacio ${spot.number}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Estado: ${_getStatusText(spot.status)}',
                        style: TextStyle(
                          color: _getStatusColor(spot.status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildInfoRow('Piso', spot.floor.toString()),
              _buildInfoRow('Sección', spot.section),
              if (spot.status == 'occupied') ...[
                _buildInfoRow('Placa', spot.plateNumber ?? 'No disponible'),
                _buildInfoRow(
                  'Ocupado desde',
                  spot.entryTime != null
                      ? _formatDateTime(spot.entryTime!)
                      : 'No disponible',
                ),
              ],
              if (spot.status == 'reserved') ...[
                _buildInfoRow(
                  'Reservado desde',
                  spot.reservationTime != null
                      ? _formatDateTime(spot.reservationTime!)
                      : 'No disponible',
                ),
              ],
              const SizedBox(height: 24),
              if (spot.status == 'available') ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _reserveSpot(spot),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Reservar Espacio'),
                  ),
                ),
              ] else if (spot.status == 'reserved' &&
                  spot.userId == user?.uid) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _registerEntry(spot),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Registrar Entrada'),
                  ),
                ),
              ] else if (spot.status == 'occupied' &&
                  spot.userId == user?.uid) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _registerExit(spot),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Registrar Salida'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'occupied':
        return Colors.red;
      case 'reserved':
        return Colors.orange;
      case 'maintenance':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'available':
        return Icons.check_circle;
      case 'occupied':
        return Icons.directions_car;
      case 'reserved':
        return Icons.bookmark;
      case 'maintenance':
        return Icons.build;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'available':
        return 'Disponible';
      case 'occupied':
        return 'Ocupado';
      case 'reserved':
        return 'Reservado';
      case 'maintenance':
        return 'Mantenimiento';
      default:
        return 'Desconocido';
    }
  }

  Future<void> _reserveSpot(ParkingSpot spot) async {
    Navigator.pop(context); // Close modal

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _parkingService.reserveSpot(spot.id);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Espacio reservado correctamente')),
        );
        await _loadSpots(); // Reload spots
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo reservar el espacio')),
        );
      }
    } catch (e) {
      print('Error al reservar espacio: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al reservar espacio: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _registerEntry(ParkingSpot spot) async {
    Navigator.pop(context); // Close modal

    // Navigate to scan screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ScanPlateScreen(spotId: spot.id)),
    );

    if (result == true) {
      await _loadSpots(); // Reload spots if entry was registered
    }
  }

  Future<void> _registerExit(ParkingSpot spot) async {
    Navigator.pop(context); // Close modal

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _parkingService.registerExit(spot.id);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Salida registrada. Monto: \$${result['amount'].toStringAsFixed(2)}',
            ),
          ),
        );
        await _loadSpots(); // Reload spots
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${result['message']}')));
      }
    } catch (e) {
      print('Error al registrar salida: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al registrar salida: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
