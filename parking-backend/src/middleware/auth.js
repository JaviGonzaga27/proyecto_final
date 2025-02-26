const { auth } = require('../config/firebase-config');

exports.verifyToken = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split('Bearer ')[1];
    
    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Token no proporcionado'
      });
    }
    
    const decodedToken = await auth.verifyIdToken(token);
    req.user = decodedToken;
    next();
  } catch (error) {
    console.error('Error en verificación de token:', error);
    return res.status(401).json({
      success: false,
      message: 'Token inválido o expirado'
    });
  }
};

exports.verifyAdmin = async (req, res, next) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Usuario no autenticado'
      });
    }
    
    const userRecord = await auth.getUser(req.user.uid);
    const customClaims = userRecord.customClaims || {};
    
    if (!customClaims.admin) {
      return res.status(403).json({
        success: false,
        message: 'Acceso no autorizado'
      });
    }
    
    next();
  } catch (error) {
    console.error('Error en verificación de admin:', error);
    return res.status(403).json({
      success: false,
      message: 'Error en verificación de permisos'
    });
  }
};