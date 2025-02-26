const { db } = require('../config/firebase-config');

class FirebaseService {
  static async transaction(callback) {
    try {
      return await db.runTransaction(async (transaction) => {
        return await callback(transaction);
      });
    } catch (error) {
      console.error('Error en transacción Firebase:', error);
      throw error;
    }
  }

  static createBatch() {
    return db.batch();
  }

  static async commitBatch(batch) {
    return await batch.commit();
  }
}

module.exports = FirebaseService;