import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore helpers for admin-facing queries.
/// Keeps query logic separate from UI so it's testable and reusable.
class AdminRepository {
  AdminRepository._();

  static final _db = FirebaseFirestore.instance;

  /// Streams the total number of documents in `rooms`.
  static Stream<int> totalRoomsCount() =>
      _db.collection('rooms').snapshots().map((s) => s.docs.length);

  /// Streams the number of rooms where `isOccupied == true`.
  static Stream<int> occupiedRoomsCount() => _db
      .collection('rooms')
      .where('isOccupied', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.length);

  /// Streams count of payments where `status == "pending"`.
  static Stream<int> pendingPaymentsCount() => _db
      .collection('payments')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => s.docs.length);

  /// Streams count of open maintenance requests.
  static Stream<int> openMaintenanceCount() => _db
      .collection('maintenance_requests')
      .where('status', isEqualTo: 'open')
      .snapshots()
      .map((s) => s.docs.length);

  /// Firestore streams used by admin pages
  static Stream<QuerySnapshot<Map<String, dynamic>>> bookingsPendingStream() =>
      _db
          .collection('bookings')
          .where('status', isEqualTo: 'pending')
          .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> maintenanceOpenStream() =>
      _db
          .collection('maintenance_requests')
          .where('status', isEqualTo: 'open')
          .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> paymentsPendingStream() =>
      _db
          .collection('payments')
          .where('status', isEqualTo: 'pending')
          .snapshots();

  /// Helper to check whether a user is admin (reads `users/{uid}.role`).
  static Future<bool> isAdmin(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final role = (doc.data()?['role'] as String?) ?? 'student';
    return role == 'admin';
  }
}
