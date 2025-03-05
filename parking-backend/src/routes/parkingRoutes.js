const express = require('express');
const router = express.Router();
const parkingController = require('../controllers/parkingController');
const { verifyToken, verifyAdmin } = require('../middleware/auth');

// Rutas que no requieren autenticación - si las necesitas
// router.get('/public', parkingController.getPublicSpots);

// Rutas que requieren autenticación
router.use(verifyToken);

// Usa solo los métodos que existen en tu controlador
router.get('/', parkingController.getAllSpots);
router.get('/available', parkingController.getAvailableSpots);
router.post('/entry', parkingController.registerEntry);
router.post('/create-test-spots', parkingController.createTestSpots);
router.post('/exit', parkingController.registerExit);
router.get('/history', parkingController.getParkingHistory);

// Rutas administrativas - comenta las que no estés usando
router.use(verifyAdmin);
router.post('/', parkingController.createSpot);
// Comenta las siguientes líneas por ahora
// router.put('/:id', parkingController.updateSpot);
// router.delete('/:id', parkingController.deleteSpot);

module.exports = router;