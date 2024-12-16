import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:logistics_app/service/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart'; // Add this dependency

class Trip {
  final int? id;
  final DateTime dateTime;
  final String destination;
  final String startingMillage;
  final String endingMillage;
  final String fuelLitres;
  final String trailer1;
  final String trailer2;
  final String plateNumber;
  final int driverId;
  final int loadId;
  final int customerId;

  Trip({
    this.id,
    required this.dateTime,
    required this.destination,
    required this.startingMillage,
    required this.endingMillage,
    required this.fuelLitres,
    required this.trailer1,
    required this.trailer2,
    required this.plateNumber,
    required this.driverId,
    required this.loadId,
    required this.customerId,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'],
      dateTime: DateTime.parse(json['dateTime']),
      destination: json['destination'],
      startingMillage: json['startingMillage'].toString(),
      endingMillage: json['endingMillage'].toString(),
      fuelLitres: json['fuelLitres'].toString(),
      trailer1: json['trailer1'] ?? '',
      trailer2: json['trailer2'] ?? '',
      plateNumber: json['plateNumber'] ?? '',
      driverId: json['driver']['id'],
      loadId: json['load']['id'],
      customerId: json['customer']['id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dateTime': dateTime.toIso8601String(),
      'destination': destination,
      'startingMillage': startingMillage,
      'endingMillage': endingMillage,
      'fuelLitres': fuelLitres,
      'trailer1': trailer1,
      'trailer2': trailer2,
      'plateNumber': plateNumber,
      'driverId': driverId,
      'loadId': loadId,
      'customerId': customerId,
    };
  }
}

class DriverTripSheet extends StatefulWidget {
  const DriverTripSheet({Key? key}) : super(key: key);

  @override
  _DriverTripSheetState createState() => _DriverTripSheetState();
}

class _DriverTripSheetState extends State<DriverTripSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _driverID;
  late final String _baseUrl;

  final AuthService _authService = AuthService();

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _vehicleRegController = TextEditingController();
  final TextEditingController _startingMileageController =
      TextEditingController();
  final TextEditingController _endingMileageController =
      TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _dieselLitresController = TextEditingController();
  final TextEditingController _trailersController = TextEditingController();

