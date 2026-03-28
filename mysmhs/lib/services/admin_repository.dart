import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRepository {
  AdminRepository._();

  static final _db = FirebaseFirestore.instance;

  static Stream<int> totalRoomsCount() => _db
      .collection('rooms')
      .snapshots()
      .map((snapshot) => snapshot.docs.length);

  static Stream<int> occupiedRoomsCount() => _db
      .collection('rooms')
      .where('isOccupied', isEqualTo: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);

  static Stream<int> pendingPaymentsCount() => _db
      .collection('payments')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) => snapshot.docs.length);

  static Stream<int> openMaintenanceCount() => _db
      .collection('maintenance_requests')
      .where('status', isEqualTo: 'open')
      .snapshots()
      .map((snapshot) => snapshot.docs.length);

  static Stream<QuerySnapshot<Map<String, dynamic>>> bookingsPendingStream() =>
      _db
          .collection('bookings')
          .where('status', isEqualTo: 'pending')
          .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> paymentsPendingStream() =>
      _db
          .collection('payments')
          .where('status', isEqualTo: 'pending')
          .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> maintenanceOpenStream() =>
      _db
          .collection('maintenance_requests')
          .where('status', isEqualTo: 'open')
          .snapshots();

  static Future<int> fetchTotalRoomsCount() async {
    final snapshot = await _db.collection('rooms').get();
    return snapshot.docs.length;
  }

  static Future<int> fetchOccupiedRoomsCount() async {
    final snapshot = await _db
        .collection('rooms')
        .where('isOccupied', isEqualTo: true)
        .get();
    return snapshot.docs.length;
  }

  static Future<int> fetchPendingPaymentsCount() async {
    final snapshot = await _db
        .collection('payments')
        .where('status', isEqualTo: 'pending')
        .get();
    return snapshot.docs.length;
  }

  static Future<int> fetchOpenMaintenanceCount() async {
    final snapshot = await _db
        .collection('maintenance_requests')
        .where('status', isEqualTo: 'open')
        .get();
    return snapshot.docs.length;
  }

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchOpenMaintenanceRequests() async {
    final snapshot = await _db
        .collection('maintenance_requests')
        .where('status', isEqualTo: 'open')
        .limit(10)
        .get();
    return snapshot.docs;
  }

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchPendingBookings() async {
    final snapshot = await _db
        .collection('bookings')
        .where('status', isEqualTo: 'pending')
        .limit(10)
        .get();
    return snapshot.docs;
  }

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchPendingPayments() async {
    final snapshot = await _db
        .collection('payments')
        .where('status', isEqualTo: 'pending')
        .limit(10)
        .get();
    return snapshot.docs;
  }
}
