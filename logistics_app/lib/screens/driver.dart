import 'package:flutter/material.dart';

class DriverScreen extends StatelessWidget {
  final List<Map<String, String>> currentTrips = [
    {
      'id': '1',
      'startLocation': 'Warehouse A',
      'endLocation': 'Store B',
      'status': 'In Progress',
    },
    {
      'id': '2',
      'startLocation': 'Factory C',
      'endLocation': 'Distribution Center D',
      'status': 'Completed',
    },
  ];

  void addTrip(BuildContext context) {
    // Navigate to the Add Trip screen or show a form
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Add Trip button pressed')),
    );
  }

  void reportFault(BuildContext context, String tripId) {
    // Navigate to the Report Fault screen or show a form
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report Fault for Trip ID: $tripId')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Trips',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: currentTrips.length,
                itemBuilder: (context, index) {
                  final trip = currentTrips[index];
                  return Card(
                    elevation: 4,
                    margin: EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(
                        '${trip['startLocation']} → ${trip['endLocation']}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('Status: ${trip['status']}'),
                      trailing: ElevatedButton(
                        onPressed: () => reportFault(context, trip['id']!),
                        child: Text('Report Fault'),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => addTrip(context),
              child: Text('Add Trip'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
