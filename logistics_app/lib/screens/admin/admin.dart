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
import 'package:logistics_app/screens/admin/customers.dart';
import 'package:logistics_app/screens/admin/driver.dart';
import 'package:logistics_app/screens/admin/load.dart';
import 'package:logistics_app/screens/admin/vehicle.dart';
import 'package:logistics_app/service/auth_service.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart'; // For date formatting


class AdminDashboardApp extends StatelessWidget {
  const AdminDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AdminDashboard(),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // Define dashboard sections
  final List<DashboardSection> sections = [
    DashboardSection(
      title: 'Customers',
      icon: Icons.people,
      page: CustomersPage(),
    ),
    DashboardSection(
      title: 'Loads',
      icon: Icons.local_shipping_rounded,
      page: LoadsPage(),
    ),
    DashboardSection(
      title: 'Drivers',
      icon: Icons.local_shipping,
      page: DriversPage(),
    ),
    DashboardSection(
      title: 'Vehicles',
      icon: Icons.directions_car,
      page: VehiclesPage(),
    ),
    DashboardSection(
      title: 'Trailers',
      icon: Icons.view_in_ar,
      page: TrailersPage(),
    ),
    DashboardSection(
      title: 'Orders',
      icon: Icons.list_alt,
      page: OrdersPage(),
    ),
  ];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
      ),
      body: Row(
        children: [
          // Sidebar Navigation
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: sections.map((section) {
              return NavigationRailDestination(
                icon: Icon(section.icon),
                label: Text(section.title),
              );
            }).toList(),
          ),

          // Vertical divider
          VerticalDivider(thickness: 1, width: 1),

          // Main Content Area
          Expanded(
            child: sections[_selectedIndex].page,
          ),
        ],
      ),
    );
  }
}

// Data class to represent dashboard sections
class DashboardSection {
  final String title;
  final IconData icon;
  final Widget page;

  DashboardSection({
    required this.title,
    required this.icon,
    required this.page,
  });
}

// Placeholder Pages for each section


//trailers section

class TrailersPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Trailers Management',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Add trailer functionality
              },
              child: Text('Add Trailer'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new trailer
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

//orders Serction

class OrdersPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Orders Management',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Add order functionality
              },
              child: Text('Create Order'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Create new order
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
