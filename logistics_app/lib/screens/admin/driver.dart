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

//Drivers Section

class DriversPage extends StatefulWidget {
  @override
  _DriversPageState createState() => _DriversPageState();
}

class _DriversPageState extends State<DriversPage> {
  final AuthService _authService = AuthService();
  List<Driver> drivers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
  }

  Future<void> _fetchDrivers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String? token = await _authService.getToken();
      final response = await http.get(
        Uri.parse('http://192.168.32.85:8080/api/drivers'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> driverJson = json.decode(response.body);
        setState(() {
          drivers = driverJson.map((json) => Driver.fromJson(json)).toList();
        });
      } else {
        _showErrorSnackBar('Failed to load drivers');
      }
    } catch (e) {
      _showErrorSnackBar('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addDriver() async {
    // Open a dialog to input driver details
    final result = await showDialog<Driver>(
      context: context,
      builder: (context) => _DriverInputDialog(),
    );

    if (result != null) {
      try {
        String? token = await _authService.getToken();
        final response = await http.post(
          Uri.parse('http://192.168.32.85:8080/api/drivers'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json'
          },
          body: json.encode(result.toJson()),
        );

        print('Create driver Response Status: ${response.statusCode}');
        print('Create driver Response Body: ${response.body}');

        if (response.statusCode == 200) {
          _fetchDrivers(); // Refresh the list
          _showSuccessSnackBar('Driver added successfully');
        } else {
          _showErrorSnackBar('Failed to add driver');
        }
      } catch (e) {
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    }
  }

  Future<void> _deleteDriver(int driverId) async {
    try {
      String? token = await _authService.getToken();
      final response = await http.delete(
        Uri.parse('http://192.168.32.85:8080/api/drivers/$driverId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 204) {
        _fetchDrivers(); // Refresh the list
        _showSuccessSnackBar('Driver deleted successfully');
      } else {
        _showErrorSnackBar('Failed to delete driver');
      }
    } catch (e) {
      _showErrorSnackBar('Error: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Drivers Management'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : drivers.isEmpty
              ? Center(child: Text('No drivers found'))
              : ListView.builder(
                  itemCount: drivers.length,
                  itemBuilder: (context, index) {
                    final driver = drivers[index];
                    return ListTile(
                      title: Text(driver.name),
                      subtitle: Text(driver.lastName),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => _deleteDriver(driver.id!),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDriver,
        child: Icon(Icons.add),
      ),
    );
  }
}

class _DriverInputDialog extends StatefulWidget {
  @override
  _DriverInputDialogState createState() => _DriverInputDialogState();
}

class _DriverInputDialogState extends State<_DriverInputDialog> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _nextOfKinController = TextEditingController();
  final _nextOfKinContactController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _idNumberController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add New Driver'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _lastNameController,
            decoration: InputDecoration(
              labelText: 'last name',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: 'user name',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'address',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _licenseNumberController,
            decoration: InputDecoration(
              labelText: 'license Number',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _nextOfKinController,
            decoration: InputDecoration(
              labelText: 'Next of Kin',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _nextOfKinContactController,
            decoration: InputDecoration(
              labelText: 'next of kin Contact',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _mobileNumberController,
            decoration: InputDecoration(
              labelText: 'mobile number',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _idNumberController,
            decoration: InputDecoration(
              labelText: 'ID Number',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty &&
                _nameController.text.isNotEmpty) {
              final newDriver = Driver(
                name: _nameController.text,
                lastName: _lastNameController.text,
                username: _usernameController.text,
                password: _passwordController.text,
                email: _emailController.text,
                address: _addressController.text,
                licenseNumber: _licenseNumberController.text,
                nextOfKin: _nextOfKinController.text,
                nextOfKinContact: _nextOfKinContactController.text,
                mobileNumber: _mobileNumberController.text,
                idNumber: _idNumberController.text,
              );
              Navigator.of(context).pop(newDriver);
            }
          },
          child: Text('Add'),
        ),
      ],
    );
  }
}