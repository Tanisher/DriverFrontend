// Load model to match backend
class Load {
  final int? id;
  final int? customerId; // Instead of Customer customer
  final String description;
  final String weight;
  final String pickupLocation;
  final String deliveryLocation;
  final String status;
  // Add other properties as needed

  Load(
      {this.id,
      this.customerId, // Change this
      required this.description,
      required this.weight,
      required this.pickupLocation,
      required this.deliveryLocation,
      required this.status});

  factory Load.fromJson(Map<String, dynamic> json) {
    return Load(
      id: json['id'],
      customerId: json['customerId'], // Receive the ID
      description: json['description'],
      weight: json['weight'],
      pickupLocation: json['pickupLocation'],
      deliveryLocation: json['deliveryLocation'],
      status: json['status'], // Adjust based on your actual Load properties
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
