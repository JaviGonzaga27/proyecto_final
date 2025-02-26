class PaymentModel {
  final String id;
  final String userId;
  final String historyId;
  final String spotId;
  final String plateNumber;
  final double amount;
  final String method; // 'app', 'credit_card', 'cash', etc.
  final String status; // 'completed', 'pending', 'refunded'
  final DateTime createdAt;
  final String? transactionId;
  final String? receipt;

  PaymentModel({
    required this.id,
    required this.userId,
    required this.historyId,
    required this.spotId,
    required this.plateNumber,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
    this.transactionId,
    this.receipt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'],
      userId: json['userId'],
      historyId: json['historyId'],
      spotId: json['spotId'],
      plateNumber: json['plateNumber'],
      amount: json['amount']?.toDouble() ?? 0.0,
      method: json['method'],
      status: json['status'],
      createdAt:
          json['createdAt'] != null
              ? (json['createdAt'] is DateTime
                  ? json['createdAt']
                  : DateTime.parse(json['createdAt']))
              : DateTime.now(),
      transactionId: json['transactionId'],
      receipt: json['receipt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'historyId': historyId,
      'spotId': spotId,
      'plateNumber': plateNumber,
      'amount': amount,
      'method': method,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'transactionId': transactionId,
      'receipt': receipt,
    };
  }
}
