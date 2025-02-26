class VehicleModel {
  final String id;
  final String userId;
  final String plateNumber;
  final String brand;
  final String model;
  final String color;
  final DateTime createdAt;

  VehicleModel({
    required this.id,
    required this.userId,
    required this.plateNumber,
    required this.brand,
    required this.model,
    required this.color,
    required this.createdAt,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'],
      userId: json['userId'],
      plateNumber: json['plateNumber'],
      brand: json['brand'],
      model: json['model'],
      color: json['color'],
      createdAt:
          json['createdAt'] != null
              ? (json['createdAt'] is DateTime
                  ? json['createdAt']
                  : DateTime.parse(json['createdAt']))
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'plateNumber': plateNumber,
      'brand': brand,
      'model': model,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
