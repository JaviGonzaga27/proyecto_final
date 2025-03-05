const User = require('../models/user');
const { auth, db } = require('../config/firebase-config');

exports.getAllUsers = async (req, res) => {
  try {
    const users = await User.getAll();
    return res.status(200).json({
      success: true,
      data: users
    });
  } catch (error) {
    console.error('Error al obtener usuarios:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al obtener usuarios'
    });
  }
};

exports.getUserById = async (req, res) => {
  try {
    const { id } = req.params;
    const user = await User.getById(id);
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Usuario no encontrado'
      });
    }
    
    return res.status(200).json({
      success: true,
      data: user
    });
  } catch (error) {
    console.error('Error al obtener usuario:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al obtener usuario'
    });
  }
};

exports.updateUser = async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;
    
    // Verificar si el usuario existe
    const existingUser = await User.getById(id);
    if (!existingUser) {
      return res.status(404).json({
        success: false,
        message: 'Usuario no encontrado'
      });
    }
    
    // Actualizar usuario
    await User.update(id, updateData);
    
    return res.status(200).json({
      success: true,
      message: 'Usuario actualizado correctamente'
    });
  } catch (error) {
    console.error('Error al actualizar usuario:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al actualizar usuario'
    });
  }
};

exports.deleteUser = async (req, res) => {
  try {
    const { id } = req.params;
    
    // Verificar si el usuario existe
    const existingUser = await User.getById(id);
    if (!existingUser) {
      return res.status(404).json({
        success: false,
        message: 'Usuario no encontrado'
      });
    }
    
    // Eliminar usuario
    await User.delete(id);
    
    return res.status(200).json({
      success: true,
      message: 'Usuario eliminado correctamente'
    });
  } catch (error) {
    console.error('Error al eliminar usuario:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al eliminar usuario'
    });
  }
};

exports.getUserVehicles = async (req, res) => {
  try {
    const { id } = req.params;
    
    const vehicles = await db.collection('vehicles')
      .where('userId', '==', id)
      .get();
    
    const vehicleList = vehicles.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    return res.status(200).json({
      success: true,
      data: vehicleList
    });
  } catch (error) {
    console.error('Error al obtener vehículos:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al obtener vehículos del usuario'
    });
  }
};

exports.addUserVehicle = async (req, res) => {
  try {
    const { id } = req.params;
    const { plateNumber, brand, model, color } = req.body;
    
    // Validar datos
    if (!plateNumber || !brand || !model) {
      return res.status(400).json({
        success: false,
        message: 'Placa, marca y modelo son obligatorios'
      });
    }
    
    // Verificar si la placa ya está registrada
    const existingVehicle = await db.collection('vehicles')
      .where('plateNumber', '==', plateNumber)
      .get();
    
    if (!existingVehicle.empty) {
      return res.status(400).json({
        success: false,
        message: 'Esta placa ya está registrada'
      });
    }
    
    // Registrar vehículo
    const vehicleRef = await db.collection('vehicles').add({
      userId: id,
      plateNumber,
      brand,
      model,
      color,
      createdAt: new Date().toISOString()
    });
    
    return res.status(201).json({
      success: true,
      message: 'Vehículo registrado correctamente',
      vehicleId: vehicleRef.id
    });
  } catch (error) {
    console.error('Error al registrar vehículo:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al registrar vehículo'
    });
  }
};

exports.getUserParkingHistory = async (req, res) => {
  try {
    const { id } = req.params;
    const { status, startDate, endDate } = req.query;
    
    let query = db.collection('parking_history')
      .where('userId', '==', id)
      .orderBy('entryTime', 'desc');
    
    if (status) {
      query = query.where('status', '==', status);
    }
    
    if (startDate) {
      query = query.where('entryTime', '>=', startDate);
    }
    
    if (endDate) {
      query = query.where('entryTime', '<=', endDate);
    }
    
    const history = await query.get();
    
    const parkingHistory = history.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    return res.status(200).json({
      success: true,
      data: parkingHistory
    });
  } catch (error) {
    console.error('Error al obtener historial:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al obtener historial de estacionamiento'
    });
  }
};

