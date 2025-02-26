const Payment = require('../models/payment');

exports.getPayments = async (req, res) => {
  try {
    const { userId } = req.query;
    const payments = await Payment.getAll(userId);
    
    return res.status(200).json({
      success: true,
      data: payments
    });
  } catch (error) {
    console.error('Error al obtener pagos:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al obtener pagos'
    });
  }
};

exports.getPaymentById = async (req, res) => {
  try {
    const { id } = req.params;
    const payment = await Payment.getById(id);
    
    if (!payment) {
      return res.status(404).json({
        success: false,
        message: 'Pago no encontrado'
      });
    }
    
    return res.status(200).json({
      success: true,
      data: payment
    });
  } catch (error) {
    console.error('Error al obtener pago:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al obtener pago'
    });
  }
};

exports.createPayment = async (req, res) => {
  try {
    const { userId, historyId, amount, method } = req.body;
    
    // Validar datos
    if (!userId || !historyId || !amount || !method) {
      return res.status(400).json({
        success: false,
        message: 'Todos los campos son obligatorios'
      });
    }
    
    const paymentId = await Payment.create({
      userId,
      historyId,
      amount,
      method
    });
    
    return res.status(201).json({
      success: true,
      message: 'Pago registrado correctamente',
      paymentId
    });
  } catch (error) {
    console.error('Error al crear pago:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al registrar pago'
    });
  }
};

exports.generateReceipt = async (req, res) => {
  try {
    const { paymentId } = req.params;
    const payment = await Payment.getById(paymentId);
    
    if (!payment) {
      return res.status(404).json({
        success: false,
        message: 'Pago no encontrado'
      });
    }
    
    // Aquí puedes implementar la lógica para generar un recibo en PDF o el formato deseado
    const receipt = {
      paymentId: payment.id,
      amount: payment.amount,
      date: payment.createdAt,
      method: payment.method,
      // Añadir más datos según necesidades
    };
    
    return res.status(200).json({
      success: true,
      data: receipt
    });
  } catch (error) {
    console.error('Error al generar recibo:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al generar recibo'
    });
  }
};

exports.getPaymentStats = async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    
    // Construir filtros de fecha
    const filters = {};
    if (startDate) filters.startDate = new Date(startDate);
    if (endDate) filters.endDate = new Date(endDate);
    
    // Obtener todos los pagos en el rango de fechas
    const payments = await Payment.getAll(null, filters);
    
    // Calcular estadísticas
    const stats = {
      totalAmount: 0,
      totalPayments: payments.length,
      paymentMethods: {},
      dailyStats: {}
    };
    
    payments.forEach(payment => {
      // Sumar monto total
      stats.totalAmount += payment.amount;
      
      // Contar por método de pago
      if (!stats.paymentMethods[payment.method]) {
        stats.paymentMethods[payment.method] = {
          count: 0,
          amount: 0
        };
      }
      stats.paymentMethods[payment.method].count++;
      stats.paymentMethods[payment.method].amount += payment.amount;
      
      // Agrupar por día
      const date = new Date(payment.createdAt).toISOString().split('T')[0];
      if (!stats.dailyStats[date]) {
        stats.dailyStats[date] = {
          count: 0,
          amount: 0
        };
      }
      stats.dailyStats[date].count++;
      stats.dailyStats[date].amount += payment.amount;
    });
    
    return res.status(200).json({
      success: true,
      data: stats
    });
  } catch (error) {
    console.error('Error al obtener estadísticas:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al obtener estadísticas'
    });
  }
};

exports.refundPayment = async (req, res) => {
  try {
    const { paymentId } = req.params;
    const { reason } = req.body;
    
    // Validar datos
    if (!reason) {
      return res.status(400).json({
        success: false,
        message: 'La razón del reembolso es obligatoria'
      });
    }
    
    const payment = await Payment.getById(paymentId);
    
    if (!payment) {
      return res.status(404).json({
        success: false,
        message: 'Pago no encontrado'
      });
    }
    
    if (payment.status === 'refunded') {
      return res.status(400).json({
        success: false,
        message: 'El pago ya fue reembolsado'
      });
    }
    
    // Registrar reembolso
    await Payment.update(paymentId, {
      status: 'refunded',
      refundReason: reason,
      refundDate: new Date().toISOString()
    });
    
    return res.status(200).json({
      success: true,
      message: 'Reembolso procesado correctamente'
    });
  } catch (error) {
    console.error('Error al procesar reembolso:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al procesar reembolso'
    });
  }
};