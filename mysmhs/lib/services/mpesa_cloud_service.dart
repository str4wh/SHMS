import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MpesaCloudService {
  // Firebase Functions base URL (server-side — no CORS issues)
  static const _functionsBase =
      'https://us-central1-shms-7b88d.cloudfunctions.net';

  /// Call a Firebase HTTPS Callable function with an explicit Bearer token.
  /// Firebase Functions accept the callable wire format:
  ///   request body  → { "data": { ... } }
  ///   response body → { "result": { ... } }
  Future<Map<String, dynamic>> _callFunction(
    String name,
    Map<String, dynamic> data,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {'__error': 'User not authenticated'};
    }

    final token = await user.getIdToken(true);

    final response = await http
        .post(
          Uri.parse('$_functionsBase/$name'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'data': data}),
        )
        .timeout(const Duration(seconds: 30));

    if (kDebugMode) {
      print('[$name] status=${response.statusCode} body=${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      final msg = decoded['error']?['message'] as String? ?? response.body;
      return {'__error': msg};
    }

    // v2 callable response wraps the return value in "result"
    return (decoded['result'] as Map<String, dynamic>?) ?? decoded;
  }

  /// Initiate M-Pesa STK Push via Cloud Function
  Future<Map<String, dynamic>> initiatePayment({
    required String phoneNumber,
    required double amount,
    required String roomNumber,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final result = await _callFunction('initiateMpesaPayment', {
        'phoneNumber': phoneNumber,
        'amount': amount,
        'roomNumber': roomNumber,
        'userId': uid, // fallback if Bearer token auth doesn't propagate
      });

      if (result.containsKey('__error')) {
        return {'success': false, 'message': result['__error']};
      }

      if (kDebugMode) print('Payment initiated: $result');

      return {
        'success': result['success'] ?? false,
        'checkoutRequestID': result['checkoutRequestID'],
        'merchantRequestID': result['merchantRequestID'],
        'message': result['message'] ?? '',
      };
    } catch (e) {
      if (kDebugMode) print('Payment initiation error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Check payment status via Cloud Function
  Future<Map<String, dynamic>> checkPaymentStatus(
    String checkoutRequestID,
  ) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final result = await _callFunction('checkPaymentStatus', {
        'checkoutRequestID': checkoutRequestID,
        'userId': uid, // fallback if Bearer token auth doesn't propagate
      });

      if (kDebugMode) print('Payment status: $result');

      return {
        'status': result['status'] ?? 'unknown',
        'mpesaReceiptNumber': result['mpesaReceiptNumber'],
        'amount': result['amount'],
        'resultDesc': result['resultDesc'],
      };
    } catch (e) {
      if (kDebugMode) print('Status check error: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Poll payment status until completed or timeout
  Future<String> waitForPaymentCompletion(
    String checkoutRequestID, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      await Future.delayed(const Duration(seconds: 5));
      final result = await checkPaymentStatus(checkoutRequestID);
      final status = result['status'] as String;
      if (status == 'completed') return 'completed';
      if (status == 'failed') return 'failed';
    }
    return 'timeout';
  }
}
