import 'package:flutter/material.dart';
import 'package:logistics_app/screens/LoginScreen.dart';
import 'package:logistics_app/screens/SignUpScreen.dart';
import 'package:logistics_app/screens/driver.dart';
import 'package:logistics_app/screens/driver_list_screen.dart';
import 'package:logistics_app/screens/landing.dart';
import 'package:logistics_app/service/driver_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/landing',
      routes: {
        '/signup': (context) => SignUpScreen(),
        '/login': (context) => LoginScreen(),
        '/home': (context) => DriverListScreen(
              drivers: fetchDrivers(), // This is now correctly imported
            ),
        '/driver': (context) => DriverScreen(),
        '/landing': (context) => LandingScreen(),
      },
    );
  }
}
