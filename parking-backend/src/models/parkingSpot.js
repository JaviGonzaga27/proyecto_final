const { db } = require('../config/firebase-config');

const parkingSpotsCollection = db.collection('parking_spots');

class ParkingSpot {
  static async getAll() {
    const snapshot = await parkingSpotsCollection.get();
    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
  }

  static async getById(id) {
    const doc = await parkingSpotsCollection.doc(id).get();
    if (!doc.exists) return null;
    return { id: doc.id, ...doc.data() };
  }

  static async getAvailable() {
    const snapshot = await parkingSpotsCollection
      .where('status', '==', 'available')
      .get();
    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
  }

  static async create(data) {
    const docRef = await parkingSpotsCollection.add({
      number: data.number,
      floor: data.floor,
      section: data.section,
      status: 'available',
      createdAt: new Date().toISOString()
    });
    return docRef.id;
  }

  static async update(id, data) {
    await parkingSpotsCollection.doc(id).update({
      ...data,
      updatedAt: new Date().toISOString()
    });
    return true;
  }

  static async delete(id) {
    await parkingSpotsCollection.doc(id).delete();
    return true;
  }
}

module.exports = ParkingSpot;