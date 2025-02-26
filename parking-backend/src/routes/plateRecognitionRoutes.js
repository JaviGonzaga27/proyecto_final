const express = require('express');
const router = express.Router();
const multer = require('multer');
const plateRecognitionController = require('../controllers/plateRecognitionController');
const { verifyToken } = require('../middleware/auth');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB límite
  }
});

router.use(verifyToken);

router.post('/recognize', 
  upload.single('image'), 
  plateRecognitionController.recognizePlate
);

module.exports = router;