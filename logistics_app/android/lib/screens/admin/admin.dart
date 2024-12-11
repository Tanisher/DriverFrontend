import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:icons_plus/icons_plus.dart';
import 'package:logistics_app/service/auth_service.dart';

class AdminDashboardApp extends StatelessWidget {
  const AdminDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AdminDashboard(),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // Define dashboard sections
  final List<DashboardSection> sections = [
    DashboardSection(
      title: 'Customers',
      icon: Icons.people,
      page: CustomersPage(),
    ),
    DashboardSection(
      title: 'Loads',
      icon: Icons.local_shipping_rounded,
      page: LoadsPage(),
    ),
    DashboardSection(
      title: 'Drivers',
      icon: Icons.local_shipping,
      page: DriversPage(),
    ),
    DashboardSection(
      title: 'Vehicles',
      icon: Icons.directions_car,
      page: VehiclesPage(),
    ),
    DashboardSection(
      title: 'Trailers',
      icon: Icons.view_in_ar,
      page: TrailersPage(),
    ),
    DashboardSection(
      title: 'Orders',
      icon: Icons.list_alt,
      page: OrdersPage(),
    ),
  ];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
      ),
      body: Row(
        children: [
          // Sidebar Navigation
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: sections.map((section) {
              return NavigationRailDestination(
                icon: Icon(section.icon),
                label: Text(section.title),
              );
            }).toList(),
          ),

          // Vertical divider
          VerticalDivider(thickness: 1, width: 1),

          // Main Content Area
          Expanded(
            child: sections[_selectedIndex].page,
          ),
        ],
      ),
    );
  }
}

// Data class to represent dashboard sections
class DashboardSection {
  final String title;
  final IconData icon;
  final Widget page;

  DashboardSection({
    required this.title,
    required this.icon,
    required this.page,
  });
}

// Placeholder Pages for each section
// Customer page
class Customer {
  final int? id;
  final String name;
  final String email;
  final String contact;
  final String address;
  final String numberOfLoads;

  Customer({
    this.id,
    required this.name,
    required this.email,
    required this.address,
    required this.contact,
    required this.numberOfLoads,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      contact: json['contact'] ?? '',
      address: json['address'] ?? '',
      numberOfLoads: json['numberOfLoads'] ?? '0',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'contact': contact,
        'address': address,
        'numberOfLoads': numberOfLoads
      };
}

class CustomersPage extends StatefulWidget {
  @override
  _CustomersPageState createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final AuthService _authService = AuthService();
  List<Customer> _customers = [];
  // IMPORTANT: Replace with your actual backend URL
  final _baseUrl = 'http://192.168.32.85:8080/api/customers';

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  // Improved fetch customers method with better error handling
  Future<void> _fetchCustomers() async {
    try {
      // Retrieve the token from authService
      String? token = await _authService.getToken();

      if (token == null) {
        _showErrorDialog('Authentication token is missing');
        return;
      }

      print('Fetching customers from: $_baseUrl');
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        setState(() {
          _customers =
              body.map((dynamic item) => Customer.fromJson(item)).toList();
        });

        if (_customers.isEmpty) {
          _showErrorDialog('No customers found');
        }
      } else {
        _showErrorDialog(
            'Failed to load customers. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Detailed Fetch Error: $e');
      _showErrorDialog('Network Error: ${e.toString()}');
    }
  }

