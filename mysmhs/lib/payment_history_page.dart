import 'package:flutter/material.dart';

class PaymentHistoryPage extends StatelessWidget {
  const PaymentHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/admin');
          },
          tooltip: 'Back',
        ),
        title: const Text(
          'Payment History',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
      ),
      body: const Center(
        child: Text(
          'Payment History - Placeholder',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
