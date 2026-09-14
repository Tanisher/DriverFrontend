import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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

dynamic weighbridgeJson(String text) {
  final trimmed = text.trim();
  return double.tryParse(trimmed) ?? trimmed;
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
        decoded['endMileage'],
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

int? jsonId(dynamic value) {
  if (value == null) return null;
  if (value is Map) return jsonId(value['id']);
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

Trip? loadedTripFromDeadheadEndResponse(String body) {
  if (body.trim().isEmpty) return null;
  try {
    return loadedTripFromDecoded(json.decode(body));
  } catch (_) {
    return null;
  }
}

Trip? loadedTripFromDecoded(dynamic decoded) {
  if (decoded == null) return null;

  if (decoded is List) {
    for (final item in decoded) {
      final trip = loadedTripFromDecoded(item);
      if (trip != null) return trip;
    }
    return null;
  }

  if (decoded is! Map) return null;
  final map = Map<String, dynamic>.from(decoded);

  for (final key in ['loadedTrip', 'loaded_trip']) {
    if (map[key] is Map) {
      final nested =
          loadedTripFromDecoded(Map<String, dynamic>.from(map[key]));
      if (nested != null) return nested;
    }
  }

  final loadedId = jsonId(map['loadedTripId'] ?? map['loaded_trip_id']);
  if (loadedId != null) {
    final status = (map['loadedTripStatus'] ??
            map['loaded_trip_status'] ??
            map['status'] ??
            '')
        .toString();
    final candidate = Trip(
      id: loadedId,
      status: status,
      loadId: jsonId(map['loadId'] ?? map['load']),
      startingMillage:
          (map['startMileage'] ?? map['startingMileage'] ?? map['startingMillage'] ?? '')
              .toString(),
      endingMillage:
          (map['endMileage'] ?? map['endingMileage'] ?? map['endingMillage'] ?? '')
              .toString(),
    );
    if (tripPhaseOf(candidate) == TripPhase.loaded) return candidate;
  }

  if (map['data'] is Map) {
    final fromData = loadedTripFromDecoded(map['data']);
    if (fromData != null) return fromData;
  }
  if (map['trip'] is Map) {
    final fromTrip = loadedTripFromDecoded(map['trip']);
    if (fromTrip != null) return fromTrip;
  }

  final trip = Trip.fromJson(map);
  if (trip.id != null && tripPhaseOf(trip) == TripPhase.loaded) {
    return trip;
  }
  return null;
}

Trip? activeTripFromResponseBody(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty || trimmed == 'null') return null;
  try {
    return activeTripFromDecoded(json.decode(trimmed));
  } catch (_) {
    return null;
  }
}

Trip? activeTripFromDecoded(dynamic decoded) {
  if (decoded == null) return null;

  if (decoded is List) {
    for (final item in decoded) {
      final trip = activeTripFromDecoded(item);
      if (trip != null) return trip;
    }
    return null;
  }

  if (decoded is! Map) return null;
  final map = Map<String, dynamic>.from(decoded);

  for (final key in [
    'activeTrip',
    'active_trip',
    'loadedTrip',
    'loaded_trip',
  ]) {
    if (map[key] is Map) {
      final nested = activeTripFromDecoded(map[key]);
      if (nested != null) return nested;
    }
  }

  if (map['trip'] is Map) {
    final nested = activeTripFromDecoded(map['trip']);
    if (nested != null) return nested;
  }

  if (map['data'] is Map && jsonId(map['id']) == null) {
    final nested = activeTripFromDecoded(map['data']);
    if (nested != null) return nested;
  }

  final trip = Trip.fromJson(map);
  if (trip.id == null) return null;
  if (tripPhaseOf(trip) == TripPhase.ready) return null;
  return trip;
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
      startingMillage: (json['startMileage'] ??
              json['startingMileage'] ??
              json['startingMillage'] ??
              '')
          .toString(),
      endingMillage: (json['endMileage'] ??
              json['endingMileage'] ??
              json['endingMillage'] ??
              '')
          .toString(),
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
  final TextEditingController _weighbridgeController = TextEditingController();

  List<Load> _assignedLoads = [];
  Load? _selectedLoad;
  Trip? _activeTrip;
  AssignedVehicle? _assignedVehicle;
  bool _isLoadingLoads = false;
  bool _isSubmitting = false;
  bool _isInitializing = true;
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
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _fetchAssignedLoads(),
      _fetchAssignedVehicle(),
      _fetchActiveTrip(),
    ]);
    if (mounted) {
      _syncSelectedLoad();
    }
  }

  Future<void> _fetchAssignedVehicle() async {
    if (_driverID == null) return;

    final token = await _authService.getToken();
    final url = '$_apiHost/api/drivers/me/assigned-vehicle';

    try {
      print('GET $url');
      final response = await http.get(
        Uri.parse(url),
        headers: _authHeaders(token),
      );
      print('Assigned vehicle ${response.statusCode}: ${response.body}');

      if (response.statusCode == 204 ||
          response.statusCode == 404 ||
          response.body.isEmpty) {
        if (!mounted) return;
        setState(() {
          _assignedVehicle = null;
        });
        return;
      }

      if (response.statusCode != 200) {
        _showErrorSnackBar('Failed to load assigned vehicle');
        return;
      }

      if (!mounted) return;
      setState(() {
        _assignedVehicle = assignedVehicleFromJson(json.decode(response.body));
      });
    } catch (e) {
      print('Error in _fetchAssignedVehicle: $e');
      _showErrorSnackBar('Error fetching assigned vehicle: $e');
    }
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
    final url = '$_apiHost/api/drivers/me/assigned-loads';

    try {
      print('GET $url');
      final response = await http.get(
        Uri.parse(url),
        headers: _authHeaders(token),
      );
      print('Assigned loads ${response.statusCode}: ${response.body}');

      if (response.statusCode == 204 || response.body.isEmpty) {
        setState(() {
          _assignedLoads = [];
        });
        _syncSelectedLoad();
        return;
      }

      if (response.statusCode != 200) {
        _showErrorSnackBar('Failed to load assigned loads');
        return;
      }

      final body = _asJsonList(json.decode(response.body));
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

  Future<void> _fetchActiveTrip() async {
    if (_driverID == null) return;

    final token = await _authService.getToken();
    final url = '$_apiHost/api/drivers/me/active-trip';

    try {
      print('GET $url');
      final response = await http.get(
        Uri.parse(url),
        headers: _authHeaders(token),
      );
      print('Active trip ${response.statusCode}: ${response.body}');

      if (response.statusCode == 204 || response.statusCode == 404) {
        _applyActiveTrip(null);
        return;
      }

      if (response.statusCode != 200) {
        _showErrorSnackBar('Failed to load active trip');
        return;
      }

      _applyActiveTrip(activeTripFromResponseBody(response.body));
    } catch (e) {
      print('Error in _fetchActiveTrip: $e');
      _showErrorSnackBar('Error fetching active trip: $e');
    }
  }

  void _applyActiveTrip(Trip? trip) {
    if (!mounted) return;
    setState(() {
      _activeTrip = trip;
      if (trip == null) {
        _endMileageError = null;
      }
    });
    _syncSelectedLoad();
  }

  void _syncSelectedLoad() {
    final loadId = _activeTrip?.loadId;
    if (loadId == null) {
      if (_phase != TripPhase.ready) {
        setState(() {
          _selectedLoad ??= Load(
            id: _activeTrip?.loadId,
            description: 'Active trip',
            weight: '',
            pickupLocation: '',
            deliveryLocation: '',
            status: '',
          );
        });
        return;
      }
      if (_selectedLoad != null &&
          !_assignedLoads.any((load) => load.id == _selectedLoad!.id)) {
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
      _weighbridgeController.clear();
    });
  }

  void _clearSelectedLoad() {
    if (_phase != TripPhase.ready) return;
    setState(() {
      _selectedLoad = null;
      _startingMileageController.clear();
      _endMileageError = null;
      _weighbridgeController.clear();
    });
  }

  Future<http.Response> _patch(String path, Map<String, dynamic> body) async {
    final token = await _authService.getToken();
    final url = '$_apiHost$path';
    print('PATCH $url');
    print('PATCH body: ${json.encode(body)}');
    final response = await http.patch(
      Uri.parse(url),
      headers: _authHeaders(token),
      body: json.encode(body),
    );
    print('PATCH $path -> ${response.statusCode} ${response.body}');
    return response;
  }

  Future<bool> _submitActualWeightIfNeeded() async {
    final load = _selectedLoad;
    if (load == null || load.id == null || !load.needsWeighbridge) {
      return true;
    }

    final text = _weighbridgeController.text.trim();
    if (text.isEmpty) return true;

    try {
      final response = await _patch(
        '/api/loads/${load.id}/actual-weight',
        {'actualWeight': weighbridgeJson(text)},
      );
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        if (mounted) {
          setState(() {
            _selectedLoad = load.copyWith(actualWeight: text);
          });
        }
        return true;
      }
      final detail = response.body.trim();
      _showErrorSnackBar(
        detail.isEmpty
            ? 'Failed to save weighbridge reading'
            : 'Failed to save weighbridge reading: $detail',
      );
      return false;
    } catch (e) {
      _showErrorSnackBar('Error saving weighbridge reading');
      return false;
    }
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
      'startMileage': millageJson(_startingMileageController.text),
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

    setState(() {
      _isSubmitting = true;
      _endMileageError = null;
    });

    try {
      if (!await _submitActualWeightIfNeeded()) return;

      final body = <String, dynamic>{
        'tripId': trip!.id,
        'endMileage': millageJson(_endingMileageController.text),
      };
      final response = await _post('/api/driver-trips/deadhead-end', body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final loadedTrip = loadedTripFromDeadheadEndResponse(response.body);
        if (loadedTrip == null || loadedTrip.id == null) {
          _showErrorSnackBar(
            'Deadhead ended, but no loaded trip id was returned. Pull to refresh.',
          );
          return;
        }
        setState(() {
          _activeTrip = loadedTrip;
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

    setState(() {
      _isSubmitting = true;
      _endMileageError = null;
    });

    try {
      if (!await _submitActualWeightIfNeeded()) return;

      final fuel = _dieselLitresController.text.trim();
      final body = <String, dynamic>{
        'tripId': trip!.id,
        'endMileage': millageJson(_endingMileageController.text),
        'fuelLitres': double.tryParse(fuel) ?? fuel,
        'trailer1': _trailer1Controller.text.trim(),
        'trailer2': _trailer2Controller.text.trim(),
      };
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
    _weighbridgeController.clear();
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
    if (_driverID == null || _isInitializing) {
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
                if (_selectedLoad != null || _phase != TripPhase.ready)
                  Form(
                    key: _formKey,
                    child: TripFlowPanel(
                      load: _selectedLoad ??
                          Load(
                            description: 'Active trip',
                            weight: '',
                            pickupLocation: '',
                            deliveryLocation: '',
                            status: '',
                          ),
                      phase: _phase,
                      startMileage: _phaseStartMileage,
                      startMileageController: _startingMileageController,
                      endMileageController: _endingMileageController,
                      dieselController: _dieselLitresController,
                      trailer1Controller: _trailer1Controller,
                      trailer2Controller: _trailer2Controller,
                      weighbridgeController: _weighbridgeController,
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
              ],
            ),
          ),
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
    _weighbridgeController.dispose();
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
  final TextEditingController? weighbridgeController;
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
    this.weighbridgeController,
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
      ..._weighbridgeFields(requiredReading: false),
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
      ..._weighbridgeFields(requiredReading: true),
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

  List<Widget> _weighbridgeFields({required bool requiredReading}) {
    if (!load.needsWeighbridge || weighbridgeController == null) {
      return [];
    }
    return [
      TextFormField(
        controller: weighbridgeController,
        decoration: InputDecoration(
          labelText: 'Weighbridge reading',
          hintText: requiredReading
              ? 'Tonnes from the weighbridge'
              : 'Enter if the weighbridge is at this stop',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) {
            return requiredReading
                ? 'Please enter the weighbridge reading'
                : null;
          }
          if (double.tryParse(text) == null) {
            return 'Please enter a valid number';
          }
          return null;
        },
      ),
      const SizedBox(height: 12),
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
