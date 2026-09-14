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
  // Add other properties as needed

  Load(
      {this.id,
      this.customerId, // Change this
      this.driverId,
      this.customerName,
      required this.description,
      required this.weight,
      required this.pickupLocation,
      required this.deliveryLocation,
      required this.status});

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
    };
  }
}
