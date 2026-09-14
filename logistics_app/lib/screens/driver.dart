import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:logistics_app/classes/Load.dart';
import 'package:logistics_app/service/auth_service.dart';

enum TripPhase { ready, deadhead, loaded }

TripPhase tripPhaseOf(Trip? trip) {
  if (trip == null) return TripPhase.ready;
  final token =
      '${trip.status} ${trip.legType}'.toUpperCase().replaceAll('-', '_');
  if (token.contains('COMPLETE') ||
      token.contains('DELIVERED') ||
      token.contains('FINISHED')) {
    return TripPhase.ready;
  }
  if (token.contains('LOAD')) return TripPhase.loaded;
  if (token.contains('DEADHEAD') || token.contains('EMPTY')) {
    return TripPhase.deadhead;
  }
  if (trip.id != null &&
      (trip.endingMillage.isEmpty || trip.endingMillage == 'null')) {
    return TripPhase.deadhead;
  }
  return TripPhase.ready;
}

dynamic millageJson(String text) {
  final trimmed = text.trim();
  return int.tryParse(trimmed) ?? trimmed;
}

String? mileageRejectionMessage(int statusCode, String body) {
  if (statusCode == 200 || statusCode == 201 || statusCode == 204) {
    return null;
  }

  final lower = body.toLowerCase();
  final looksLikeMileage = lower.contains('mileage') ||
      lower.contains('millage') ||
      lower.contains('odometer') ||
      ((lower.contains('end') || lower.contains('ending')) &&
          (lower.contains('start') || lower.contains('greater') ||
              lower.contains('lower') ||
              lower.contains('less')));

  if (!looksLikeMileage && statusCode != 400 && statusCode != 422) {
    return null;
  }

  String? extracted;
  try {
    final decoded = json.decode(body);
    if (decoded is Map) {
      extracted = _firstNonEmpty([
        decoded['message'],
        decoded['error'],
        decoded['detail'],
        decoded['endingMillage'],
        decoded['endingMileage'],
        decoded['title'],
      ]);
      final errors = decoded['errors'];
      if (extracted == null && errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is Map) {
          extracted = _firstNonEmpty([first['defaultMessage'], first['message']]);
        } else {
          extracted = first.toString();
        }
      }
      final fieldErrors = decoded['fieldErrors'];
      if (extracted == null && fieldErrors is List && fieldErrors.isNotEmpty) {
        final first = fieldErrors.first;
        if (first is Map) {
          extracted = _firstNonEmpty([first['message'], first['defaultMessage']]);
        }
      }
    }
  } catch (_) {
    extracted = body.trim().isEmpty ? null : body.trim();
  }

  if (!looksLikeMileage && extracted != null) {
    final extractedLower = extracted.toLowerCase();
    if (!(extractedLower.contains('mileage') ||
        extractedLower.contains('millage') ||
        extractedLower.contains('odometer'))) {
      return null;
    }
  }

  if (looksLikeMileage || extracted != null) {
    if (extracted != null && extracted.trim().isNotEmpty) {
      return extracted.trim();
    }
    return 'End mileage must be greater than start mileage';
  }
  return null;
}

String? _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text != 'null') return text;
  }
  return null;
}

class AssignedVehicle {
  final String plate;
  final String? make;
  final String? model;

  const AssignedVehicle({
    required this.plate,
    this.make,
    this.model,
  });

  String get subtitle {
    final parts = [
      if (make != null && make!.isNotEmpty) make,
      if (model != null && model!.isNotEmpty) model,
    ];
    return parts.join(' ');
  }
}

AssignedVehicle? assignedVehicleFromJson(dynamic decoded) {
  if (decoded == null) return null;

  if (decoded is List) {
    for (final item in decoded) {
      final vehicle = assignedVehicleFromJson(item);
      if (vehicle != null) return vehicle;
    }
    return null;
  }

  if (decoded is! Map) return null;
  final map = Map<String, dynamic>.from(decoded);

  final nested = map['vehicle'] ??
      map['assignedVehicle'] ??
      map['assigned_vehicle'] ??
      map['data'];
  if (nested is Map || nested is List) {
    final fromNested = assignedVehicleFromJson(nested);
    if (fromNested != null) return fromNested;
  }

  final plate = _firstNonEmpty([
    map['licensePlate'],
    map['plateNumber'],
    map['plate'],
    map['registration'],
    map['vehicleRegistration'],
  ]);
  if (plate == null) return null;

  return AssignedVehicle(
    plate: plate,
    make: _firstNonEmpty([map['make']]),
    model: _firstNonEmpty([map['model']]),
  );
}

