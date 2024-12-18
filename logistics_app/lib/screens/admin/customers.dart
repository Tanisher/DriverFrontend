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
