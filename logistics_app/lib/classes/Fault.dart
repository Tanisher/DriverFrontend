import 'package:flutter/material.dart';

class Fault {
  final int? id;
  final String description;
  final DateTime? reportDate;
  final bool resolved;

  Fault({
    this.id,
    required this.description,
    this.reportDate,
    this.resolved = false,
  });

  factory Fault.fromJson(Map<String, dynamic> json) {
    return Fault(
      id: json['id'],
      description: json['description'],
      reportDate: json['reportDate'] != null 
          ? DateTime.parse(json['reportDate']) 
          : null,
      resolved: json['resolved'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'reportDate': reportDate?.toIso8601String(),
    'resolved': resolved,
  };
}