  // Create a new customer
  Future<void> _showAddCustomerDialog() async {
    final _nameController = TextEditingController();
    final _emailController = TextEditingController();
    final _contactController = TextEditingController();
    final _addressController = TextEditingController();
    final _numberOfLoads = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add New Customer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(hintText: 'Customer Name'),
              ),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(hintText: 'Customer Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(hintText: 'Customer Address'),
              ),
              TextField(
                controller: _contactController,
                decoration: InputDecoration(hintText: 'Customer Contact'),
              ),
              TextField(
                controller: _numberOfLoads,
                decoration: InputDecoration(hintText: 'Customer Loads'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Add'),
              onPressed: () {
                _createCustomer(
                  Customer(
                    name: _nameController.text,
                    email: _emailController.text,
                    contact: _contactController.text,
                    address: _addressController.text,
                    numberOfLoads: _numberOfLoads.text,
                  ),
                );
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Create customer API call
  Future<void> _createCustomer(Customer customer) async {
    try {
      String? token = await _authService.getToken();

      if (token == null) {
        _showErrorDialog('Authentication token is missing');
        return;
      }

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(customer.toJson()),
      );

      print('Create Customer Response Status: ${response.statusCode}');
      print('Create Customer Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _fetchCustomers(); // Refresh list
        _showSuccessDialog('Customer added successfully');
      } else {
        _showErrorDialog(
            'Failed to add customer. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Detailed Create Customer Error: $e');
      _showErrorDialog('Network Error: ${e.toString()}');
    }
  }

  bool _validateCustomer(Customer customer) {
    if (customer.name.isEmpty) {
      _showErrorDialog('Customer name is required');
      return false;
    }
    if (customer.email.isEmpty || !customer.email.contains('@')) {
      _showErrorDialog('Valid email is required');
      return false;
    }
    return true;
  }

  // Get customer by ID
  Future<void> _showCustomerDetails(int id) async {
    try {
      String? token = await _authService.getToken();

      if (token == null) {
        _showErrorDialog('Authentication token is missing');
        return;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final customer = Customer.fromJson(json.decode(response.body));

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Customer Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID: ${customer.id}'),
                  Text('Name: ${customer.name}'),
                  Text('Email: ${customer.email}'),
                  Text('Contact: ${customer.contact}'),
                  Text('Address: ${customer.address}'),
                  Text('Number of Loads: ${customer.numberOfLoads}'),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      } else {
        _showErrorDialog('Failed to fetch customer details');
      }
    } catch (e) {
      _showErrorDialog('Error: ${e.toString()}');
    }
  }

  // Delete customer
  Future<void> _deleteCustomer(int id) async {
    try {
      String? token = await _authService.getToken();

      if (token == null) {
        _showErrorDialog('Authentication token is missing');
        return;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Remove the customer from the list
        setState(() {
          _customers.removeWhere((customer) => customer.id == id);
        });
        _showSuccessDialog('Customer deleted successfully');
      } else {
        _showErrorDialog('Failed to delete customer');
      }
    } catch (e) {
      _showErrorDialog('Error: ${e.toString()}');
    }
  }

  // Success dialog
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Success'),
          content: Text(message),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Customers Management'),
      ),
      body: _customers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Loading customers or no customers found')
                ],
              ),
            )
          : ListView.builder(
              itemCount: _customers.length,
              itemBuilder: (context, index) {
                final customer = _customers[index];
                return ListTile(
                  title: Text(customer.name),
                  subtitle: Text(customer.email),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove_red_eye),
                        onPressed: () => _showCustomerDetails(customer.id!),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => _deleteCustomer(customer.id!),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomerDialog,
        child: Icon(Icons.add),
      ),
    );
  }
}

//Load section

// Load model to match backend
class Load {
  final int? id;
  final String customer;
  final String description;
  final String weight;
  final String pickUpLocation;
  final String deliveryLocation;
  final String status;
  // Add other properties as needed

  Load(
      {this.id,
      required this.customer,
      required this.description,
      required this.weight,
      required this.pickUpLocation,
      required this.deliveryLocation,
      required this.status});

  factory Load.fromJson(Map<String, dynamic> json) {
    return Load(
      id: json['id'],
      customer: json['customer'],
      description: json['description'],
      weight: json['weight'],
      pickUpLocation: json['pickUpLocation'],
      deliveryLocation: json['deliveryLocation'],
      status: json['status'], // Adjust based on your actual Load properties
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer': customer,
      'description': description,
      'weight': weight,
      'pickUpLocation': pickUpLocation,
      'deliveryLocation': deliveryLocation,
      'status': status,
      // Add other properties
    };
  }
}

class LoadsPage extends StatefulWidget {
  @override
  _LoadsPageState createState() => _LoadsPageState();
}