class Trip {
  final int? id;
  final DateTime? dateTime;
  final String destination;
  final String startingMillage;
  final String endingMillage;
  final String fuelLitres;
  final String trailer1;
  final String trailer2;
  final String plateNumber;
  final int? driverId;
  final int? loadId;
  final int? customerId;
  final String status;
  final String legType;

  Trip({
    this.id,
    this.dateTime,
    this.destination = '',
    this.startingMillage = '',
    this.endingMillage = '',
    this.fuelLitres = '',
    this.trailer1 = '',
    this.trailer2 = '',
    this.plateNumber = '',
    this.driverId,
    this.loadId,
    this.customerId,
    this.status = '',
    this.legType = '',
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    int? nestedId(dynamic value) {
      if (value is Map) return value['id'];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    DateTime? parsedDate;
    final rawDate = json['dateTime'] ?? json['createdAt'] ?? json['startTime'];
    if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString());
    }

    return Trip(
      id: nestedId(json['id']),
      dateTime: parsedDate,
      destination: json['destination']?.toString() ?? '',
      startingMillage: (json['startingMillage'] ?? json['startingMileage'] ?? '')
          .toString(),
      endingMillage:
          (json['endingMillage'] ?? json['endingMileage'] ?? '').toString(),
      fuelLitres: (json['fuelLitres'] ?? '').toString(),
      trailer1: json['trailer1']?.toString() ?? '',
      trailer2: json['trailer2']?.toString() ?? '',
      plateNumber: json['plateNumber']?.toString() ?? '',
      driverId: nestedId(json['driver']) ?? nestedId(json['driverId']),
      loadId: nestedId(json['load']) ?? nestedId(json['loadId']),
      customerId: nestedId(json['customer']) ?? nestedId(json['customerId']),
      status: (json['status'] ?? json['tripStatus'] ?? json['state'] ?? '')
          .toString(),
      legType: (json['leg'] ?? json['tripType'] ?? json['type'] ?? '').toString(),
    );
  }

  Trip copyWith({
    int? id,
    String? startingMillage,
    String? endingMillage,
    String? status,
    String? legType,
    int? loadId,
  }) {
    return Trip(
      id: id ?? this.id,
      dateTime: dateTime,
      destination: destination,
      startingMillage: startingMillage ?? this.startingMillage,
      endingMillage: endingMillage ?? this.endingMillage,
      fuelLitres: fuelLitres,
      trailer1: trailer1,
      trailer2: trailer2,
      plateNumber: plateNumber,
      driverId: driverId,
      loadId: loadId ?? this.loadId,
      customerId: customerId,
      status: status ?? this.status,
      legType: legType ?? this.legType,
    );
  }
}

class DriverTripSheet extends StatefulWidget {
  const DriverTripSheet({Key? key}) : super(key: key);

  @override
  _DriverTripSheetState createState() => _DriverTripSheetState();
}

class _DriverTripSheetState extends State<DriverTripSheet> {
  static const String _apiHost = 'http://192.168.32.85:8080';

  final _formKey = GlobalKey<FormState>();
  String? _driverID;

  final AuthService _authService = AuthService();

  final TextEditingController _startingMileageController =
      TextEditingController();
  final TextEditingController _endingMileageController =
      TextEditingController();
  final TextEditingController _dieselLitresController = TextEditingController();
  final TextEditingController _trailer1Controller = TextEditingController();
  final TextEditingController _trailer2Controller = TextEditingController();

  List<Trip> _trips = [];
  List<Load> _assignedLoads = [];
  Load? _selectedLoad;
  Trip? _activeTrip;
  AssignedVehicle? _assignedVehicle;
  bool _isLoading = false;
  bool _isLoadingLoads = false;
  bool _isSubmitting = false;
  String? _endMileageError;

  TripPhase get _phase => tripPhaseOf(_activeTrip);

  String get _phaseStartMileage {
    if (_phase == TripPhase.loaded) {
      final deadheadEnd = _activeTrip?.endingMillage ?? '';
      if (deadheadEnd.isNotEmpty && deadheadEnd != 'null') {
        return deadheadEnd;
      }
    }
    return _activeTrip?.startingMillage ?? '';
  }

