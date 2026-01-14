import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class MpesaCloudService {
  // Explicitly specify the region to match your deployed functions
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  /// Initiate M-Pesa STK Push via Cloud Function
  Future<Map<String, dynamic>> initiatePayment({
    required String phoneNumber,
    required double amount,
    required String roomNumber,
  }) async {
    try {
      final callable = _functions.httpsCallable('initiateMpesaPayment');

      final result = await callable.call({
        'phoneNumber': phoneNumber,
        'amount': amount,
        'roomNumber': roomNumber,
      });

      if (kDebugMode) print('Payment initiated: ${result.data}');

      return {
        'success': result.data['success'] ?? false,
        'checkoutRequestID': result.data['checkoutRequestID'],
        'message': result.data['message'] ?? '',
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
      final callable = _functions.httpsCallable('checkPaymentStatus');

      final result = await callable.call({
        'checkoutRequestID': checkoutRequestID,
      });

      if (kDebugMode) print('Payment status: ${result.data}');

      return {
        'status': result.data['status'] ?? 'unknown',
        'mpesaReceiptNumber': result.data['mpesaReceiptNumber'],
        'amount': result.data['amount'],
        'resultDesc': result.data['resultDesc'],
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
