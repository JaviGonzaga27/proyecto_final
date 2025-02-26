const vision = require('@google-cloud/vision');
const fs = require('fs');
const path = require('path');
const { storage } = require('../config/firebase-config');

class PlateRecognitionService {
  constructor() {
    this.client = new vision.ImageAnnotatorClient();
  }

  async detectPlate(filePath) {
    try {
      // Leer la imagen del archivo
      const imageBuffer = fs.readFileSync(filePath);
      
      // Ejecutar reconocimiento de texto en la imagen
      const [result] = await this.client.textDetection(imageBuffer);
      const detections = result.textAnnotations;
      
      if (detections.length === 0) {
        return { success: false, message: 'No se detectó texto en la imagen' };
      }
      
      // Extraer el texto completo detectado
      const fullText = detections[0].description;
      
      // Limpiar y procesar el texto para encontrar el formato de placa
      // Modificar según el formato de placa local
      const plateRegex = /[A-Z]{3}[-\s]?\d{3,4}/g;
      const matches = fullText.match(plateRegex);
      
      if (matches && matches.length > 0) {
        // Tomar la primera coincidencia como placa
        const plateNumber = matches[0].replace(/[-\s]/g, '');
        return { success: true, plateNumber };
      } else {
        return { success: false, message: 'No se encontró un formato de placa válido' };
      }
    } catch (error) {
      console.error('Error al detectar placa:', error);
      return { success: false, message: 'Error en el procesamiento de la imagen' };
    }
  }

  async uploadAndRecognize(file) {
    try {
      // Subir imagen a Firebase Storage
      const filename = `${Date.now()}_${file.originalname}`;
      const fileUpload = storage.file(`plates/${filename}`);
      
      // Crear stream para subir el archivo
      const blobStream = fileUpload.createWriteStream({
        metadata: {
          contentType: file.mimetype
        }
      });
      
      // Esperar a que termine la subida
      await new Promise((resolve, reject) => {
        blobStream.on('error', reject);
        blobStream.on('finish', resolve);
        blobStream.end(file.buffer);
      });
      
      // Ejecutar reconocimiento de placa
      const result = await this.detectPlate(file.path);
      
      // Si se usó un archivo temporal, eliminarlo
      if (fs.existsSync(file.path)) {
        fs.unlinkSync(file.path);
      }
      
      // Obtener URL pública de la imagen
      const publicUrl = `https://storage.googleapis.com/${storage.name}/plates/${filename}`;
      
      return {
        ...result,
        imageUrl: publicUrl
      };
    } catch (error) {
      console.error('Error al procesar imagen:', error);
      return { success: false, message: 'Error al procesar la imagen' };
    }
  }
}

module.exports = new PlateRecognitionService();