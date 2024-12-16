import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    print('Token saved: $token');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    print('Retrieved token: $token');
    return token;
  }

  Future<String?> getCurrentUserId() async {
    final token = await getToken();
    if (token == null) {
      print('No token found');
      return null;
    }

    try {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);

      print('Full Decoded Token: $decodedToken');

      // More flexible user ID extraction
      final userId = decodedToken['id'] ??
          decodedToken['userId'] ??
          decodedToken['sub'] ??
          decodedToken['user_id'];

      print('Extracted User ID: $userId');
      print('Token Expiration: ${JwtDecoder.getExpirationDate(token)}');
      print('Is Token Expired: ${JwtDecoder.isExpired(token)}');

      return userId?.toString();
    } catch (e) {
      print('Error decoding JWT: $e');
      return null;
    }
  }
}
