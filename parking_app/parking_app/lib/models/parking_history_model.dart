class ParkingHistoryModel {
  final String id;
  final String parkingSpotId;
  final String spotNumber;
  final String spotSection;
  final int spotFloor;
  final String userId;
  final String plateNumber;
  final String? plateImageUrl;
  final DateTime entryTime;
  final DateTime? exitTime;
  final double? duration;
  final double? amount;
  final String status; // 'active', 'completed', 'cancelled'
  final String? paymentId;

  ParkingHistoryModel({
    required this.id,
    required this.parkingSpotId,
    required this.spotNumber,
    required this.spotSection,
    required this.spotFloor,
    required this.userId,
    required this.plateNumber,
    this.plateImageUrl,
    required this.entryTime,
    this.exitTime,
    this.duration,
    this.amount,
    required this.status,
    this.paymentId,
  });

  factory ParkingHistoryModel.fromJson(Map<String, dynamic> json) {
    return ParkingHistoryModel(
      id: json['id'],
      parkingSpotId: json['parkingSpotId'],
      spotNumber: json['spotNumber'],
      spotSection: json['spotSection'],
      spotFloor: json['spotFloor'],
      userId: json['userId'],
      plateNumber: json['plateNumber'],
      plateImageUrl: json['plateImageUrl'],
      entryTime:
          json['entryTime'] != null
              ? (json['entryTime'] is DateTime
                  ? json['entryTime']
                  : DateTime.parse(json['entryTime']))
              : DateTime.now(),
      exitTime:
          json['exitTime'] != null
              ? (json['exitTime'] is DateTime
                  ? json['exitTime']
                  : DateTime.parse(json['exitTime']))
              : null,
      duration: json['duration']?.toDouble(),
      amount: json['amount']?.toDouble(),
      status: json['status'],
      paymentId: json['paymentId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parkingSpotId': parkingSpotId,
      'spotNumber': spotNumber,
      'spotSection': spotSection,
      'spotFloor': spotFloor,
      'userId': userId,
      'plateNumber': plateNumber,
      'plateImageUrl': plateImageUrl,
      'entryTime': entryTime.toIso8601String(),
      'exitTime': exitTime?.toIso8601String(),
      'duration': duration,
      'amount': amount,
      'status': status,
      'paymentId': paymentId,
    };
  }
}
