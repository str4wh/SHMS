// ignore_for_file: unused_local_variable, unused_import, unused_field

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mysmhs/services/connectivity_service.dart';
import 'package:mysmhs/services/local_cache_service.dart';
import 'package:mysmhs/services/sync_manager.dart';
import 'package:mysmhs/services/mpesa_service.dart';

enum PaymentState { initial, loading, waitingPin, queued, success, error }

class PayRentPage extends StatefulWidget {
  const PayRentPage({super.key});

  @override
  State<PayRentPage> createState() => _PayRentPageState();
}

class _PayRentPageState extends State<PayRentPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtl = TextEditingController();
  final _amountCtl = TextEditingController();
  final _roomCtl = TextEditingController();

  bool _loading = false;
  String _statusMessage = '';
  PaymentState _state = PaymentState.initial;

  double _amount = 0.0;
  String _roomNumber = '';

  StreamSubscription<bool>? _connSub;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityService.instance.isOnline.value;
    _connSub = ConnectivityService.instance.onStatusChange.listen((online) {
      setState(() => _isOnline = online);
    });

    _loadUserData();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _phoneCtl.dispose();
    _amountCtl.dispose();
    _roomCtl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    try {
      // 1) Get user doc for optional phone
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .get();
      final userData = userDoc.data() ?? {};

      final phone = (userData['phone'] as String?) ?? '';
      _phoneCtl.value = TextEditingValue(
        text: phone,
        selection: TextSelection.collapsed(offset: phone.length),
      );

      // 2) Query bookings for this student (note field names in your DB)
      final bookingQuery = await FirebaseFirestore.instance
          .collection('bookings')
          .where('studentID', isEqualTo: u.uid)
          .where('status', whereIn: ['approved', 'pending/approved'])
          .limit(1)
          .get();

      if (bookingQuery.docs.isNotEmpty) {
        final bookingData = bookingQuery.docs.first.data();

        // Price may be numeric
        _amount = (bookingData['price'] as num?)?.toDouble() ?? 0.0;
        final formattedAmount = NumberFormat.decimalPattern().format(_amount);
        _amountCtl.value = TextEditingValue(
          text: formattedAmount,
          selection: TextSelection.collapsed(offset: formattedAmount.length),
        );

        // Room number may be int or string -- convert to string
        final roomNum = bookingData['roomNumber'];
        _roomNumber = roomNum?.toString() ?? '';
        _roomCtl.value = TextEditingValue(
          text: _roomNumber,
          selection: TextSelection.collapsed(offset: _roomNumber.length),
        );
      } else {
        // No booking found - clear amount/room
        _amount = 0.0;
        _amountCtl.value = TextEditingValue(
          text: '0',
          selection: TextSelection.collapsed(offset: 1),
        );
        _roomNumber = '';
        _roomCtl.value = const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );
      }

      setState(() {});
    } catch (e) {
      if (kDebugMode) print('Error loading user data: $e');
    }
  }

  InputDecoration _inputDecoration(String label, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        labelStyle: const TextStyle(color: Colors.white),
        hintStyle: const TextStyle(color: Colors.white),
      );

  String? _validatePhone(String? v) {
    final s = (v ?? '').replaceAll(RegExp(r'\s+'), '');
    if (s.isEmpty) return 'Enter phone number';
    // Accept 07XXXXXXXX or 254XXXXXXXXX
    final norm = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (RegExp(r'^(07\d{8}|2547\d{8})$').hasMatch(norm)) return null;
    return 'Phone must be 07XXXXXXXX or 254XXXXXXXXX';
  }

  Future<void> _payPressed() async {
    if (!_formKey.currentState!.validate()) return;

    final phoneRaw = _phoneCtl.text.trim();
    final phone = phoneRaw.replaceAll(RegExp(r'[^0-9]'), '');

    final amount = _amount;
    final room = _roomNumber;

    final isOnline = ConnectivityService.instance.isOnline.value;

    if (isOnline) {
      await _confirmAndPayOnline(phone, amount, room);
    } else {
      await _confirmAndQueue(phone, amount, room);
    }
  }

  Future<void> _confirmAndPayOnline(
    String phone,
    double amount,
    String room,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm payment'),
        content: Text(
          'Initiate M-Pesa payment of KES ${NumberFormat.decimalPattern().format(amount)} from $phone?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _loading = true;
      _state = PaymentState.loading;
      _statusMessage = 'Sending payment request...';
    });

    try {
      final res = await MpesaService().initiateSTKPush(
        phone: phone,
        amount: amount,
        accountReference: 'RENT-$room',
      );
      if (res['success'] != true || res['checkoutRequestID'] == null) {
        setState(() {
          _loading = false;
          _state = PaymentState.error;
          _statusMessage =
              'Failed to send payment request: ${res['message'] ?? 'Unknown'}';
        });

        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Payment error'),
            content: Text(_statusMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Now poll for status up to 60s
      setState(() {
        _state = PaymentState.waitingPin;
        _statusMessage = 'Check your phone for the M-Pesa prompt';
      });

      final checkout = res['checkoutRequestID'] as String;
      final end = DateTime.now().add(const Duration(seconds: 60));
      var completed = false;
      while (DateTime.now().isBefore(end)) {
        await Future.delayed(const Duration(seconds: 5));
        final status = await MpesaService().querySTKPushStatus(checkout);
        if (status == 'completed') {
          completed = true;
          break;
        }
        if (status == 'failed') break;
      }

      setState(() => _loading = false);

      if (completed) {
        // Save to Firestore
        final u = FirebaseAuth.instance.currentUser;
        await FirebaseFirestore.instance.collection('payments').add({
          'userId': u?.uid,
          'roomNumber': room,
          'amount': amount,
          'phoneNumber': phone,
          'mpesaReceiptNumber': res['raw']?['CheckoutRequestID'] ?? checkout,
          'transactionDate': FieldValue.serverTimestamp(),
          'status': 'completed',
          'checkoutRequestID': checkout,
          'completedAt': DateTime.now().toIso8601String(),
        });

        setState(() {
          _state = PaymentState.success;
          _statusMessage = 'Payment completed!';
        });

        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Success'),
            content: Text(
              'Payment of KES ${NumberFormat.decimalPattern().format(amount)} completed.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        setState(() {
          _state = PaymentState.error;
          _statusMessage = 'Payment timed out or failed';
        });

        final choice = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Payment not completed'),
            content: const Text(
              'The payment was not completed. Retry or queue to process when online?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop('retry'),
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('queue'),
                child: const Text('Queue'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('cancel'),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );

        if (choice == 'retry') {
          await _confirmAndPayOnline(phone, amount, room);
        } else if (choice == 'queue') {
          await _queuePayment(phone, amount, room);
        }
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _state = PaymentState.error;
        _statusMessage = 'Payment failed: $e';
      });

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Payment failed'),
          content: Text('Payment failed: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _confirmAndQueue(
    String phone,
    double amount,
    String room,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Queue payment'),
        content: Text(
          'You are offline. Queue payment of KES ${NumberFormat.decimalPattern().format(amount)} from $phone?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Queue'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _queuePayment(phone, amount, room);
  }

  Future<void> _queuePayment(String phone, double amount, String room) async {
    final u = FirebaseAuth.instance.currentUser;
    final payload = {
      'userId': u?.uid,
      'roomNumber': room,
      'amount': amount,
      'phoneNumber': phone,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'queued',
    };

    await SyncManager.instance.addAction('mpesa_payment', payload);

    setState(() {
      _state = PaymentState.queued;
      _statusMessage = 'Payment queued. Will process when online.';
    });

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Queued'),
        content: const Text(
          'Payment queued. It will sync when connection is restored.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      colors: [Color(0xFF052A6E), Color(0xFF5BC0FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Pay Rent', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A8A),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            color: Colors.white,
            onPressed: () =>
                Navigator.of(context).pushNamed('/payment-history'),
            tooltip: 'View Payment History',
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(gradient: gradient),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: ConnectivityService.instance.isOnline,
                      builder: (context, isOnline, _) {
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isOnline
                                ? Colors.green.shade700
                                : Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isOnline ? Icons.wifi : Icons.wifi_off,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isOnline
                                      ? 'Online'
                                      : 'Offline - Payments will be queued',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              if (!_isOnline) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.info, color: Colors.white),
                              ],
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    LayoutBuilder(
                      builder: (context, c) {
                        final w = c.maxWidth;
                        final isMobile = w < 600;
                        final isTablet = w >= 600 && w < 900;
                        final isDesktop = w >= 900;

                        final cardMaxWidth = isDesktop
                            ? 800.0
                            : (isTablet ? 600.0 : double.infinity);

                        return Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: cardMaxWidth),
                            child: Card(
                              color: Colors.black.withOpacity(0.25),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),

                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pay Rent',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Responsive fields
                                      isMobile
                                          ? Column(
                                              children: [
                                                Semantics(
                                                  label:
                                                      'Phone number input field',
                                                  hint:
                                                      'Enter your M-Pesa phone number starting with 07 or 254',
                                                  child: TextFormField(
                                                    controller: _phoneCtl,
                                                    decoration:
                                                        _inputDecoration(
                                                          'Phone number',
                                                          hint: '07XXXXXXXX',
                                                        ),
                                                    validator: _validatePhone,
                                                    keyboardType:
                                                        TextInputType.phone,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                Semantics(
                                                  label: 'Amount',
                                                  child: TextFormField(
                                                    controller: _amountCtl,
                                                    decoration:
                                                        _inputDecoration(
                                                          'Amount',
                                                        ),
                                                    readOnly: true,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Row(
                                              children: [
                                                Expanded(
                                                  child: Semantics(
                                                    label:
                                                        'Phone number input field',
                                                    hint:
                                                        'Enter your M-Pesa phone number starting with 07 or 254',
                                                    child: TextFormField(
                                                      controller: _phoneCtl,
                                                      decoration:
                                                          _inputDecoration(
                                                            'Phone number',
                                                            hint: '07XXXXXXXX',
                                                          ),
                                                      validator: _validatePhone,
                                                      keyboardType:
                                                          TextInputType.phone,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                SizedBox(
                                                  width: 160,
                                                  child: Semantics(
                                                    label: 'Amount',
                                                    child: TextFormField(
                                                      controller: _amountCtl,
                                                      decoration:
                                                          _inputDecoration(
                                                            'Amount',
                                                          ),
                                                      readOnly: true,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),

                                      const SizedBox(height: 12),
                                      Semantics(
                                        label: 'Room number',
                                        child: TextFormField(
                                          controller: _roomCtl,
                                          decoration: _inputDecoration(
                                            'Room number',
                                          ),
                                          readOnly: true,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 18),

                                      // Status message (live region)
                                      Semantics(
                                        liveRegion: true,
                                        label: _statusMessage,
                                        child: Text(
                                          _statusMessage,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: Semantics(
                                              button: true,
                                              label:
                                                  'Pay ${NumberFormat.decimalPattern().format(_amount)} KES with M-Pesa',
                                              enabled: !_loading,
                                              child: ElevatedButton(
                                                onPressed: _loading
                                                    ? null
                                                    : _payPressed,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF00B848,
                                                  ),
                                                  foregroundColor: Colors.white,
                                                  minimumSize: const Size(
                                                    0,
                                                    50,
                                                  ),
                                                ),
                                                child: _loading
                                                    ? const SizedBox(
                                                        height: 20,
                                                        width: 20,
                                                        child: CircularProgressIndicator(
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                Color
                                                              >(Colors.white),
                                                          strokeWidth: 2,
                                                        ),
                                                      )
                                                    : const Text(
                                                        'Pay with M-Pesa',
                                                      ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          OutlinedButton(
                                            onPressed: () => Navigator.of(
                                              context,
                                            ).pushNamed('/payment-history'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              side: const BorderSide(
                                                color: Colors.white,
                                              ),
                                            ),
                                            child: const Text(
                                              'View Payment History',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