class _LoadsPageState extends State<LoadsPage> {
  final AuthService _authService = AuthService();
  List<Load> loads = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchLoads();
  }

  // Fetch all loads
  Future<void> fetchLoads() async {
    try {
      String? token = await _authService.getToken();

      final response = await http.get(
        Uri.parse('http://192.168.32.85:8080/api/loads'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> loadJson = json.decode(response.body);
        setState(() {
          loads = loadJson.map((json) => Load.fromJson(json)).toList();
        });
      } else {
        _showErrorSnackBar('Failed to load loads');
      }
    } catch (e) {
      _showErrorSnackBar('Error fetching loads: ${e.toString()}');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Create a new load
  Future<void> createLoad(Load load) async {
    try {
      String? token = await _authService.getToken();

      final response = await http.post(
        Uri.parse('http://192.168.32.85:8080/api/loads'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(load.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final newLoad = Load.fromJson(json.decode(response.body));
        setState(() {
          loads.add(newLoad);
        });
        _showSuccessSnackBar('Load created successfully');
      } else {
        _showErrorSnackBar('Failed to create load');
      }
    } catch (e) {
      _showErrorSnackBar('Error creating load: ${e.toString()}');
    }
  }

  // Delete a load
  Future<void> deleteLoad(int loadId) async {
    try {
      String? token = await _authService.getToken();
      final response = await http.delete(
        Uri.parse('http://192.168.32.85:8080/api/loads/$loadId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          loads.removeWhere((load) => load.id == loadId);
        });
        _showSuccessSnackBar('Load deleted successfully');
      } else {
        _showErrorSnackBar('Failed to delete load');
      }
    } catch (e) {
      _showErrorSnackBar('Error deleting load: ${e.toString()}');
    }
  }

  //fetch all customers
  Future<List<Customer>> _fetchCustomers() async {
    try {
      String? token = await _authService.getToken();
      final response = await http.get(
        Uri.parse('http://192.168.32.85:8080/api/customers'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        return body.map((dynamic item) => Customer.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load customers');
      }
    } catch (e) {
      print('Error fetching customers: $e');
      return [];
    }
  }

  // Show load creation dialog
  void _showAddLoadDialog() {
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController weightController = TextEditingController();
    final TextEditingController pickUpLocationController =
        TextEditingController();
    final TextEditingController deliveryLocationController =
        TextEditingController();
    final TextEditingController statusController = TextEditingController();

    Customer? selectedCustomer;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add New Load'),
              content: FutureBuilder<List<Customer>>(
                future: _fetchCustomers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Text('No customers available');
                  }

                  // Remove duplicate customers based on ID
                  List<Customer> customers = snapshot.data!
                      .toSet() // Remove duplicates
                      .toList();

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<int>(
                          // Change to use customer ID
                          value: selectedCustomer?.id,
                          hint: Text('Select Customer'),
                          items: customers.map((Customer customer) {
                            return DropdownMenuItem<int>(
                              value: customer.id,
                              child: Text(customer.name),
                            );
                          }).toList(),
                          onChanged: (int? newCustomerId) {
                            setState(() {
                              // Find the full customer object by ID
                              selectedCustomer = customers.firstWhere(
                                  (customer) => customer.id == newCustomerId);
                            });
                          },
                          validator: (value) =>
                              value == null ? 'Please select a customer' : null,
                        ),
                        TextField(
                          controller: descriptionController,
                          decoration:
                              InputDecoration(hintText: 'Load Description'),
                        ),
                        TextField(
                          controller: weightController,
                          decoration: InputDecoration(hintText: 'Weight'),
                          keyboardType: TextInputType.number,
                        ),
                        TextField(
                          controller: pickUpLocationController,
                          decoration:
                              InputDecoration(hintText: 'Pickup Location'),
                        ),
                        TextField(
                          controller: deliveryLocationController,
                          decoration:
                              InputDecoration(hintText: 'Delivery Location'),
                        ),
                        TextField(
                          controller: statusController,
                          decoration: InputDecoration(hintText: 'Status'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: Text('Add Load'),
                  onPressed: () {
                    if (selectedCustomer == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please select a customer')),
                      );
                      return;
                    }

                    // Create and add the load
                    final newLoad = Load(
                      customer: selectedCustomer!.name, // Use customer name
                      description: descriptionController.text,
                      weight: weightController.text,
                      pickUpLocation: pickUpLocationController.text,
                      deliveryLocation: deliveryLocationController.text,
                      status: statusController.text,
                    );

                    createLoad(newLoad);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Utility method to show success snackbar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Utility method to show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Load Management'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : loads.isEmpty
              ? Center(child: Text('No loads found'))
              : ListView.builder(
                  itemCount: loads.length,
                  itemBuilder: (context, index) {
                    final load = loads[index];
                    return ListTile(
                      title: Text(load.customer),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => deleteLoad(load.id!),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddLoadDialog,
        child: Icon(Icons.add),
      ),
    );
  }
}

//Drivers Section

class DriversPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Drivers Management',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Add driver functionality
              },
              child: Text('Add Driver'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new driver
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

//vehicle section

class VehiclesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Vehicles Management',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Add vehicle functionality
              },
              child: Text('Add Vehicle'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new vehicle
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

//trailers section

class TrailersPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Trailers Management',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Add trailer functionality
              },
              child: Text('Add Trailer'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new trailer
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

//orders Serction

class OrdersPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Orders Management',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Add order functionality
              },
              child: Text('Create Order'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Create new order
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
