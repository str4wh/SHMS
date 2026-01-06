// ignore_for_file: depend_on_referenced_packages, curly_braces_in_flow_control_structures

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RoomDetailsPage extends StatefulWidget {
  const RoomDetailsPage({super.key, this.roomId});
  final String? roomId;

  @override
  State<RoomDetailsPage> createState() => _RoomDetailsPageState();
}

class _RoomDetailsPageState extends State<RoomDetailsPage> {
  bool _isBooking = false;

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final id = widget.roomId ?? args?['roomId'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Room Details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF052A6E), Color(0xFF5BC0FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: id == null
            ? const Center(
                child: Text(
                  'No room selected',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              )
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('rooms')
                    .doc(id)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading room details',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Go Back'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    );
                  }

                  final data = snap.data?.data() ?? {};
                  final images =
                      (data['images'] as List?)?.cast<String>() ?? [];
                  final availability =
                      (data['availability'] as String?) ?? 'available';

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image section
                        if (images.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: images.first,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 250,
                              placeholder: (context, url) => Container(
                                height: 250,
                                color: Colors.white10,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: 250,
                                color: Colors.white10,
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 64,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            height: 250,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.bed,
                                size: 80,
                                color: Colors.white70,
                              ),
                            ),
                          ),

                        const SizedBox(height: 20),

                        // Room info card
                        Card(
                          color: Colors.white.withOpacity(0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Room ${data['roomNumber'] ?? '—'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(availability),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        availability.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                Row(
                                  children: [
                                    const Icon(
                                      Icons.attach_money,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'KES ${(data['price'] as num?)?.toString() ?? '-'} / month',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Colors.white.withOpacity(
                                              0.95,
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),
                                const Divider(color: Colors.white24),
                                const SizedBox(height: 12),

                                Text(
                                  'Description',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  data['description'] ??
                                      'No description available',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Action button (if available)
                        if (availability.toLowerCase() == 'available')
                          SizedBox(
                            width: double.infinity,
                            child: Semantics(
                              button: true,
                              label: 'Book this room',
                              child: ElevatedButton.icon(
                                onPressed: _isBooking
                                    ? null
                                    : () => _handleBook(context, id, data),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF052A6E),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: _isBooking
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Color(0xFF052A6E),
                                              ),
                                        ),
                                      )
                                    : const Icon(Icons.book_online),
                                label: _isBooking
                                    ? const Text(
                                        'Booking...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : const Text(
                                        'Book This Room',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _handleBook(
    BuildContext context,
    String roomId,
    Map<String, dynamic> roomData,
  ) async {
    // Validate user logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Not logged in'),
          content: const Text('You must be logged in to book a room'),
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

    final uid = user.uid;

    // Check user doesn't already have an active/pending booking
    try {
      final existing = await FirebaseFirestore.instance
          .collection('bookings')
          .where('studentID', isEqualTo: uid)
          .where('status', whereIn: ['approved', 'pending/approved', 'pending'])
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Existing booking'),
            content: const Text(
              'You already have an active booking. Cancel your existing booking first.',
            ),
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
    } catch (e) {
      // Ignore query errors for now; proceed and let transaction catch issues
    }

    // Ensure room is still available
    try {
      final roomSnap = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .get();
      final currentAvailability =
          (roomSnap.data()?['availability'] as String?) ?? 'available';
      if (currentAvailability.toLowerCase() != 'available') {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Room unavailable'),
            content: const Text(
              'Sorry, this room was just booked by someone else',
            ),
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
    } catch (e) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text('Booking failed: $e. Please try again.'),
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

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room: ${roomData['roomNumber'] ?? '—'}'),
            const SizedBox(height: 8),
            Text(
              'Price: KES ${(roomData['price'] as num?)?.toString() ?? '-'} / month',
            ),
            const SizedBox(height: 12),
            const Text('Are you sure you want to book this room?'),
          ],
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

    // Proceed to create booking in a transaction
    setState(() => _isBooking = true);

    final bookingRef = FirebaseFirestore.instance.collection('bookings').doc();
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final freshRoom = await tx.get(roomRef);
        if (!freshRoom.exists) throw Exception('Room not found');
        final availability =
            (freshRoom.data()?['availability'] as String?) ?? 'available';
        if (availability.toLowerCase() != 'available')
          throw Exception('Room no longer available');

        final now = DateTime.now();
        final end = DateTime.now().add(const Duration(days: 30));

        tx.set(bookingRef, {
          'studentID': uid,
          'roomID': roomId,
          'roomNumber': roomData['roomNumber'] ?? '',
          'price': roomData['price'] ?? 0,
          'status': 'approved',
          'bookingDate': FieldValue.serverTimestamp(),
          'startDate': Timestamp.fromDate(now),
          'endDate': Timestamp.fromDate(end),
        });

        tx.update(roomRef, {
          'availability': 'occupied',
          'isOccupied': true,
          'occupiedBy': uid,
        });

        tx.set(userRef, {
          'assignedRoom': roomData['roomNumber'] ?? '',
          'roomId': roomId,
        }, SetOptions(merge: true));
      });

      // Success
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Success'),
          content: const Text('Room booked successfully!'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      Navigator.of(context).pushReplacementNamed('/student-dashboard');
    } catch (e) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Booking failed'),
          content: Text('Booking failed: $e. Please try again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green.shade600;
      case 'occupied':
        return Colors.red.shade600;
      case 'maintenance':
        return Colors.amber.shade700;
      default:
        return Colors.grey.shade600;
    }
  }
}
