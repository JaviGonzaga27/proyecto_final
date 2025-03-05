const ParkingSpot = require('../models/parkingSpot');
const ParkingHistory = require('../models/parkingHistory');
const Payment = require('../models/payment');
const FirebaseService = require('../services/firebaseService');
const { db } = require('../config/firebase-config');

exports.getAllSpots = async (req, res) => {
  try {
    const spots = await ParkingSpot.getAll();
    return res.status(200).json({
      success: true,
      data: spots
    });
  } catch (error) {
    console.error('Error al obtener espacios:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al obtener espacios'
    });
  }
};

exports.getAvailableSpots = async (req, res) => {
  try {
    const spots = await ParkingSpot.getAvailable();
    return res.status(200).json({
      success: true,
      data: spots
    });
  } catch (error) {
    console.error('Error al obtener espacios disponibles:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al obtener espacios disponibles'
    });
  }
};

exports.createSpot = async (req, res) => {
  try {
    const { number, floor, section } = req.body;
    
    // Validar datos
    if (!number || !floor || !section) {
      return res.status(400).json({
        success: false,
        message: 'Todos los campos son obligatorios'
      });
    }
    
    const spotId = await ParkingSpot.create({
      number,
      floor,
      section
    });
    
    return res.status(201).json({
      success: true,
      message: 'Espacio creado correctamente',
      spotId
    });
  } catch (error) {
    console.error('Error al crear espacio:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al crear espacio'
    });
  }
};

exports.reserveSpot = async (req, res) => {
  try {
    const { spotId, userId } = req.body;
    
    // Validar datos
    if (!spotId || !userId) {
      return res.status(400).json({
        success: false,
        message: 'ID de espacio y usuario son obligatorios'
      });
    }
    
    // Verificar disponibilidad y reservar en una transacción
    const result = await FirebaseService.transaction(async (transaction) => {
      const spotRef = db.collection('parking_spots').doc(spotId);
      const spotDoc = await transaction.get(spotRef);
      
      if (!spotDoc.exists) {
        throw new Error('Espacio no encontrado');
      }
      
      const spotData = spotDoc.data();
      
      if (spotData.status !== 'available') {
        throw new Error('Espacio no disponible');
      }
      
      // Actualizar estado a reservado
      transaction.update(spotRef, {
        status: 'reserved',
        userId,
        reservationTime: new Date().toISOString()
      });
      
      return true;
    });
    
    return res.status(200).json({
      success: true,
      message: 'Espacio reservado correctamente'
    });
  } catch (error) {
    console.error('Error al reservar espacio:', error);
    
    // Manejar errores específicos
    if (error.message === 'Espacio no encontrado') {
      return res.status(404).json({
        success: false,
        message: error.message
      });
    }
    
    if (error.message === 'Espacio no disponible') {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }
    
    return res.status(500).json({
      success: false,
      message: 'Error al reservar espacio'
    });
  }
};

exports.registerEntry = async (req, res) => {
  try {
    const { spotId, userId, plateNumber } = req.body;
    
    // Validar datos
    if (!spotId || !userId || !plateNumber) {
      return res.status(400).json({
        success: false,
        message: 'Todos los campos son obligatorios'
      });
    }
    
    // Registrar entrada en una transacción
    await FirebaseService.transaction(async (transaction) => {
      const spotRef = db.collection('parking_spots').doc(spotId);
      const spotDoc = await transaction.get(spotRef);
      
      if (!spotDoc.exists) {
        throw new Error('Espacio no encontrado');
      }
      
      const spotData = spotDoc.data();
      
      // Verificar si el espacio está disponible o reservado por este usuario
      if (spotData.status !== 'available' && 
          !(spotData.status === 'reserved' && spotData.userId === userId)) {
        throw new Error('Espacio no disponible');
      }
      
      // Actualizar estado a ocupado
      transaction.update(spotRef, {
        status: 'occupied',
        userId,
        plateNumber,
        entryTime: new Date().toISOString()
      });
      
      // Crear registro en historial
      const historyRef = db.collection('parking_history').doc();
      transaction.set(historyRef, {
        parkingSpotId: spotId,
        userId,
        plateNumber,
        entryTime: new Date().toISOString(),
        status: 'active'
      });
    });
    
    return res.status(200).json({
      success: true,
      message: 'Entrada registrada correctamente'
    });
  } catch (error) {
    console.error('Error al registrar entrada:', error);
    
    // Manejar errores específicos
    if (error.message === 'Espacio no encontrado') {
      return res.status(404).json({
        success: false,
        message: error.message
      });
    }
    
    if (error.message === 'Espacio no disponible') {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }
    
    return res.status(500).json({
      success: false,
      message: 'Error al registrar entrada'
    });
  }
};

