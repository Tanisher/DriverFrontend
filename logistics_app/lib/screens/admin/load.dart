import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:icons_plus/icons_plus.dart';
import 'package:logistics_app/classes/Customer.dart';
import 'package:logistics_app/classes/Driver.dart';
import 'package:logistics_app/classes/Fault.dart';
import 'package:logistics_app/classes/Load.dart';
import 'package:logistics_app/classes/vehicle.dart';
import 'package:logistics_app/service/auth_service.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart'; // For date formatting

//Load section


class LoadsPage extends StatefulWidget {
  @override
  _LoadsPageState createState() => _LoadsPageState();
}

class _LoadsPageState extends State<LoadsPage> {
  final AuthService _authService = AuthService();
  Map<int, String> customerNames = {};
  List<Load> loads = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchLoadsAndCustomers(); // Change this from fetchLoads()
  }

  //fetch Customers
  Future<void> _fetchLoadsAndCustomers() async {
    try {
      // Fetch customers first
      final customers = await _fetchCustomers();

      // Use null-aware operator and ensure non-null keys
      customerNames = {
        for (var customer in customers)
          if (customer.id != null) customer.id!: customer.name
      };

      // Use existing fetchLoads method instead of non-existent _fetchLoads
      await fetchLoads();
    } catch (e) {
      print('Error in _fetchLoadsAndCustomers: $e');
    }
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

      print('Create Load Request Body: ${json.encode(load.toJson())}');
      print('Create Load Response Status: ${response.statusCode}');
      print('Create Load Response Body: ${response.body}');

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
    final TextEditingController pickupLocationController =
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
                          controller: pickupLocationController,
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
                      customerId: selectedCustomer!.id!, //using the actual Id
                      description: descriptionController.text,
                      weight: weightController.text,
                      pickupLocation: pickupLocationController.text,
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
                      title: Text(
                          customerNames[load.customerId] ?? 'Unknown Customer'),
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