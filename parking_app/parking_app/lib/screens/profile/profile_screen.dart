import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user != null) {
        final userData =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userData.exists) {
          final data = userData.data()!;
          _firstNameController.text = data['firstName'] ?? '';
          _lastNameController.text = data['lastName'] ?? '';
          _emailController.text = user.email ?? '';
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user != null) {
        // Actualizar datos en Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'displayName':
              '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Actualizar displayName en Firebase Auth
        await user.updateDisplayName(
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')),
        );

        setState(() {
          _isEditing = false;
        });
      }
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar perfil: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(user),
                    const SizedBox(height: 24),
                    _buildProfileForm(),
                    const SizedBox(height: 24),
                    _buildVehiclesSection(),
                    const SizedBox(height: 24),
                    _buildHistorySection(),
                  ],
                ),
              ),
    );
  }

  Widget _buildProfileHeader(User? user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppTheme.primaryColor,
              backgroundImage:
                  user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child:
                  user?.photoURL == null
                      ? const Icon(Icons.person, size: 50, color: Colors.white)
                      : null,
            ),
            const SizedBox(height: 16),
            Text(
              user?.displayName ?? 'Usuario',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? '',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Información Personal',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(_isEditing ? Icons.close : Icons.edit),
                    onPressed: () {
                      setState(() {
                        _isEditing = !_isEditing;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                enabled: _isEditing,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa tu nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Apellido',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                enabled: _isEditing,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa tu apellido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                enabled: false,
              ),
              if (_isEditing) ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Guardar Cambios'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehiclesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mis Vehículos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    // Implementar agregar vehículo
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildVehicleCard(
              'ABC123',
              'Toyota Corolla',
              'Blanco',
              Icons.directions_car,
              Colors.blue,
            ),
            _buildVehicleCard(
              'XYZ789',
              'Honda Civic',
              'Negro',
              Icons.directions_car,
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(
    String plate,
    String model,
    String color,
    IconData icon,
    Color iconColor,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(plate, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$model • $color'),
        trailing: PopupMenuButton(
          itemBuilder:
              (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Editar')),
                const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
          onSelected: (value) {
            // Implementar acciones
          },
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Historial Reciente',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    // Implementar ver todo el historial
                  },
                  child: const Text('Ver Todo'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildHistoryItem(
              'Parqueadero Central',
              'ABC123',
              DateTime.now().subtract(const Duration(hours: 5)),
              DateTime.now().subtract(const Duration(hours: 3)),
              15.00,
            ),
            _buildHistoryItem(
              'Parqueadero Norte',
              'XYZ789',
              DateTime.now().subtract(const Duration(days: 1)),
              DateTime.now().subtract(const Duration(days: 1, hours: 3)),
              8.50,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(
    String location,
    String plate,
    DateTime entryTime,
    DateTime exitTime,
    double amount,
  ) {
    final duration = exitTime.difference(entryTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  location,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.directions_car, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(plate),
                const SizedBox(width: 16),
                const Icon(Icons.schedule, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('$hours h $minutes min'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.login, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Text('Entrada: ${_formatDateTime(entryTime)}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.logout, size: 16, color: Colors.red),
                const SizedBox(width: 4),
                Text('Salida: ${_formatDateTime(exitTime)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
