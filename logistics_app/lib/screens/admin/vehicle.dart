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
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart'; // For date formatting
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';



//vehicle section
class VehiclesPage extends StatefulWidget {
  @override
  _VehiclesPageState createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  final AuthService _authService = AuthService();
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://192.168.32.85:8080/api/vehicles'));
  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
    _initializeWebSocket();
  }

  void _initializeWebSocket() async {
    try {
      // Retrieve JWT token
      String? token = await _authService.getToken();
      
      // Create WebSocket connection with token
      _channel = IOWebSocketChannel.connect(
        Uri.parse('ws://192.168.32.85:8080/ws'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      // Listen for messages
      _channel?.stream.listen(
        (message) {
          try {
            final data = json.decode(message);
            final vehicleId = data['vehicleId'];
            final latitude = data['latitude'];
            final longitude = data['longitude'];

            setState(() {
              final vehicleIndex = _vehicles.indexWhere((v) => v.id == vehicleId);
              if (vehicleIndex != -1) {
                _vehicles[vehicleIndex].latitude = latitude;
                _vehicles[vehicleIndex].longitude = longitude;
              }
            });
          } catch (e) {
            print('Error parsing WebSocket message: $e');
          }
        },
        onDone: () {
          print('WebSocket connection closed');
        },
        onError: (error) {
          print('WebSocket error: $error');
        },
      );
    } catch (e) {
      print('Error initializing WebSocket: $e');
    }
  }

  @override
  void dispose() {
    // Close the WebSocket connection
    _channel?.sink.close();
    super.dispose();
  }


  Future<void> _fetchVehicles() async {
    setState(() => _isLoading = true);
    try {
      String? token = await _authService.getToken();
      final response = await _dio.get(
        '', // Assuming the endpoint is directly under the baseUrl
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        setState(() {
          _vehicles = (response.data as List)
              .map((vehicleJson) => Vehicle.fromJson(vehicleJson))
              .toList();
        });
      } else {
        _showErrorSnackBar('Failed to fetch vehicles. Status code: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to fetch vehicles');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addVehicle() async {
    final vehicle = await _showVehicleDialog();
    if (vehicle != null) {
      try {
        String? token = await _authService.getToken();
        final response = await _dio.post('',
        options: Options(
          headers: {
            'Authorization':'Bearer $token',
          }
        ), data: vehicle.toJson());
        // If the response is successful, add the new vehicle to the list
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _vehicles.add(Vehicle.fromJson(response.data));
        });
      } else {
        _showErrorSnackBar('Failed to add vehicle. Status code: ${response.statusCode}');
      }
      } catch (e) {
        _showErrorSnackBar('Failed to add vehicle');
      }
    }
  }

  Future<void> _updateVehicle(Vehicle vehicle) async {
  final updatedVehicle = await _showVehicleDialog(vehicle: vehicle);
  
  if (updatedVehicle != null) {
    try {
      // Get the token from AuthService
      String? token = await _authService.getToken();

      // Make the PUT request to update the vehicle
      final response = await _dio.put(
        '/${vehicle.id}',  // Assuming the vehicle id is part of the URL
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
        data: updatedVehicle.toJson(), // Send the updated vehicle data as JSON
      );

      // Update the vehicle in the list if successful
      if (response.statusCode == 200) {
        setState(() {
          final index = _vehicles.indexWhere((v) => v.id == vehicle.id);
          if (index != -1) {
            _vehicles[index] = Vehicle.fromJson(response.data);  // Update the list
          }
        });
      } else {
        _showErrorSnackBar('Failed to update vehicle. Status code: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to update vehicle');
    }
  }
}


  Future<void> _deleteVehicle(int id) async {
  try {
    // Get the token from AuthService
    String? token = await _authService.getToken();

    // Perform the DELETE request
    final response = await _dio.delete(
      '/$id',  // Assuming vehicle ID is part of the URL
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    // Check the response status before updating the list
    if (response.statusCode == 200 || response.statusCode == 204) {
      setState(() {
        _vehicles.removeWhere((vehicle) => vehicle.id == id);  // Remove vehicle from list
      });
    } else {
      _showErrorSnackBar('Failed to delete vehicle. Status code: ${response.statusCode}');
    }
  } catch (e) {
    _showErrorSnackBar('Failed to delete vehicle');
  }
}


  Future<List<Fault>> _fetchVehicleFaults(int vehicleId) async {
  try {
    // Get the token from AuthService
    String? token = await _authService.getToken();

    // Perform the GET request to fetch vehicle faults
    final response = await _dio.get(
      '/$vehicleId/faults',  // Assuming the URL includes vehicleId
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    // Check if the response is successful
    if (response.statusCode == 200) {
      // Map the data into a list of Fault objects
      return (response.data as List)
          .map((faultJson) => Fault.fromJson(faultJson))
          .toList();
    } else {
      _showErrorSnackBar('Failed to fetch vehicle faults. Status code: ${response.statusCode}');
      return [];
    }
  } catch (e) {
    _showErrorSnackBar('Failed to fetch vehicle faults');
    return [];
  }
}

 Future<void> _assignDriverToVehicle(Vehicle vehicle) async {
    // Fetch list of available drivers
    List<Driver> availableDrivers = await _fetchAvailableDrivers();

    // Show a dialog to select a driver
    Driver? selectedDriver = await showDialog<Driver>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Driver to ${vehicle.make} ${vehicle.model}'),
        content: SingleChildScrollView(
          child: ListBody(
            children: availableDrivers.map((driver) => 
              ListTile(
                title: Text('${driver.name} ${driver.lastName}'),
                subtitle: Text(driver.licenseNumber),
                onTap: () => Navigator.of(context).pop(driver),
              )
            ).toList(),
          ),
        ),
      ),
    );

    // If a driver is selected, update the vehicle
    if (selectedDriver != null) {
      try {
        String? token = await _authService.getToken();
        final response = await _dio.put(
          '/${vehicle.id}/assign-driver',
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
            },
          ),
          data: {
            'driverId': selectedDriver.id,
          },
        );

        if (response.statusCode == 200) {
          // Update the local state
          setState(() {
            final index = _vehicles.indexWhere((v) => v.id == vehicle.id);
            if (index != -1) {
              _vehicles[index] = Vehicle.fromJson(response.data);
            }
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Driver assigned successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          _showErrorSnackBar('Failed to assign driver');
        }
      } catch (e) {
        _showErrorSnackBar('Error assigning driver');
      }
    }
  }

  // Method to fetch available drivers
  Future<List<Driver>> _fetchAvailableDrivers() async {
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
      // Decode the response body as JSON
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((driverJson) => Driver.fromJson(driverJson)).toList();
    } else {
      throw Exception('Failed to fetch available drivers');
    }
  } catch (e) {
    print('Error fetching available drivers: $e');
    return [];
  }
}


  Future<Vehicle?> _showVehicleDialog({Vehicle? vehicle}) async {
    final licensePlateController = TextEditingController(text: vehicle?.licensePlate ?? '');
    final makeController = TextEditingController(text: vehicle?.make ?? '');
    final modelController = TextEditingController(text: vehicle?.model ?? '');
    final yearController = TextEditingController(
      text: vehicle?.year != null ? vehicle!.year.toString() : '',
    );
    final colorController = TextEditingController(text: vehicle?.color ?? '');
    
    DateTime? selectedServiceDate = vehicle?.lastServiceDate;
    bool isActive = vehicle?.active ?? true;

    return await showDialog<Vehicle>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(vehicle == null ? 'Add Vehicle' : 'Edit Vehicle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: licensePlateController,
                  decoration: InputDecoration(labelText: 'License Plate'),
                ),
                TextField(
                  controller: makeController,
                  decoration: InputDecoration(labelText: 'Make'),
                ),
                TextField(
                  controller: modelController,
                  decoration: InputDecoration(labelText: 'Model'),
                ),
                TextField(
                  controller: yearController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Year'),
                ),
                TextField(
                  controller: colorController,
                  decoration: InputDecoration(labelText: 'Color'),
                ),
                Row(
                  children: [
                    Text('Last Service Date:'),
                    TextButton(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedServiceDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            selectedServiceDate = pickedDate;
                          });
                        }
                      },
                      child: Text(
                        selectedServiceDate != null
                            ? DateFormat('yyyy-MM-dd').format(selectedServiceDate!)
                            : 'Select Date',
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: Text('Active'),
                  value: isActive,
                  onChanged: (bool value) {
                    setState(() {
                      isActive = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newVehicle = Vehicle(
                  id: vehicle?.id,
                  licensePlate: licensePlateController.text,
                  make: makeController.text,
                  model: modelController.text,
                  year: int.parse(yearController.text),
                  color: colorController.text,
                  active: isActive,
                  lastServiceDate: selectedServiceDate,
                );
                Navigator.of(context).pop(newVehicle);
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showVehicleFaultsDialog(Vehicle vehicle) async {
    String? token = await _authService.getToken();
    final faults = await _fetchVehicleFaults(vehicle.id!);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Faults for ${vehicle.make}'),
        content: faults.isEmpty
            ? Text('No faults found')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: faults.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(faults[index].description),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vehicles Management'),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = _vehicles[index];
                return Card(
                  child: ListTile(
                    title: Text('${vehicle.make} ${vehicle.model} (${vehicle.licensePlate})'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Year: ${vehicle.year}, Color: ${vehicle.color}'),
                        Text('Status: ${vehicle.active ? 'Active' : 'Inactive'}'),
                        if (vehicle.lastServiceDate != null)
                          Text('Last Service: ${DateFormat('yyyy-MM-dd').format(vehicle.lastServiceDate!)}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () => _updateVehicle(vehicle),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => _deleteVehicle(vehicle.id!),
                        ),
                         IconButton(
                           icon: Icon(Icons.person_add),
                           onPressed: () => _assignDriverToVehicle(vehicle),
                           tooltip: 'Assign Driver',
                        ),
                        if (vehicle.faults != null && vehicle.faults!.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.warning, color: Colors.red),
                            onPressed: () => _showVehicleFaultsDialog(vehicle),
                          ),
                          
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addVehicle,
        child: Icon(Icons.add),
      ),
    );
  }
}



