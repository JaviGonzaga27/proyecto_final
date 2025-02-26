const { auth, db } = require('../config/firebase-config');
const User = require('../models/user');

exports.register = async (req, res) => {
  try {
    const { email, password, firstName, lastName, role, uid } = req.body;
    
    // Validar datos
    if (!email || !password || !firstName || !lastName) {
      return res.status(400).json({ 
        success: false, 
        message: 'Todos los campos son obligatorios' 
      });
    }
    
    let userId = uid;
    
    // Si no se proporcionó un UID (registro desde backend), crear el usuario en Firebase Auth
    if (!userId) {
      try {
        const userRecord = await auth.createUser({
          email,
          password,
          displayName: `${firstName} ${lastName}`
        });
        userId = userRecord.uid;
      } catch (authError) {
        console.error('Error al crear usuario en Firebase Auth:', authError);
        
        // Manejar errores específicos de Firebase Auth
        if (authError.code === 'auth/email-already-exists') {
          return res.status(400).json({
            success: false,
            message: 'El correo electrónico ya está en uso'
          });
        }
        
        throw authError;
      }
    }
    
    // Guardar datos en Firestore
    console.log('Guardando usuario en Firestore con UID:', userId);
    await db.collection('users').doc(userId).set({
      firstName,
      lastName,
      email,
      role: role || 'user',
      createdAt: new Date().toISOString()
    });
    
    return res.status(201).json({
      success: true,
      message: 'Usuario registrado correctamente',
      userId
    });
  } catch (error) {
    console.error('Error al registrar usuario:', error);
    
    return res.status(500).json({
      success: false,
      message: 'Error al registrar usuario'
    });
  }
};

exports.login = async (req, res) => {
  try {
    const { email, uid } = req.body;
    const idToken = req.headers.authorization?.split('Bearer ')[1];
    
    console.log('Login intento - Email:', email, 'UID:', uid);
    
    if (!idToken) {
      return res.status(400).json({
        success: false,
        message: 'Token no proporcionado'
      });
    }
    
    // Verificar token
    const decodedToken = await auth.verifyIdToken(idToken);
    
    // Verificar que el uid coincida
    if (decodedToken.uid !== uid) {
      console.log('UID no coincide:', decodedToken.uid, '!=', uid);
      return res.status(401).json({
        success: false,
        message: 'Token inválido'
      });
    }
    
    // Obtener datos del usuario
    console.log('Buscando usuario en Firestore con UID:', uid);
    const userDoc = await db.collection('users').doc(uid).get();
    
    if (!userDoc.exists) {
      console.log('Usuario no encontrado en Firestore, creándolo automáticamente');
      // Crear el usuario en Firestore
      const userData = {
        firstName: email.split('@')[0], // Valor temporal basado en email
        lastName: "",
        email: email,
        role: "user",
        createdAt: new Date().toISOString()
      };
      
      await db.collection('users').doc(uid).set(userData);
      
      return res.status(200).json({
        success: true,
        message: 'Login exitoso - Usuario creado automáticamente',
        user: {
          uid: decodedToken.uid,
          email: decodedToken.email,
          firstName: userData.firstName,
          lastName: userData.lastName,
          role: userData.role
        }
      });
    }
    
    const userData = userDoc.data();
    
    return res.status(200).json({
      success: true,
      message: 'Login exitoso',
      user: {
        uid: decodedToken.uid,
        email: decodedToken.email,
        firstName: userData.firstName,
        lastName: userData.lastName,
        role: userData.role
      }
    });
  } catch (error) {
    console.error('Error al iniciar sesión:', error);
    return res.status(401).json({
      success: false,
      message: 'Credenciales inválidas'
    });
  }
};

exports.verifyToken = async (req, res) => {
  try {
    const { idToken } = req.body;
    
    // Validar datos
    if (!idToken) {
      return res.status(400).json({ 
        success: false, 
        message: 'Token no proporcionado' 
      });
    }
    
    // Verificar token
    const decodedToken = await auth.verifyIdToken(idToken);
    const uid = decodedToken.uid;
    
    // Obtener datos del usuario
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Usuario no encontrado'
      });
    }
    
    const userData = userDoc.data();
    
    return res.status(200).json({
      success: true,
      user: {
        uid,
        email: userData.email,
        firstName: userData.firstName,
        lastName: userData.lastName,
        role: userData.role
      }
    });
  } catch (error) {
    console.error('Error al verificar token:', error);
    return res.status(401).json({
      success: false,
      message: 'Token inválido o expirado'
    });
  }
};