exports.getUserProfile = async (req, res) => {
  try {
    const { id } = req.params;
    
    // Obtener datos básicos del usuario
    const user = await User.getById(id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Usuario no encontrado'
      });
    }
    
    // Obtener vehículos del usuario
    const vehicles = await db.collection('vehicles')
      .where('userId', '==', id)
      .get();
    
    // Obtener estadísticas de estacionamiento
    const parkingStats = await db.collection('parking_history')
      .where('userId', '==', id)
      .get();
    
    // Obtener pagos totales
    const payments = await db.collection('payments')
      .where('userId', '==', id)
      .get();
    
    const profile = {
      ...user,
      vehicles: vehicles.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      })),
      stats: {
        totalParkings: parkingStats.size,
        totalPayments: payments.size,
        totalAmount: payments.docs.reduce((sum, doc) => sum + doc.data().amount, 0)
      }
    };
    
    return res.status(200).json({
      success: true,
      data: profile
    });
  } catch (error) {
    console.error('Error al obtener perfil:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al obtener perfil de usuario'
    });
  }
};

exports.updateUserPreferences = async (req, res) => {
  try {
    const { id } = req.params;
    const { notifications, language, theme } = req.body;
    
    // Actualizar preferencias
    await db.collection('users').doc(id).update({
      preferences: {
        notifications,
        language,
        theme
      },
      updatedAt: new Date().toISOString()
    });
    
    return res.status(200).json({
      success: true,
      message: 'Preferencias actualizadas correctamente'
    });
  } catch (error) {
    console.error('Error al actualizar preferencias:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al actualizar preferencias'
    });
  }
};

// Añade este método a tu userController.js
exports.updateUserVehicle = async (req, res) => {
  try {
    const { id, vehicleId } = req.params;
    const { brand, model, color } = req.body;
    
    // Validar datos
    if (!brand && !model && !color) {
      return res.status(400).json({
        success: false,
        message: 'Se debe proporcionar al menos un campo para actualizar'
      });
    }
    
    // Verificar que el vehículo exista y pertenezca al usuario
    const vehicleDoc = await db.collection('vehicles').doc(vehicleId).get();
    
    if (!vehicleDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Vehículo no encontrado'
      });
    }
    
    const vehicleData = vehicleDoc.data();
    if (vehicleData.userId !== id) {
      return res.status(403).json({
        success: false,
        message: 'No tienes permiso para modificar este vehículo'
      });
    }
    
    // Construir objeto con los campos a actualizar
    const updateData = {};
    if (brand) updateData.brand = brand;
    if (model) updateData.model = model;
    if (color) updateData.color = color;
    updateData.updatedAt = new Date().toISOString();
    
    // Actualizar vehículo
    await db.collection('vehicles').doc(vehicleId).update(updateData);
    
    return res.status(200).json({
      success: true,
      message: 'Vehículo actualizado correctamente'
    });
  } catch (error) {
    console.error('Error al actualizar vehículo:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al actualizar vehículo'
    });
  }
};

exports.deleteUserVehicle = async (req, res) => {
  try {
    const { id, vehicleId } = req.params;
    
    // Verificar que el vehículo exista y pertenezca al usuario
    const vehicleDoc = await db.collection('vehicles').doc(vehicleId).get();
    
    if (!vehicleDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Vehículo no encontrado'
      });
    }
    
    const vehicleData = vehicleDoc.data();
    if (vehicleData.userId !== id) {
      return res.status(403).json({
        success: false,
        message: 'No tienes permiso para eliminar este vehículo'
      });
    }
    
    // Eliminar vehículo
    await db.collection('vehicles').doc(vehicleId).delete();
    
    return res.status(200).json({
      success: true,
      message: 'Vehículo eliminado correctamente'
    });
  } catch (error) {
    console.error('Error al eliminar vehículo:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al eliminar vehículo'
    });
  }
};