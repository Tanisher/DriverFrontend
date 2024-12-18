// Customer page
class Customer {
  final int? id;
  final String name;
  final String email;
  final String contact;
  final String address;

  Customer({
    this.id,
    required this.name,
    required this.email,
    required this.address,
    required this.contact,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      contact: json['contact'] ?? '',
      address: json['address'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'contact': contact,
        'address': address,
      };
}