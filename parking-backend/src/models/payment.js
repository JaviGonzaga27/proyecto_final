const { db } = require('../config/firebase-config');

const paymentsCollection = db.collection('payments');

class Payment {
  static async getAll(userId) {
    let query = paymentsCollection;
    
    if (userId) {
      query = query.where('userId', '==', userId);
    }
    
    const snapshot = await query.orderBy('createdAt', 'desc').get();
    
    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
  }

  static async getById(id) {
    const doc = await paymentsCollection.doc(id).get();
    if (!doc.exists) return null;
    return { id: doc.id, ...doc.data() };
  }

  static async create(data) {
    const docRef = await paymentsCollection.add({
      userId: data.userId,
      historyId: data.historyId,
      amount: data.amount,
      method: data.method,
      status: 'completed',
      createdAt: new Date().toISOString()
    });
    return docRef.id;
  }
}

module.exports = Payment;