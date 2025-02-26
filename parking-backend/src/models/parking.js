const { db } = require('../config/firebase-config');
const FirebaseService = require('../services/firebaseService');

class Parking {
  constructor() {
    this.collection = db.collection('parkings');
    this.spotsCollection = db.collection('parking_spots');
  }

  async getAll() {
    try {
      const snapshot = await this.collection.get();
      return snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
    } catch (error) {
      console.error('Error al obtener parkings:', error);
      throw error;
    }
  }

  async getById(parkingId) {
    try {
      const doc = await this.collection.doc(parkingId).get();
      if (!doc.exists) return null;
      return { id: doc.id, ...doc.data() };
    } catch (error) {
      console.error('Error al obtener parking:', error);
      throw error;
    }
  }

  async create(parkingData) {
    try {
      const { name, location, totalSpots, rates, operatingHours } = parkingData;

      // Validar datos requeridos
      if (!name || !location || !totalSpots || !rates || !operatingHours) {
        throw new Error('Faltan datos requeridos');
      }

      // Crear el parking
      const parkingRef = await this.collection.add({
        name,
        location,
        totalSpots,
        availableSpots: totalSpots,
        rates,
        operatingHours,
        status: 'active',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      });

      // Crear spots iniciales
      const batch = db.batch();
      for (let i = 1; i <= totalSpots; i++) {
        const spotRef = this.spotsCollection.doc();
        batch.set(spotRef, {
          parkingId: parkingRef.id,
          number: i,
          status: 'available',
          createdAt: new Date().toISOString()
        });
      }
      await batch.commit();

      return parkingRef.id;
    } catch (error) {
      console.error('Error al crear parking:', error);
      throw error;
    }
  }

  async update(parkingId, updateData) {
    try {
      const parking = await this.getById(parkingId);
      if (!parking) throw new Error('Parking no encontrado');

      await this.collection.doc(parkingId).update({
        ...updateData,
        updatedAt: new Date().toISOString()
      });

      return true;
    } catch (error) {
      console.error('Error al actualizar parking:', error);
      throw error;
    }
  }

  async delete(parkingId) {
    try {
      // Eliminar parking y sus spots en una transacción
      await FirebaseService.transaction(async (transaction) => {
        // Verificar si hay spots ocupados
        const spotsSnapshot = await this.spotsCollection
          .where('parkingId', '==', parkingId)
          .where('status', '==', 'occupied')
          .get();

        if (!spotsSnapshot.empty) {
          throw new Error('No se puede eliminar el parking con spots ocupados');
        }

        // Eliminar todos los spots
        const allSpotsSnapshot = await this.spotsCollection
          .where('parkingId', '==', parkingId)
          .get();

        allSpotsSnapshot.docs.forEach(doc => {
          transaction.delete(doc.ref);
        });

        // Eliminar el parking
        transaction.delete(this.collection.doc(parkingId));
      });

      return true;
    } catch (error) {
      console.error('Error al eliminar parking:', error);
      throw error;
    }
  }

  async getSpots(parkingId, filters = {}) {
    try {
      let query = this.spotsCollection.where('parkingId', '==', parkingId);

      if (filters.status) {
        query = query.where('status', '==', filters.status);
      }

      const snapshot = await query.get();
      return snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
    } catch (error) {
      console.error('Error al obtener spots:', error);
      throw error;
    }
  }

  async getAvailability(parkingId) {
    try {
      const parking = await this.getById(parkingId);
      if (!parking) throw new Error('Parking no encontrado');

      const spotsSnapshot = await this.spotsCollection
        .where('parkingId', '==', parkingId)
        .get();

      const availability = {
        total: parking.totalSpots,
        available: 0,
        occupied: 0,
        reserved: 0,
        maintenance: 0
      };

      spotsSnapshot.docs.forEach(doc => {
        const status = doc.data().status;
        availability[status]++;
      });

      return availability;
    } catch (error) {
      console.error('Error al obtener disponibilidad:', error);
      throw error;
    }
  }

  async updateSpot(spotId, updateData) {
    try {
      const spotRef = this.spotsCollection.doc(spotId);
      const spot = await spotRef.get();

      if (!spot.exists) {
        throw new Error('Spot no encontrado');
      }

      await spotRef.update({
        ...updateData,
        updatedAt: new Date().toISOString()
      });

      // Actualizar contador de spots disponibles
      if (updateData.status) {
        const parkingRef = this.collection.doc(spot.data().parkingId);
        const parking = await parkingRef.get();
        const parkingData = parking.data();

        let availableSpots = parkingData.availableSpots;
        if (updateData.status === 'available' && spot.data().status !== 'available') {
          availableSpots++;
        } else if (updateData.status !== 'available' && spot.data().status === 'available') {
          availableSpots--;
        }

        await parkingRef.update({ availableSpots });
      }

      return true;
    } catch (error) {
      console.error('Error al actualizar spot:', error);
      throw error;
    }
  }

  async getParkingStats(parkingId, dateRange = {}) {
    try {
      const { startDate, endDate } = dateRange;
      let query = db.collection('parking_history')
        .where('parkingId', '==', parkingId);

      if (startDate) {
        query = query.where('entryTime', '>=', startDate);
      }
      if (endDate) {
        query = query.where('entryTime', '<=', endDate);
      }

      const snapshot = await query.get();
      const stats = {
        totalParkings: snapshot.size,
        revenue: 0,
        averageDuration: 0,
        peakHours: {},
        popularSpots: {}
      };

      let totalDuration = 0;

      snapshot.docs.forEach(doc => {
        const data = doc.data();
        // Calcular ingresos
        stats.revenue += data.amount || 0;

        // Calcular duración promedio
        if (data.duration) {
          totalDuration += data.duration;
        }

        // Registrar horas pico
        const hour = new Date(data.entryTime).getHours();
        stats.peakHours[hour] = (stats.peakHours[hour] || 0) + 1;

        // Registrar spots populares
        stats.popularSpots[data.spotId] = (stats.popularSpots[data.spotId] || 0) + 1;
      });

      if (snapshot.size > 0) {
        stats.averageDuration = totalDuration / snapshot.size;
      }

      return stats;
    } catch (error) {
      console.error('Error al obtener estadísticas:', error);
      throw error;
    }
  }
}

module.exports = new Parking();