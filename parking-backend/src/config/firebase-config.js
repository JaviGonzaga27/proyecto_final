const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Obtener el ID del proyecto directamente del archivo de credenciales
const projectId = serviceAccount.project_id;

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: `https://${projectId}.firebaseio.com`,
  storageBucket: `${projectId}.appspot.com`
});

const db = admin.firestore();
const auth = admin.auth();

// Manejo seguro del bucket de storage
let storage;
try {
  storage = admin.storage().bucket();
} catch (error) {
  console.warn('Advertencia: No se pudo inicializar Firebase Storage:', error.message);
  // Crear un objeto simulado para evitar errores
  storage = {
    file: () => ({
      createWriteStream: () => {
        console.warn('Firebase Storage no está disponible');
        return { on: () => {}, end: () => {} };
      }
    }),
    upload: async () => { console.warn('Firebase Storage no está disponible'); }
  };
}

module.exports = { admin, db, auth, storage };