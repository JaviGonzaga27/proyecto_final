const express = require('express');
const router = express.Router();

const authRoutes = require('./authRoutes');
const userRoutes = require('./userRoutes');
const parkingRoutes = require('./parkingRoutes');
const plateRecognitionRoutes = require('./plateRecognitionRoutes');
const paymentRoutes = require('./paymentRoutes');

router.use('/auth', authRoutes);
router.use('/users', userRoutes);
router.use('/parking', parkingRoutes);
router.use('/plate-recognition', plateRecognitionRoutes);
router.use('/payments', paymentRoutes);

// Ruta de prueba de salud
router.get('/health', (req, res) => {
  res.status(200).json({
    success: true,
    message: 'API funcionando correctamente',
    timestamp: new Date().toISOString()
  });
});

module.exports = router;