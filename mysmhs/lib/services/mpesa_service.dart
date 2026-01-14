// ignore_for_file: avoid_print

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// M-Pesa STK Push service using Firebase Cloud Functions.
/// This implementation uses Cloud Functions to avoid CORS errors and keep credentials secure.
class MpesaService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  /// Initiate STK Push. Returns a map with keys: success(bool), message, checkoutRequestID, receiptNumber?
  ///
  /// Maintains backward compatibility with the old service interface.
  Future<Map<String, dynamic>> initiateSTKPush({
    required String phone,
    required double amount,
    required String accountReference,
  }) async {
    try {
      // Extract room number from accountReference (format: 'RENT-{roomNumber}')
      final roomNumber = accountReference.replaceFirst('RENT-', '');

      final callable = _functions.httpsCallable('initiateMpesaPayment');

      final result = await callable.call({
        'phoneNumber': phone,
        'amount': amount,
        'roomNumber': roomNumber,
      });

      if (kDebugMode) print('STK Push response: ${result.data}');

      // Map Cloud Function response to match old service format
      return {
        'success': result.data['success'] ?? false,
        'checkoutRequestID': result.data['checkoutRequestID'],
        'message': result.data['message'] ?? '',
        'raw': result.data, // Include raw response for backward compatibility
      };
    } catch (e) {
      if (kDebugMode) print('STK Push failed: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Query STK Push status by checkoutRequestID. Returns one of: 'pending','completed','failed'
  ///
  /// Maintains backward compatibility with the old service interface.
  Future<String> querySTKPushStatus(String checkoutRequestID) async {
    try {
      final callable = _functions.httpsCallable('checkPaymentStatus');

      final result = await callable.call({
        'checkoutRequestID': checkoutRequestID,
      });

      if (kDebugMode) print('STK Query response: ${result.data}');

      // Map Cloud Function response to match old service format
      final status = result.data['status'] as String? ?? 'unknown';

      if (status == 'completed') return 'completed';
      if (status == 'pending') return 'pending';
      if (status == 'failed') return 'failed';

      return 'pending'; // Default to pending for unknown statuses
    } catch (e) {
      if (kDebugMode) print('STK Query failed: $e');
      return 'failed';
    }
  }
}

/// Handler for SyncManager to process queued mpesa payments.
/// Expects payload with keys: userId, roomNumber, amount, phoneNumber, timestamp
Future<bool> mpesaPaymentHandler(Map<String, dynamic> payload) async {
  try {
    final mpesa = MpesaService();

    final phone = payload['phoneNumber'] as String?;
    final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
    final userId = payload['userId'] as String?;
    final roomNumberRaw = payload['roomNumber'];
    final roomNumber = roomNumberRaw?.toString() ?? 'unknown';

    if (phone == null || userId == null || amount <= 0) {
      return true; // drop invalid
    }

    final result = await mpesa.initiateSTKPush(
      phone: phone,
      amount: amount,
      accountReference: 'RENT-$roomNumber',
    );

    if (result['success'] == true && result['checkoutRequestID'] != null) {
      final checkout = result['checkoutRequestID'] as String;

      // Poll a few times for completion
      final end = DateTime.now().add(const Duration(seconds: 60));
      while (DateTime.now().isBefore(end)) {
        await Future.delayed(const Duration(seconds: 5));
        final status = await MpesaService().querySTKPushStatus(checkout);
        if (status == 'completed') {
          // Save payment to Firestore
          await FirebaseFirestore.instance.collection('payments').add({
            'userId': userId,
            'roomNumber': roomNumber,
            'amount': amount,
            'phoneNumber': phone,
            'mpesaReceiptNumber':
                result['raw']?['CheckoutRequestID'] ?? checkout,
            'transactionDate': FieldValue.serverTimestamp(),
            'status': 'completed',
            'checkoutRequestID': checkout,
            'queuedAt': payload['timestamp'],
            'completedAt': DateTime.now().toIso8601String(),
          });

          return true;
        }
      }
    }

    return false;
  } catch (e) {
    if (kDebugMode) print('mpesaPaymentHandler error: $e');
    return false;
  }
}
