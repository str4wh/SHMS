import 'package:flutter/material.dart';

class PayRentPage extends StatelessWidget {
  const PayRentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Rent', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A8A),
      ),
      body: const Center(
        child: Text(
          'Pay Rent - Placeholder',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
