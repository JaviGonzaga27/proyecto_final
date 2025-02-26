const { db, auth } = require('../config/firebase-config');

const usersCollection = db.collection('users');

class User {
  static async getById(id) {
    const doc = await usersCollection.doc(id).get();
    if (!doc.exists) return null;
    return { id: doc.id, ...doc.data() };
  }

  static async create(data) {
    // Crear usuario en Firebase Auth
    const userRecord = await auth.createUser({
      email: data.email,
      password: data.password,
      displayName: `${data.firstName} ${data.lastName}`
    });

    // Guardar información adicional en Firestore
    await usersCollection.doc(userRecord.uid).set({
      firstName: data.firstName,
      lastName: data.lastName,
      email: data.email,
      role: data.role || 'user',
      createdAt: new Date().toISOString()
    });

    return userRecord.uid;
  }

  static async update(id, data) {
    const updateData = { ...data };
    delete updateData.password; // Eliminar la contraseña del objeto

    // Actualizar la información en Firestore
    await usersCollection.doc(id).update({
      ...updateData,
      updatedAt: new Date().toISOString()
    });

    // Si hay cambio de contraseña, actualizarla en Auth
    if (data.password) {
      await auth.updateUser(id, {
        password: data.password
      });
    }

    return true;
  }

  static async delete(id) {
    await usersCollection.doc(id).delete();
    await auth.deleteUser(id);
    return true;
  }
}

module.exports = User;