exports.registerExit = async (req, res) => {
  try {
    const { spotId, paymentMethod } = req.body;
    
    // Validar datos
    if (!spotId) {
      return res.status(400).json({
        success: false,
        message: 'ID de espacio es obligatorio'
      });
    }
    
    // Registrar salida en una transacción
    const result = await FirebaseService.transaction(async (transaction) => {
      const spotRef = db.collection('parking_spots').doc(spotId);
      const spotDoc = await transaction.get(spotRef);
      
      if (!spotDoc.exists) {
        throw new Error('Espacio no encontrado');
      }
      
      const spotData = spotDoc.data();
      
      if (spotData.status !== 'occupied') {
        throw new Error('No hay vehículo para registrar salida');
      }
      
      // Buscar el registro activo en el historial
      const historySnapshot = await db.collection('parking_history')
        .where('parkingSpotId', '==', spotId)
        .where('status', '==', 'active')
        .limit(1)
        .get();
      
      if (historySnapshot.empty) {
        throw new Error('No se encontró registro de entrada');
      }
      
      const historyDoc = historySnapshot.docs[0];
      const historyData = historyDoc.data();
      const historyRef = historyDoc.ref;
      
      // Calcular tiempo y tarifa
      const entryTime = new Date(historyData.entryTime);
      const exitTime = new Date();
      const durationMs = exitTime.getTime() - entryTime.getTime();
      const durationHours = durationMs / (1000 * 60 * 60);
      
      // Tarifa por hora (ajustar según necesidades)
      const hourlyRate = 5.0;
      const amount = Math.max(hourlyRate, hourlyRate * Math.ceil(durationHours));
      
      // Actualizar estado del espacio
      transaction.update(spotRef, {
        status: 'available',
        userId: null,
        plateNumber: null,
        entryTime: null
      });
      
      // Actualizar historial
      transaction.update(historyRef, {
        exitTime: exitTime.toISOString(),
        duration: durationHours,
        amount,
        status: 'completed'
      });
      
      // Registrar pago si se proporcionó método
      let paymentId = null;
      if (paymentMethod) {
        const paymentRef = db.collection('payments').doc();
        transaction.set(paymentRef, {
          userId: historyData.userId,
          historyId: historyDoc.id,
          amount,
          method: paymentMethod,
          status: 'completed',
          createdAt: new Date().toISOString()
        });
        paymentId = paymentRef.id;
      }
      
      return {
        historyId: historyDoc.id,
        entryTime,
        exitTime,
        duration: durationHours,
        amount,
        paymentId
      };
    });
    
    return res.status(200).json({
      success: true,
      message: 'Salida registrada correctamente',
      data: result
    });
  } catch (error) {
    console.error('Error al registrar salida:', error);
    
    // Manejar errores específicos
    if (error.message === 'Espacio no encontrado' || 
        error.message === 'No hay vehículo para registrar salida' ||
        error.message === 'No se encontró registro de entrada') {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }
    
    return res.status(500).json({
      success: false,
      message: 'Error al registrar salida'
    });
  }
};

exports.getParkingHistory = async (req, res) => {
  try {
    const { userId, plateNumber, status } = req.query;
    const filters = {};
    
    if (userId) filters.userId = userId;
    if (plateNumber) filters.plateNumber = plateNumber;
    if (status) filters.status = status;
    
    const history = await ParkingHistory.getAll(filters);
    
    return res.status(200).json({
      success: true,
      data: history
    });
  } catch (error) {
    console.error('Error al obtener historial:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al obtener historial'
    });
  }
};
// Agregar estos métodos al final de tu parkingController.js

exports.updateSpot = async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;
    
    const updated = await ParkingSpot.update(id, updateData);
    
    if (!updated) {
      return res.status(404).json({
        success: false,
        message: 'Espacio no encontrado'
      });
    }
    
    return res.status(200).json({
      success: true,
      message: 'Espacio actualizado correctamente'
    });
  } catch (error) {
    console.error('Error al actualizar espacio:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al actualizar espacio'
    });
  }
};

exports.deleteSpot = async (req, res) => {
  try {
    const { id } = req.params;
    
    const deleted = await ParkingSpot.delete(id);
    
    if (!deleted) {
      return res.status(404).json({
        success: false,
        message: 'Espacio no encontrado'
      });
    }
    
    return res.status(200).json({
      success: true,
      message: 'Espacio eliminado correctamente'
    });
  } catch (error) {
    console.error('Error al eliminar espacio:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al eliminar espacio'
    });
  }
};

exports.createTestSpots = async (req, res) => {
  try {
    const batch = db.batch();
    
    // Ejemplo de 12 espacios de estacionamiento distribuidos en 3 secciones y 2 pisos
    for (let floor = 1; floor <= 2; floor++) {
      for (let section of ['A', 'B', 'C']) {
        for (let i = 1; i <= 4; i++) {
          const spotRef = db.collection('parking_spots').doc();
          batch.set(spotRef, {
            number: `${section}${i}`,
            section: section,
            floor: floor,
            status: 'available', // Todos disponibles inicialmente
            createdAt: new Date().toISOString()
          });
        }
      }
    }
    
    await batch.commit();
    
    return res.status(201).json({
      success: true,
      message: 'Espacios de prueba creados correctamente'
    });
  } catch (error) {
    console.error('Error al crear espacios de prueba:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al crear espacios de prueba'
    });
  }
};