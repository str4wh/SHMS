// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Minimal M-Pesa STK Push service for sandbox/testing purposes.
/// NOTE: Replace credentials with secure configuration (env/remote config) for production.
class MpesaService {
  // TODO: Replace with secure storage / remote config
  static const String _consumerKey = 'YOUR_CONSUMER_KEY';
  static const String _consumerSecret = 'YOUR_CONSUMER_SECRET';
  static const String _shortCode = '174379'; // Sandbox
  static const String _passkey = 'YOUR_PASSKEY';
  static const String _baseUrl = 'https://sandbox.safaricom.co.ke';
  static const String _callbackUrl = 'https://example.com/mpesa-callback';

  /// Obtain OAuth access token
  Future<String> getAccessToken() async {
    // Implementing in a robust way: use OAuth endpoint
    final auth = base64Encode(utf8.encode('$_consumerKey:$_consumerSecret'));
    final resp = await http
        .get(
          Uri.parse(
            'https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials',
          ),
          headers: {'Authorization': 'Basic $auth'},
        )
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200)
      throw Exception('Failed to get token: ${resp.statusCode}');
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    return j['access_token'] as String;
  }

  /// Initiate STK Push. Returns a map with keys: success(bool), message, checkoutRequestID, receiptNumber?
  Future<Map<String, dynamic>> initiateSTKPush({
    required String phone,
    required double amount,
    required String accountReference,
  }) async {
    try {
      final token = await getAccessToken();
      final timestamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(RegExp(r'[^0-9]'), '')
          .substring(0, 14);
      // password is base64 of shortcode+passkey+timestamp
      final password = base64Encode(
        utf8.encode('$_shortCode$_passkey$timestamp'),
      );

      final body = {
        'BusinessShortCode': _shortCode,
        'Password': password,
        'Timestamp': timestamp,
        'TransactionType': 'CustomerPayBillOnline',
        'Amount': amount.toStringAsFixed(0),
        'PartyA': phone,
        'PartyB': _shortCode,
        'PhoneNumber': phone,
        'CallBackURL': _callbackUrl,
        'AccountReference': accountReference,
        'TransactionDesc': 'Rent payment',
      };

      final resp = await http
          .post(
            Uri.parse('$_baseUrl/mpesa/stkpush/v1/processrequest'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final j = jsonDecode(resp.body) as Map<String, dynamic>;

      if (kDebugMode) print('STK Push response: $j');

      final success = j['ResponseCode'] == '0' || j['ResponseCode'] == 0;

      return {
        'success': success,
        'raw': j,
        'checkoutRequestID': j['CheckoutRequestID'] ?? j['checkoutRequestID'],
        'message': j['ResponseDescription'] ?? j['message'] ?? '',
      };
    } catch (e) {
      if (kDebugMode) print('STK Push failed: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Query STK Push status by checkoutRequestID. Returns one of: 'pending','completed','failed'
  Future<String> querySTKPushStatus(String checkoutRequestID) async {
    try {
      final token = await getAccessToken();
      final body = {
        'BusinessShortCode': _shortCode,
        'Password': base64Encode(
          utf8.encode(
            '$_shortCode$_passkey${DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14)}',
          ),
        ),
        'Timestamp': DateTime.now()
            .toUtc()
            .toIso8601String()
            .replaceAll(RegExp(r'[^0-9]'), '')
            .substring(0, 14),
        'CheckoutRequestID': checkoutRequestID,
      };

      final resp = await http
          .post(
            Uri.parse('$_baseUrl/mpesa/stkpushquery/v1/query'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      if (kDebugMode) print('STK Query response: $j');

      // Interpret response
      final code = j['ResponseCode']?.toString();
      if (code == '0') return 'completed';
      if (code == '1032' || code == '1' || code == '2020') return 'pending';
      return 'failed';
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
    final roomNumber = payload['roomNumber'] as String? ?? 'unknown';

    if (phone == null || userId == null || amount <= 0)
      return true; // drop invalid

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
