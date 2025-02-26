class ParkingSpot {
  final String id;
  final String number;
  final String section;
  final int floor;
  final String status; // 'available', 'occupied', 'reserved', 'maintenance'
  final String? userId;
  final String? plateNumber;
  final DateTime? entryTime;
  final DateTime? reservationTime;
  final DateTime createdAt;

  ParkingSpot({
    required this.id,
    required this.number,
    required this.section,
    required this.floor,
    required this.status,
    this.userId,
    this.plateNumber,
    this.entryTime,
    this.reservationTime,
    required this.createdAt,
  });

  factory ParkingSpot.fromJson(Map<String, dynamic> json) {
    return ParkingSpot(
      id: json['id'],
      number: json['number'],
      section: json['section'],
      floor: json['floor'],
      status: json['status'],
      userId: json['userId'],
      plateNumber: json['plateNumber'],
      entryTime:
          json['entryTime'] != null ? DateTime.parse(json['entryTime']) : null,
      reservationTime:
          json['reservationTime'] != null
              ? DateTime.parse(json['reservationTime'])
              : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'section': section,
      'floor': floor,
      'status': status,
      'userId': userId,
      'plateNumber': plateNumber,
      'entryTime': entryTime?.toIso8601String(),
      'reservationTime': reservationTime?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
