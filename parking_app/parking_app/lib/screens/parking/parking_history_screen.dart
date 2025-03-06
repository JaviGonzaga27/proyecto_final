// lib/screens/parking/parking_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/parking_history_model.dart';
import '../../services/parking_history_service.dart';
import '../../config/theme.dart';

class ParkingHistoryScreen extends StatefulWidget {
  const ParkingHistoryScreen({Key? key}) : super(key: key);

  @override
  _ParkingHistoryScreenState createState() => _ParkingHistoryScreenState();
}

class _ParkingHistoryScreenState extends State<ParkingHistoryScreen> {
  final ParkingHistoryService _historyService = ParkingHistoryService();
  bool _isLoading = true;
  List<ParkingHistoryModel> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final history = await _historyService.getUserParkingHistory();
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      print('Error al cargar historial: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar historial: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Estacionamientos'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistory),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _history.isEmpty
              ? _buildEmptyState()
              : _buildHistoryList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No tienes historial de estacionamientos',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];

        // Determinar color según estado
        Color statusColor;
        if (item.status == 'active') {
          statusColor = Colors.green;
        } else if (item.status == 'completed') {
          statusColor = Colors.blue;
        } else {
          statusColor = Colors.red;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Espacio ${item.spotSection}${item.spotNumber}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        _getStatusText(item.status),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.directions_car,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Placa: ${item.plateNumber}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.login, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Entrada: ${_formatDateTime(item.entryTime)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                if (item.exitTime != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.logout, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        'Salida: ${_formatDateTime(item.exitTime!)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
                if (item.duration != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Duración: ${_formatDuration(item.duration!)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
                if (item.amount != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Total: \$${item.amount!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
                if (item.status == 'active') ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _registerExit(item.id),
                      icon: const Icon(Icons.logout),
                      label: const Text('Registrar Salida'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  String _formatDuration(double hours) {
    final int hrs = hours.floor();
    final int mins = ((hours - hrs) * 60).round();
    return hrs > 0 ? '$hrs h $mins min' : '$mins min';
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return 'Activo';
      case 'completed':
        return 'Completado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return status;
    }
  }

  Future<void> _registerExit(String historyId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _historyService.registerExit(historyId);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Salida registrada. Monto: \$${result['amount'].toStringAsFixed(2)}',
            ),
          ),
        );
        _loadHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error al registrar salida: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar salida: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
}
