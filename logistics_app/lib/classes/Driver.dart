class Driver {
  final int? id;
  final String username;
  final String password;
  final String email;
  final String name;
  final String lastName;
  final String address;
  final String licenseNumber;
  final String nextOfKin;
  final String nextOfKinContact;
  final String mobileNumber;
  final String idNumber;

  // Add other driver-related fields as needed

  Driver(
      {this.id,
      required this.name,
      required this.email,
      required this.username,
      required this.password,
      required this.lastName,
      required this.address,
      required this.licenseNumber,
      required this.idNumber,
      required this.mobileNumber,
      required this.nextOfKin,
      required this.nextOfKinContact});

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
        id: json['id'],
        name: json['name'],
        username: json['username'],
        password: json['password'],
        email: json['email'],
        lastName: json['lastName'],
        address: json['address'],
        licenseNumber: json['licenseNumber'],
        idNumber: json['idNumber'],
        mobileNumber: json['mobileNumber'],
        nextOfKin: json['nextOfKin'],
        nextOfKinContact: json['nextOfKinContact']);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'username': username,
        'password': password,
        'email': email,
        'lastName': lastName,
        'address': address,
        'licenseNumber': licenseNumber,
        'mobileNumber': mobileNumber,
        'nextOfKin': nextOfKin,
        'nextOfKinContact': nextOfKinContact,
        'idNumber': idNumber,
      };
}
