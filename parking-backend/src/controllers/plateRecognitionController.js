const path = require('path');
const os = require('os');
const fs = require('fs');
const plateRecognitionService = require('../services/plateRecognitionService');

exports.recognizePlate = async (req, res) => {
  try {
    // Verificar si hay archivo en la solicitud
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No se proporcionó imagen'
      });
    }
    
    // Guardar temporalmente el archivo
    const tempFilePath = path.join(os.tmpdir(), req.file.originalname);
    fs.writeFileSync(tempFilePath, req.file.buffer);
    
    // Añadir ruta al objeto file
    req.file.path = tempFilePath;
    
    // Procesar imagen
    const result = await plateRecognitionService.uploadAndRecognize(req.file);
    
    if (result.success) {
      return res.status(200).json({
        success: true,
        plateNumber: result.plateNumber,
        imageUrl: result.imageUrl
      });
    } else {
      return res.status(400).json({
        success: false,
        message: result.message,
        imageUrl: result.imageUrl
      });
    }
  } catch (error) {
    console.error('Error al reconocer placa:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al procesar la imagen'
    });
  }
};