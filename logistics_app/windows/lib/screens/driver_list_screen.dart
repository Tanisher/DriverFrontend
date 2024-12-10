import 'package:flutter/material.dart';

class DriverListScreen extends StatelessWidget {
  final Future<List<dynamic>> drivers;

  DriverListScreen({required this.drivers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Drivers')),
      body: FutureBuilder<List<dynamic>>(
        future: drivers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final driverList = snapshot.data!;
            return ListView.builder(
              itemCount: driverList.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(driverList[index]['name'] ?? 'Unknown'),
                  subtitle: Text('ID: ${driverList[index]['id'] ?? 'N/A'}'),
                );
              },
            );
          }
        },
      ),
    );
  }
}