  @override
  void initState() {
    super.initState();
    _initializeDriverInfo();
  }

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
      });

      await _refresh();
    } catch (e) {
      print('Initialization Error: $e');
      _showErrorSnackBar('Error initializing driver information');
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _fetchAssignedLoads(),
      _fetchTrips(),
      _fetchAssignedVehicle(),
    ]);
  }

  Future<void> _fetchAssignedVehicle() async {
    if (_driverID == null) return;

    final token = await _authService.getToken();
    final candidateUrls = [
      '$_apiHost/api/drivers/$_driverID',
      '$_apiHost/api/drivers/$_driverID/vehicle',
      '$_apiHost/api/drivers/$_driverID/assigned-vehicle',
      '$_apiHost/api/vehicles/assigned/$_driverID',
      '$_apiHost/api/vehicles/driver/$_driverID',
    ];

    AssignedVehicle? found;
    for (final url in candidateUrls) {
      try {
        print('Fetching assigned vehicle from: $url');
        final response = await http.get(
          Uri.parse(url),
          headers: _authHeaders(token),
        );
        print('Assigned vehicle $url -> ${response.statusCode}');
        if (response.statusCode != 200 || response.body.isEmpty) continue;

        final vehicle = assignedVehicleFromJson(json.decode(response.body));
        if (vehicle != null) {
          found = vehicle;
          print('Using assigned-vehicle endpoint: $url (${vehicle.plate})');
          break;
        }
      } catch (e) {
        print('Assigned vehicle lookup failed for $url: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _assignedVehicle = found;
    });
  }

  List<dynamic> _asJsonList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      return decoded['content'] ??
          decoded['loads'] ??
          decoded['data'] ??
          decoded['assignedLoads'] ??
          decoded['trips'] ??
          [];
    }
    return [];
  }

  Map<String, String> _authHeaders(String? token) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<void> _fetchAssignedLoads() async {
    if (_driverID == null) return;

    setState(() {
      _isLoadingLoads = true;
    });

    final token = await _authService.getToken();
    final candidateUrls = [
      '$_apiHost/api/loads/assigned/$_driverID',
      '$_apiHost/api/loads/driver/$_driverID',
      '$_apiHost/api/loads/driver/username/$_driverID',
    ];

    try {
      http.Response? success;

      for (final url in candidateUrls) {
        print('Fetching assigned loads from: $url');
        final response = await http.get(
          Uri.parse(url),
          headers: _authHeaders(token),
        );
        print('Assigned loads $url -> ${response.statusCode}');

        if (response.statusCode == 200 || response.statusCode == 204) {
          success = response;
          break;
        }
      }

      if (success == null) {
        _showErrorSnackBar('Failed to load assigned loads');
        return;
      }

      if (success.statusCode == 204 || success.body.isEmpty) {
        setState(() {
          _assignedLoads = [];
        });
        _syncSelectedLoad();
        return;
      }

      final body = _asJsonList(json.decode(success.body));
      setState(() {
        _assignedLoads = body
            .whereType<Map>()
            .map((item) => Load.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      });
      _syncSelectedLoad();
    } catch (e) {
      print('Error in _fetchAssignedLoads: $e');
      _showErrorSnackBar('Error fetching assigned loads: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLoads = false;
        });
      }
    }
  }

  Future<void> _fetchTrips() async {
    if (_driverID == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _authService.getToken();
      final tripsUrl =
          '$_apiHost/api/driver-trips/driver/username/$_driverID';
      print('Constructed trips URL: $tripsUrl');

      final response = await http.get(
        Uri.parse(tripsUrl),
        headers: _authHeaders(token),
      );

      print('Trips status: ${response.statusCode}');
      print('Trips body: ${response.body}');

      if (response.statusCode == 204 || response.body.isEmpty) {
        setState(() {
          _trips = [];
        });
      } else if (response.statusCode == 200) {
        final body = _asJsonList(json.decode(response.body));
        setState(() {
          _trips = body
              .whereType<Map>()
              .map((item) => Trip.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        });
      } else {
        _showErrorSnackBar('Failed to load trips. Error: ${response.body}');
      }

      _syncActiveTripFromList();
      await _fetchActiveTrip();
    } catch (e) {
      print('Error in _fetchTrips: $e');
      _showErrorSnackBar('Error connecting to server: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchActiveTrip() async {
    if (_driverID == null) return;
    final token = await _authService.getToken();
    final urls = [
      '$_apiHost/api/driver-trips/active/$_driverID',
      '$_apiHost/api/driver-trips/driver/$_driverID/active',
    ];

    for (final url in urls) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: _authHeaders(token),
        );
        print('Active trip $url -> ${response.statusCode}');
        if (response.statusCode == 200 && response.body.isNotEmpty) {
          final decoded = json.decode(response.body);
          Map<String, dynamic>? tripJson;
          if (decoded is Map<String, dynamic>) {
            if (decoded['id'] != null || decoded['status'] != null) {
              tripJson = decoded;
            } else if (decoded['trip'] is Map) {
              tripJson = Map<String, dynamic>.from(decoded['trip']);
            }
          }
          if (tripJson != null) {
            final trip = Trip.fromJson(tripJson);
            if (tripPhaseOf(trip) != TripPhase.ready) {
              setState(() {
                _activeTrip = trip;
              });
              _syncSelectedLoad();
            }
            return;
          }
        }
      } catch (e) {
        print('Active trip lookup failed for $url: $e');
      }
    }
  }

  void _syncActiveTripFromList() {
    Trip? active;
    for (final trip in _trips) {
      if (tripPhaseOf(trip) != TripPhase.ready) {
        active = trip;
        break;
      }
    }
    if (active != null) {
      setState(() {
        _activeTrip = active;
      });
    }
    _syncSelectedLoad();
  }

  void _syncSelectedLoad() {
    final loadId = _activeTrip?.loadId;
    if (loadId == null) {
      if (_selectedLoad != null &&
          !_assignedLoads.any((load) => load.id == _selectedLoad!.id) &&
          _phase == TripPhase.ready) {
        setState(() {
          _selectedLoad = null;
        });
      }
      return;
    }
    Load? match;
    for (final load in _assignedLoads) {
      if (load.id == loadId) {
        match = load;
        break;
      }
    }
    setState(() {
      _selectedLoad = match ??
          _selectedLoad ??
          Load(
            id: loadId,
            description: 'Load #$loadId',
            weight: '',
            pickupLocation: '',
            deliveryLocation: '',
            status: '',
          );
    });
  }

  void _selectLoad(Load load) {
    if (_phase != TripPhase.ready) {
      _showErrorSnackBar('Finish the current trip before selecting another load');
      return;
    }
    setState(() {
      _selectedLoad = load;
      _endMileageError = null;
      _endingMileageController.clear();
    });
  }

  void _clearSelectedLoad() {
    if (_phase != TripPhase.ready) return;
    setState(() {
      _selectedLoad = null;
      _startingMileageController.clear();
      _endMileageError = null;
    });
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    final token = await _authService.getToken();
    final url = '$_apiHost$path';
    print('POST $url');
    print('POST body: ${json.encode(body)}');
    final response = await http.post(
      Uri.parse(url),
      headers: _authHeaders(token),
      body: json.encode(body),
    );
    print('POST $path -> ${response.statusCode} ${response.body}');
    return response;
  }

  Trip? _tripFromResponse(http.Response response, {String? fallbackStatus}) {
    if (response.body.isEmpty) return null;
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        Map<String, dynamic> tripMap = map;
        if (map['trip'] is Map) {
          tripMap = Map<String, dynamic>.from(map['trip']);
        } else if (map['data'] is Map) {
          tripMap = Map<String, dynamic>.from(map['data']);
        }
        final trip = Trip.fromJson(tripMap);
        if (fallbackStatus != null && trip.status.isEmpty) {
          return trip.copyWith(status: fallbackStatus);
        }
        return trip;
      }
    } catch (e) {
      print('Could not parse trip response: $e');
    }
    return null;
  }

  bool _handleMileageRejection(http.Response response) {
    final message = mileageRejectionMessage(response.statusCode, response.body);
    if (message == null) return false;
    setState(() {
      _endMileageError = message;
    });
    return true;
  }

  Future<void> _startDeadhead() async {
    if (_driverID == null) {
      _showErrorSnackBar('Driver information not available');
      return;
    }
    final selectedLoad = _selectedLoad;
    if (selectedLoad == null || selectedLoad.id == null) {
      _showErrorSnackBar('Select an assigned load before starting a trip');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final driverId = int.tryParse(_driverID!);
    final body = <String, dynamic>{
      'loadId': selectedLoad.id,
      'startingMillage': millageJson(_startingMileageController.text),
      'dateTime': DateTime.now().toIso8601String(),
    };
    if (driverId != null) {
      body['driverId'] = driverId;
    } else {
      body['driverId'] = _driverID;
    }
    if (selectedLoad.customerId != null) {
      body['customerId'] = selectedLoad.customerId;
    }

    setState(() {
      _isSubmitting = true;
      _endMileageError = null;
    });

    try {
      final response = await _post('/api/driver-trips/deadhead-start', body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final trip = _tripFromResponse(response, fallbackStatus: 'DEADHEAD') ??
            Trip(
              loadId: selectedLoad.id,
              driverId: driverId,
              startingMillage: _startingMileageController.text.trim(),
              status: 'DEADHEAD',
            );
        setState(() {
          _activeTrip = trip.copyWith(
            status: trip.status.isEmpty ? 'DEADHEAD' : trip.status,
            startingMillage: trip.startingMillage.isEmpty
                ? _startingMileageController.text.trim()
                : trip.startingMillage,
          );
          _endingMileageController.clear();
        });
      } else if (!_handleMileageRejection(response)) {
        _showErrorSnackBar('Failed to start trip');
      }
    } catch (e) {
      _showErrorSnackBar('Error connecting to server');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _endDeadhead() async {
    final trip = _activeTrip;
    if (trip?.id == null) {
      _showErrorSnackBar('No active deadhead trip');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final body = <String, dynamic>{
      'tripId': trip!.id,
      'id': trip.id,
      'endingMillage': millageJson(_endingMileageController.text),
    };

    setState(() {
      _isSubmitting = true;
      _endMileageError = null;
    });

    try {
      final response = await _post('/api/driver-trips/deadhead-end', body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final updated =
            _tripFromResponse(response, fallbackStatus: 'LOADED') ??
                trip.copyWith(
                  status: 'LOADED',
                  endingMillage: _endingMileageController.text.trim(),
                );
        setState(() {
          _activeTrip = updated.copyWith(
            status: updated.status.isEmpty ? 'LOADED' : updated.status,
          );
          _endingMileageController.clear();
          _endMileageError = null;
        });
      } else if (!_handleMileageRejection(response)) {
        _showErrorSnackBar('Failed to end deadhead');
      }
    } catch (e) {
      _showErrorSnackBar('Error connecting to server');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _completeDelivery() async {
    final trip = _activeTrip;
    if (trip?.id == null) {
      _showErrorSnackBar('No active loaded trip');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final fuel = _dieselLitresController.text.trim();
    final body = <String, dynamic>{
      'tripId': trip!.id,
      'id': trip.id,
      'endingMillage': millageJson(_endingMileageController.text),
      'fuelLitres': double.tryParse(fuel) ?? fuel,
      'trailer1': _trailer1Controller.text.trim(),
      'trailer2': _trailer2Controller.text.trim(),
    };

    setState(() {
      _isSubmitting = true;
      _endMileageError = null;
    });

    try {
      final response = await _post('/api/driver-trips/loaded-trip-end', body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _resetForm();
        await _refresh();
      } else if (!_handleMileageRejection(response)) {
        _showErrorSnackBar('Failed to complete delivery');
      }
    } catch (e) {
      _showErrorSnackBar('Error connecting to server');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _resetForm() {
    _startingMileageController.clear();
    _endingMileageController.clear();
    _dieselLitresController.clear();
    _trailer1Controller.clear();
    _trailer2Controller.clear();
    _selectedLoad = null;
    _activeTrip = null;
    _endMileageError = null;
  }

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
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AssignedVehicleBanner(vehicle: _assignedVehicle),
                if (_phase != TripPhase.ready) TripStatusBanner(phase: _phase),
                AssignedLoadsPanel(
                  isLoading: _isLoadingLoads,
                  loads: _assignedLoads,
                  selectedLoad: _selectedLoad,
                  onSelect: _selectLoad,
                ),
                if (_selectedLoad != null)
                  Form(
                    key: _formKey,
                    child: TripFlowPanel(
                      load: _selectedLoad!,
                      phase: _phase,
                      startMileage: _phaseStartMileage,
                      startMileageController: _startingMileageController,
                      endMileageController: _endingMileageController,
                      dieselController: _dieselLitresController,
                      trailer1Controller: _trailer1Controller,
                      trailer2Controller: _trailer2Controller,
                      endMileageError: _endMileageError,
                      isSubmitting: _isSubmitting,
                      onStartTrip: _startDeadhead,
                      onEndDeadhead: _endDeadhead,
                      onCompleteDelivery: _completeDelivery,
                      onChangeLoad:
                          _phase == TripPhase.ready ? _clearSelectedLoad : null,
                      onEndMileageChanged: () {
                        if (_endMileageError != null) {
                          setState(() {
                            _endMileageError = null;
                          });
                        }
                      },
                    ),
                  ),
                _buildTripRecordsCard(),
                _buildSummaryCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripRecordsCard() {
    return Card(
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
                            DataColumn(label: Text('Load ID')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Starting Mileage')),
                            DataColumn(label: Text('Ending Mileage')),
                            DataColumn(label: Text('Fuel Litres')),
                          ],
                          rows: _trips.map((trip) {
                            return DataRow(cells: [
                              DataCell(Text(trip.dateTime == null
                                  ? ''
                                  : DateFormat('yyyy-MM-dd')
                                      .format(trip.dateTime!))),
                              DataCell(Text(trip.plateNumber)),
                              DataCell(Text(trip.loadId?.toString() ?? '')),
                              DataCell(Text(trip.status.isEmpty
                                  ? trip.legType
                                  : trip.status)),
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
    );
  }

  Widget _buildSummaryCard() {
    return Card(
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
    );
  }

  @override
  void dispose() {
    _startingMileageController.dispose();
    _endingMileageController.dispose();
    _dieselLitresController.dispose();
    _trailer1Controller.dispose();
    _trailer2Controller.dispose();
    super.dispose();
  }
}

class AssignedVehicleBanner extends StatelessWidget {
  final AssignedVehicle? vehicle;

  const AssignedVehicleBanner({Key? key, required this.vehicle})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final plate = vehicle?.plate;
    final subtitle = vehicle?.subtitle ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.local_shipping_outlined, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assigned vehicle',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plate == null || plate.isEmpty
                        ? 'No vehicle assigned to your profile'
                        : plate,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.black54),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String loadTitle(Load load) {
  if (load.description.isNotEmpty) return load.description;
  return 'Load #${load.id ?? ''}';
}

String loadRoute(Load load) {
  final pickup =
      load.pickupLocation.isNotEmpty ? load.pickupLocation : 'Pickup TBD';
  final delivery = load.deliveryLocation.isNotEmpty
      ? load.deliveryLocation
      : 'Delivery TBD';
  return '$pickup → $delivery';
}

class TripStatusBanner extends StatelessWidget {
  final TripPhase phase;

  const TripStatusBanner({Key? key, required this.phase}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final loaded = phase == TripPhase.loaded;
    final background = loaded ? Colors.green.shade50 : Colors.orange.shade50;
    final border = loaded ? Colors.green : Colors.orange;
    final text = loaded
        ? 'Loaded — en route to delivery'
        : 'Deadhead — en route to pickup';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            loaded ? Icons.local_shipping : Icons.alt_route,
            color: border,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: loaded ? Colors.green.shade800 : Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TripFlowPanel extends StatelessWidget {
  final Load load;
  final TripPhase phase;
  final String startMileage;
  final TextEditingController startMileageController;
  final TextEditingController endMileageController;
  final TextEditingController dieselController;
  final TextEditingController trailer1Controller;
  final TextEditingController trailer2Controller;
  final String? endMileageError;
  final bool isSubmitting;
  final VoidCallback onStartTrip;
  final VoidCallback onEndDeadhead;
  final VoidCallback onCompleteDelivery;
  final VoidCallback? onChangeLoad;
  final VoidCallback? onEndMileageChanged;

  const TripFlowPanel({
    Key? key,
    required this.load,
    required this.phase,
    required this.startMileage,
    required this.startMileageController,
    required this.endMileageController,
    required this.dieselController,
    required this.trailer1Controller,
    required this.trailer2Controller,
    required this.endMileageError,
    required this.isSubmitting,
    required this.onStartTrip,
    required this.onEndDeadhead,
    required this.onCompleteDelivery,
    this.onChangeLoad,
    this.onEndMileageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Trip for ${loadTitle(load)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                if (onChangeLoad != null)
                  TextButton(
                    onPressed: onChangeLoad,
                    child: const Text('Change load'),
                  ),
              ],
            ),
            Text(
              loadRoute(load),
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            if (phase == TripPhase.ready) ..._readyFields(),
            if (phase == TripPhase.deadhead) ..._deadheadFields(),
            if (phase == TripPhase.loaded) ..._loadedFields(),
          ],
        ),
      ),
    );
  }

  List<Widget> _readyFields() {
    return [
      TextFormField(
        controller: startMileageController,
        decoration: const InputDecoration(
          labelText: 'Start mileage',
        ),
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter start mileage';
          }
          if (int.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
          return null;
        },
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isSubmitting ? null : onStartTrip,
          child: Text(isSubmitting ? 'Starting...' : 'Start trip'),
        ),
      ),
    ];
  }

  List<Widget> _deadheadFields() {
    return [
      if (startMileage.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text('Deadhead started at $startMileage'),
        ),
      TextFormField(
        controller: endMileageController,
        decoration: InputDecoration(
          labelText: 'End mileage',
          errorText: endMileageError,
          errorMaxLines: 3,
        ),
        keyboardType: TextInputType.number,
        onChanged: (_) => onEndMileageChanged?.call(),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter end mileage';
          }
          if (int.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
          return null;
        },
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isSubmitting ? null : onEndDeadhead,
          child: Text(
            isSubmitting ? 'Updating...' : 'Arrived / End deadhead',
          ),
        ),
      ),
    ];
  }

  List<Widget> _loadedFields() {
    return [
      if (startMileage.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text('Loaded leg started at $startMileage'),
        ),
      TextFormField(
        controller: endMileageController,
        decoration: InputDecoration(
          labelText: 'End mileage',
          errorText: endMileageError,
          errorMaxLines: 3,
        ),
        keyboardType: TextInputType.number,
        onChanged: (_) => onEndMileageChanged?.call(),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter end mileage';
          }
          if (int.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
          return null;
        },
      ),
      TextFormField(
        controller: dieselController,
        decoration: const InputDecoration(
          labelText: 'Diesel litres',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter diesel litres';
          }
          if (double.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
          return null;
        },
      ),
      TextFormField(
        controller: trailer1Controller,
        decoration: const InputDecoration(
          labelText: 'Trailer 1',
        ),
        validator: (value) =>
            value == null || value.isEmpty ? 'Please enter trailer 1' : null,
      ),
      TextFormField(
        controller: trailer2Controller,
        decoration: const InputDecoration(
          labelText: 'Trailer 2',
        ),
        validator: (value) =>
            value == null || value.isEmpty ? 'Please enter trailer 2' : null,
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isSubmitting ? null : onCompleteDelivery,
          child: Text(
            isSubmitting ? 'Completing...' : 'Complete delivery',
          ),
        ),
      ),
    ];
  }
}

class AssignedLoadsPanel extends StatelessWidget {
  final bool isLoading;
  final List<Load> loads;
  final Load? selectedLoad;
  final ValueChanged<Load> onSelect;

  const AssignedLoadsPanel({
    Key? key,
    required this.isLoading,
    required this.loads,
    required this.selectedLoad,
    required this.onSelect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assigned Loads',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pick a load assigned by office to start a trip.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (loads.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text('No loads have been assigned to you yet'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: loads.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final load = loads[index];
                  final selected = selectedLoad?.id == load.id;
                  return InkWell(
                    onTap: () => onSelect(load),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected ? Colors.blue : Colors.grey.shade300,
                          width: selected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: selected ? Colors.blue.shade50 : Colors.white,
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  loadTitle(load),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (load.status.isNotEmpty)
                                Chip(
                                  label: Text(load.status),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(loadRoute(load)),
                          if (load.weight.isNotEmpty)
                            Text('Weight: ${load.weight}'),
                          if (load.customerName != null &&
                              load.customerName!.isNotEmpty)
                            Text('Customer: ${load.customerName}'),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: () => onSelect(load),
                              child: Text(
                                selected ? 'Selected' : 'Select',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
