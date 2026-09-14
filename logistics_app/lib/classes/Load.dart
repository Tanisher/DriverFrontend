// Load model to match backend
class Load {
  final int? id;
  final int? customerId; // Instead of Customer customer
  final int? driverId;
  final String? customerName;
  final String description;
  final String weight;
  final String pickupLocation;
  final String deliveryLocation;
  final String status;
  final String cargoType;
  final String actualWeight;

  Load(
      {this.id,
      this.customerId, // Change this
      this.driverId,
      this.customerName,
      required this.description,
      required this.weight,
      required this.pickupLocation,
      required this.deliveryLocation,
      required this.status,
      this.cargoType = '',
      this.actualWeight = ''});

  String get _cargoToken =>
      cargoType.toUpperCase().replaceAll('-', '_').trim();

  bool get isBulk => _cargoToken == 'BULK';

  bool get isBagged => _cargoToken == 'BAGGED';

  bool get hasActualWeight =>
      actualWeight.isNotEmpty && actualWeight != 'null';

  bool get needsWeighbridge => isBulk && !hasActualWeight;

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  factory Load.fromJson(Map<String, dynamic> json) {
    int? nestedCustomerId;
    String? nestedCustomerName;
    final customer = json['customer'];
    if (customer is Map) {
      nestedCustomerId = _asInt(customer['id']);
      nestedCustomerName = customer['name']?.toString();
    }

    int? nestedDriverId;
    final driver = json['driver'];
    if (driver is Map) {
      nestedDriverId = _asInt(driver['id']);
    }

    return Load(
      id: _asInt(json['id']),
      customerId: _asInt(json['customerId']) ?? nestedCustomerId,
      driverId: _asInt(json['driverId']) ?? nestedDriverId,
      customerName: json['customerName']?.toString() ?? nestedCustomerName,
      description: json['description']?.toString() ?? '',
      weight: json['weight']?.toString() ?? '',
      pickupLocation: json['pickupLocation']?.toString() ?? '',
      deliveryLocation: json['deliveryLocation']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      cargoType: (json['cargoType'] ??
              json['cargo_type'] ??
              json['loadType'] ??
              '')
          .toString(),
      actualWeight: (json['actualWeight'] ?? json['actual_weight'] ?? '')
          .toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId, // Send only the customer ID directly
      'description': description,
      'weight': weight,
      'pickupLocation': pickupLocation,
      'deliveryLocation': deliveryLocation,
      'status': status,
      if (cargoType.isNotEmpty) 'cargoType': cargoType,
      if (actualWeight.isNotEmpty) 'actualWeight': actualWeight,
    };
  }

  Load copyWith({
    int? id,
    int? customerId,
    int? driverId,
    String? customerName,
    String? description,
    String? weight,
    String? pickupLocation,
    String? deliveryLocation,
    String? status,
    String? cargoType,
    String? actualWeight,
  }) {
    return Load(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      driverId: driverId ?? this.driverId,
      customerName: customerName ?? this.customerName,
      description: description ?? this.description,
      weight: weight ?? this.weight,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      status: status ?? this.status,
      cargoType: cargoType ?? this.cargoType,
      actualWeight: actualWeight ?? this.actualWeight,
    );
  }
}
