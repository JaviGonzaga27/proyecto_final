const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const { verifyToken } = require('../middleware/auth');

router.use(verifyToken);

router.get('/', userController.getAllUsers);
router.get('/:id', userController.getUserById);
router.put('/:id', userController.updateUser);
router.delete('/:id', userController.deleteUser);

router.get('/:id/vehicles', userController.getUserVehicles);
router.post('/:id/vehicles', userController.addUserVehicle);
router.put('/:id/vehicles/:vehicleId', userController.updateUserVehicle);
router.delete('/:id/vehicles/:vehicleId', userController.deleteUserVehicle);
router.get('/:id/parking-history', userController.getUserParkingHistory);
router.get('/:id/profile', userController.getUserProfile);
router.put('/:id/preferences', userController.updateUserPreferences);

module.exports = router;