  List<Trip> _trips = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeDriverInfo();
  }

  // Manually add debug information
  Future<void> _initializeDriverInfo() async {
    try {
      final token = await _authService.getToken();
      print('Current Token: $token');

      final userId = await _authService.getCurrentUserId();
      print('Extracted User ID for API: $userId');

      if (userId == null) {
        _showErrorSnackBar('Could not retrieve driver information');
        return;
      }

      setState(() {
        _driverID = userId;
        // Double-check your exact endpoint construction
        _baseUrl =
            'http://192.168.32.85:8080/api/driver-trips/driver/username/$_driverID';
      });

      print('Constructed API URL: $_baseUrl');

      await _fetchTrips();
    } catch (e) {
      print('Initialization Error: $e');
      _showErrorSnackBar('Error initializing driver information');
    }
  }

  Future<void> _fetchTrips() async {
    if (_driverID == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _authService.getToken();
      print('JWT Token being sent: $token'); // Detailed token logging

      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization':
              'Bearer $token', // Ensure 'Bearer ' prefix is correct
          'Content-Type': 'application/json', // Sometimes helpful to include
        },
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 204) {
        print('Welcome to the app');
      } else if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);

        setState(() {
          _trips = body.map((dynamic item) => Trip.fromJson(item)).toList();
        });
      } else {
        // More detailed error handling
        print('Failed to load trips. Status code: ${response.statusCode}');
        _showErrorSnackBar('Failed to load trips. Error: ${response.body}');
      }
    } catch (e) {
      print('Error in _fetchTrips: $e');
      _showErrorSnackBar('Error connecting to server: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addTrip() async {
    if (_driverID == null) {
      _showErrorSnackBar('Driver information not available');
      return;
    }

    if (_formKey.currentState!.validate()) {
      final newTrip = Trip(
        dateTime: DateTime.parse(_dateController.text),
        destination: _destinationController.text,
        startingMillage: _startingMileageController.text,
        endingMillage: _endingMileageController.text,
        fuelLitres: _dieselLitresController.text,
        trailer1: _trailersController.text, // Adjust as needed
        trailer2: '', // Add second trailer if applicable
        plateNumber: _vehicleRegController.text,
        driverId: int.parse(_driverID!), // Your current driver ID
        loadId: 1, // You'll need to handle load selection
        customerId: 1, // You'll need to handle customer selection
      );

      // Rest of the method remains the same

      setState(() {
        _isLoading = true;
      });

      try {
        // Get the JWT token for authorization
        final token = await _authService.getToken();

        final response = await http.post(
          Uri.parse('http://192.168.32.85:8080/api/driver-trips/create'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(newTrip.toJson()),
        );

        if (response.statusCode == 201) {
          await _fetchTrips();
          _resetForm();
        } else {
          _showErrorSnackBar('Failed to add trip');
        }
      } catch (e) {
        _showErrorSnackBar('Error connecting to server');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Reset form after adding trip
  void _resetForm() {
    _dateController.clear();
    _vehicleRegController.clear();
    _startingMileageController.clear();
    _endingMileageController.clear();
    _customerNameController.clear();
    _destinationController.clear();
    _dieselLitresController.clear();
    _trailersController.clear();
  }

  // Calculate kilometers traveled
  String _calculateKms(String start, String end) {
    if (start.isNotEmpty && end.isNotEmpty) {
      return (int.parse(end) - int.parse(start)).toString();
    }
    return '';
  }

  // Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Date selection method
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_driverID == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Driver's Trip Sheet"),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver's Trip Sheet"),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTrips,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Form for adding trips (which was missing in the previous snippet)
                Card(
                  child: Form(
                    key: _formKey,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Add your form fields here (date, vehicle reg, etc.)
                          // Similar to the controllers you've defined earlier
                          TextFormField(
                            controller: _dateController,
                            decoration: InputDecoration(
                              labelText: 'Date',
                              suffixIcon: IconButton(
                                icon: Icon(Icons.calendar_today),
                                onPressed: () => _selectDate(context),
                              ),
                            ),
                            validator: (value) =>
                                value!.isEmpty ? 'Please enter a date' : null,
                          ),
                          TextFormField(
                            controller: _vehicleRegController,
                            decoration: InputDecoration(
                              labelText: 'Vehicle Registration',
                            ),
                            validator: (value) => value!.isEmpty
                                ? 'Please enter vehicle registration'
                                : null,
                          ),

                          // Customer Name Field
                          TextFormField(
                            controller: _customerNameController,
                            decoration: InputDecoration(
                              labelText: 'Customer Name',
                            ),
                            validator: (value) => value!.isEmpty
                                ? 'Please enter customer name'
                                : null,
                          ),

                          // Destination Field
                          TextFormField(
                            controller: _destinationController,
                            decoration: InputDecoration(
                              labelText: 'Destination',
                            ),
                            validator: (value) => value!.isEmpty
                                ? 'Please enter destination'
                                : null,
                          ),

                          // Starting Mileage Field
                          TextFormField(
                            controller: _startingMileageController,
                            decoration: InputDecoration(
                              labelText: 'Starting Mileage',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value!.isEmpty)
                                return 'Please enter starting mileage';
                              if (int.tryParse(value) == null)
                                return 'Please enter a valid number';
                              return null;
                            },
                          ),

                          // Ending Mileage Field
                          TextFormField(
                            controller: _endingMileageController,
                            decoration: InputDecoration(
                              labelText: 'Ending Mileage',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value!.isEmpty)
                                return 'Please enter ending mileage';
                              if (int.tryParse(value) == null)
                                return 'Please enter a valid number';

                              // Optional: Validate that ending mileage is greater than starting mileage
                              final startMileage =
                                  int.tryParse(_startingMileageController.text);
                              final endMileage = int.tryParse(value);
                              if (startMileage != null &&
                                  endMileage != null &&
                                  endMileage <= startMileage) {
                                return 'Ending mileage must be greater than starting mileage';
                              }
                              return null;
                            },
                          ),

                          // Diesel Litres Field
                          TextFormField(
                            controller: _dieselLitresController,
                            decoration: InputDecoration(
                              labelText: 'Diesel Litres',
                            ),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (value!.isEmpty)
                                return 'Please enter diesel litres';
                              if (double.tryParse(value) == null)
                                return 'Please enter a valid number';
                              return null;
                            },
                          ),

                          // Trailers Field
                          TextFormField(
                            controller: _trailersController,
                            decoration: InputDecoration(
                              labelText: 'Trailers',
                            ),
                            validator: (value) => value!.isEmpty
                                ? 'Please enter trailer information'
                                : null,
                          ),

                          // Add similar TextFormFields for other controllers
                          ElevatedButton(
                            onPressed: _addTrip,
                            child: Text('Add Trip'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Trips Table (as in your previous code)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trip Records',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 16),
                        _isLoading
                            ? Center(child: CircularProgressIndicator())
                            : _trips.isEmpty
                                ? Center(child: Text('No trips found'))
                                : SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: [
                                        DataColumn(label: Text('Date')),
                                        DataColumn(label: Text('Vehicle')),
                                        DataColumn(
                                            label: Text(
                                                'Customer ID')), // Changed from Customer Name
                                        DataColumn(label: Text('Destination')),
                                        DataColumn(
                                            label: Text('Starting Mileage')),
                                        DataColumn(
                                            label: Text('Ending Mileage')),
                                        DataColumn(label: Text('Fuel Litres')),
                                      ],
                                      rows: _trips.map((trip) {
                                        return DataRow(cells: [
                                          DataCell(Text(trip.dateTime
                                              .toString())), // Use dateTime
                                          DataCell(Text(trip
                                              .plateNumber)), // Use plateNumber
                                          DataCell(Text(trip.customerId
                                              .toString())), // Convert to string
                                          DataCell(Text(trip.destination)),
                                          DataCell(Text(trip.startingMillage)),
                                          DataCell(Text(trip.endingMillage)),
                                          DataCell(Text(trip.fuelLitres)),
                                        ]);
                                      }).toList(),
                                    ),
                                  ),
                      ],
                    ),
                  ),
                ),

                // Summary Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Trips',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _trips.length.toString(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    _vehicleRegController.dispose();
    _startingMileageController.dispose();
    _endingMileageController.dispose();
    _customerNameController.dispose();
    _destinationController.dispose();
    _dieselLitresController.dispose();
    _trailersController.dispose();
    super.dispose();
  }
}
