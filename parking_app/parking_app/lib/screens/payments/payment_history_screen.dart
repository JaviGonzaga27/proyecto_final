// lib/screens/payments/payment_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/payment_model.dart';
import '../../services/payment_service.dart';
import '../../config/theme.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({Key? key}) : super(key: key);

  @override
  _PaymentHistoryScreenState createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = true;
  List<PaymentModel> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final payments = await _paymentService.getUserPayments();
      setState(() {
        _payments = payments;
        _isLoading = false;
      });
    } catch (e) {
      print('Error al cargar pagos: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar pagos: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Pagos'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPayments),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _payments.isEmpty
              ? _buildEmptyState()
              : _buildPaymentsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payment, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No tienes historial de pagos',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsList() {
    // Calcular monto total
    final totalAmount = _payments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );

    return Column(
      children: [
        // Resumen de pagos
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: AppTheme.primaryColor.withOpacity(0.1),
          child: Column(
            children: [
              const Text(
                'Resumen de Pagos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Total Pagado: \$${totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Cantidad de Pagos: ${_payments.length}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
        // Lista de pagos
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _payments.length,
            itemBuilder: (context, index) {
              final payment = _payments[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '#${payment.id.substring(0, 8)}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getPaymentMethodColor(
                                payment.method,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _getPaymentMethodColor(payment.method),
                              ),
                            ),
                            child: Text(
                              _getPaymentMethodText(payment.method),
                              style: TextStyle(
                                color: _getPaymentMethodColor(payment.method),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.directions_car,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Placa: ${payment.plateNumber}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Fecha: ${_formatDateTime(payment.createdAt)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '\$${payment.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _viewReceipt(payment.id),
                          icon: const Icon(Icons.receipt),
                          label: const Text('Ver Recibo'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  Color _getPaymentMethodColor(String method) {
    switch (method) {
      case 'app':
        return Colors.blue;
      case 'credit_card':
        return Colors.green;
      case 'cash':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentMethodText(String method) {
    switch (method) {
      case 'app':
        return 'App';
      case 'credit_card':
        return 'Tarjeta';
      case 'cash':
        return 'Efectivo';
      default:
        return method;
    }
  }

  Future<void> _viewReceipt(String paymentId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final receipt = await _paymentService.getReceipt(paymentId);

      setState(() {
        _isLoading = false;
      });

      if (receipt['success']) {
        _showReceiptDialog(receipt['data']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${receipt['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error al obtener recibo: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al obtener recibo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showReceiptDialog(Map<String, dynamic> receiptData) {
    final dateTime =
        receiptData['date'] is String
            ? DateTime.parse(receiptData['date'])
            : (receiptData['date'] as DateTime);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Recibo de Pago'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 48, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(
                    '\$${receiptData['amount'].toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildReceiptRow('Fecha', _formatDateTime(dateTime)),
                  _buildReceiptRow(
                    'Método',
                    _getPaymentMethodText(receiptData['method']),
                  ),
                  _buildReceiptRow('Estado', receiptData['status']),
                  _buildReceiptRow('ID', receiptData['paymentId']),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Implementar función para enviar recibo por email o compartir
                },
                icon: const Icon(Icons.share),
                label: const Text('Compartir'),
              ),
            ],
          ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
