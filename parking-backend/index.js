// Al inicio del archivo
require('dotenv').config();
console.log('Bucket de storage:', process.env.FIREBASE_STORAGE_BUCKET);

const app = require('./src/app');

const config = require('./src/config/app-config');

// Iniciar el servidor
const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Servidor iniciado en el puerto ${PORT}`);
  console.log(`Entorno: ${config.env}`);
  console.log(`URL: http://localhost:${PORT}`);
  console.log(`Para acceso externo: http://192.168.1.6:${PORT}`);
});

// Manejar cierre elegante
process.on('SIGINT', () => {
  console.log('Cerrando servidor...');
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('Cerrando servidor...');
  process.exit(0);
});

process.on('uncaughtException', (error) => {
  console.error('Error no capturado:', error);
  process.exit(1);
});