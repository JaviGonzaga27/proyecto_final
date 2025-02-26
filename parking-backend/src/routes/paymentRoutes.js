const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/paymentController');
const { verifyToken, verifyAdmin } = require('../middleware/auth');

router.use(verifyToken);

// Rutas de usuario
router.get('/user/:userId', paymentController.getPayments);
router.get('/:id', paymentController.getPaymentById);
router.get('/:id/receipt', paymentController.generateReceipt);

// Rutas administrativas
router.use(verifyAdmin);
router.get('/stats', paymentController.getPaymentStats);
router.post('/:id/refund', paymentController.refundPayment);

module.exports = router;