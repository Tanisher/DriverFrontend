import 'package:flutter/material.dart';
import 'package:logistics_app/classes/Fault.dart';

class Vehicle {
  final int? id;
  final String licensePlate;
  final String make;
  final String model;
  final int year;
  final String color;
  final bool active;
  final DateTime? lastServiceDate;
  final List<Fault>? faults;
  double? latitude;
  double? longitude;

  Vehicle({
    this.id,
    required this.licensePlate,
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    this.active = true,
    this.lastServiceDate,
    this.faults,
    this.latitude,
    this.longitude,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      licensePlate: json['licensePlate'],
      make: json['make'],
      model: json['model'],
      year: json['year'],
      color: json['color'],
      active: json['active'] ?? true,
      lastServiceDate: json['lastServiceDate'] != null 
          ? DateTime.parse(json['lastServiceDate']) 
          : null,
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),    
      faults: json['faults'] != null
          ? (json['faults'] as List)
              .map((faultJson) => Fault.fromJson(faultJson))
              .toList()
          : null,

    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'licensePlate': licensePlate,
    'make': make,
    'model': model,
    'year': year,
    'color': color,
    'active': active,
    'lastServiceDate': lastServiceDate?.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    // Note: Faults are typically managed separately, so we don't include them in toJson
  };
}