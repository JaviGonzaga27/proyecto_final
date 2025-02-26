const { db } = require('../config/firebase-config');

const historyCollection = db.collection('parking_history');

class ParkingHistory {
  static async getAll(filters = {}) {
    let query = historyCollection;
    
    if (filters.userId) {
      query = query.where('userId', '==', filters.userId);
    }
    
    if (filters.plateNumber) {
      query = query.where('plateNumber', '==', filters.plateNumber);
    }
    
    if (filters.status) {
      query = query.where('status', '==', filters.status);
    }
    
    const snapshot = await query.orderBy('entryTime', 'desc').get();
    
    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
  }

  static async getActive() {
    const snapshot = await historyCollection
      .where('status', '==', 'active')
      .get();
    
    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
  }

  static async getById(id) {
    const doc = await historyCollection.doc(id).get();
    if (!doc.exists) return null;
    return { id: doc.id, ...doc.data() };
  }

  static async create(data) {
    const docRef = await historyCollection.add({
      parkingSpotId: data.parkingSpotId,
      userId: data.userId,
      plateNumber: data.plateNumber,
      entryTime: new Date().toISOString(),
      status: 'active'
    });
    return docRef.id;
  }

  static async update(id, data) {
    await historyCollection.doc(id).update({
      ...data,
      updatedAt: new Date().toISOString()
    });
    return true;
  }

  static async registerExit(id, amount) {
    const exitTime = new Date();
    
    const historyDoc = await historyCollection.doc(id).get();
    if (!historyDoc.exists) throw new Error('Registro no encontrado');
    
    const historyData = historyDoc.data();
    const entryTime = new Date(historyData.entryTime);
    
    // Calcular duración en horas
    const durationMs = exitTime.getTime() - entryTime.getTime();
    const durationHours = durationMs / (1000 * 60 * 60);
    
    await historyCollection.doc(id).update({
      exitTime: exitTime.toISOString(),
      duration: durationHours,
      amount: amount,
      status: 'completed'
    });
    
    return {
      entryTime,
      exitTime,
      duration: durationHours,
      amount
    };
  }
}

module.exports = ParkingHistory;