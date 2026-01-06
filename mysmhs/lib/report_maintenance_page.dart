import 'package:flutter/material.dart';

class ReportMaintenancePage extends StatelessWidget {
  const ReportMaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Report Maintenance',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
      ),
      body: const Center(
        child: Text(
          'Report Maintenance - Placeholder',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
