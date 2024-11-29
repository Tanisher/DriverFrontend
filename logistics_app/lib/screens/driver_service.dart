import 'package:http/http.dart' as http;
import 'package:logistics_app/service/auth_service.dart';
import 'dart:convert';

Future<List<dynamic>> fetchDrivers() async {
  final authService = AuthService();
  final token = await authService.getToken();
  final response = await http.get(
    Uri.parse('http://192.168.32.11:8080/api/drivers'),
    headers: {
      'Authorization': 'Bearer $token',
    },
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to load drivers');
  }
}
