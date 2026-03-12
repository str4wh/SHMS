# Student Hostel Management System (SHMS) Documentation

---

## 1. Application Overview

**SHMS** is a comprehensive Flutter application designed to streamline hostel management for both students and administrators. It provides a seamless experience for room booking, payments, maintenance reporting, and administrative oversight.

- **Target Users:**
  - Students: Manage bookings, payments, maintenance requests.
  - Administrators: Oversee room allocations, payments, maintenance, and analytics.
- **Technology Stack:**
  - Flutter (cross-platform UI)
  - Firebase (Authentication, Firestore, Storage)
  - M-Pesa (secure mobile payment integration)

---

## 2. Why This App is Unique

- **Unique Features:**
  - Offline-first architecture: Works reliably even with intermittent connectivity.
  - Real-time synchronization: Instant updates across devices.
  - Secure M-Pesa payment integration: Native STK Push, offline queueing.
  - Role-based access: Distinct flows for students and admins.
  - Image compression and upload: Efficient room image management.
  - Maintenance reporting: Streamlined issue tracking.
- **Differentiation:**
  - Combines offline and real-time capabilities.
  - Robust payment and booking workflows.
  - Advanced analytics and reporting for admins.

---

## 3. Complete User Journey & Page Flow

### For Students

#### Landing Page ([landingpage.dart](mysmhs/lib/landingpage.dart))

- **What users see:** Welcome screen, app branding, brief intro.
- **Actions:**
  - Get Started: Navigates to authentication.
  - Login: Direct access for returning users.

#### Authentication Page ([authpage.dart](mysmhs/lib/authpage.dart))

- **Login:** Email/password, Google sign-in, M-Pesa phone number.
- **Sign-up:** New account creation, role selection (student/admin).
- **Password Reset:** Email-based reset flow.
- **Role Selection:** Determines access and navigation.

#### Student Dashboard ([student_dashboard_page.dart](mysmhs/lib/student_dashboard_page.dart))

- **Real-time Data:** Bookings, payments, room status.
- **Actions:**
  - Browse rooms
  - View booking status
  - Access payment history
  - Report maintenance

#### Room Details Page ([room_details_page.dart](mysmhs/lib/room_details_page.dart))

- **Information:** Room images, amenities, availability, price.
- **Booking:** Initiate booking, view status.
- **Room Switching:** Request switch, approval workflow.

#### Pay Rent Page ([pay_rent_page.dart](mysmhs/lib/pay_rent_page.dart))

- **Payment Form:** Rent details, amount, due date.
- **M-Pesa Integration:** STK Push, payment status polling.
- **Offline Queueing:** Payments queued if offline, synced later.

#### Report Maintenance Page ([report_maintenance_page.dart](mysmhs/lib/report_maintenance_page.dart))

- **Reporting:** Issue description, image upload, status tracking.

#### Payment History Page ([payment_history_page.dart](mysmhs/lib/payment_history_page.dart))

- **Transactions:** List of payments, status, receipts.

---

### For Administrators

#### Admin Dashboard ([admin_dashboard_page.dart](mysmhs/lib/admin_dashboard_page.dart))

- **Metrics:** Total rooms, occupancy, pending payments, maintenance requests.
- **Quick Actions:** Approve bookings, manage rooms, review payments.

#### Manage Rooms Page ([admin_rooms_page.dart](mysmhs/lib/admin_rooms_page.dart))

- **Room Listing:** All rooms, search, filter by status/amenities.

#### Add/Edit Room Page ([add_edit_room_page.dart](mysmhs/lib/add_edit_room_page.dart))

- **Creation:** Room details, amenities, price, image upload.
- **Image Compression:** Optimizes uploads for speed/storage.
- **Offline Persistence:** Room data cached locally, synced when online.

---

## 4. Core Functions & Operations

### Authentication & Authorization

- **Firebase Authentication:**
  - Email/password, Google, phone number.
  - Role-based access (student/admin).
- **Session Management:**
  - Persistent login, session timeout.
- **Offline Authentication Caching:**
  - Credentials cached for offline access.

### Room Management

- **CRUD Operations:**
  - Create, update, delete, view rooms.
- **Image Upload/Storage:**
  - Firebase Storage, compression before upload.
- **Availability Tracking:**
  - Real-time updates via Firestore streams.

### Booking System

- **Booking Workflow:**
  - Request booking, admin approval, status updates.
- **Room Switching:**
  - Student requests, admin reviews, real-time update.
- **Transaction Handling:**
  - Linked to payment status, booking confirmation.

### Payment Processing

- **M-Pesa STK Push:**
  - Initiates payment, handles callbacks.
- **Status Polling:**
  - Checks payment status, updates records.
- **Offline Queueing:**
  - Payments stored locally, retried when online.
- **History Tracking:**
  - All transactions logged, accessible to user.

### Offline Functionality

- **Local Data Caching:**
  - Hive/SQLite for offline storage.
- **Connectivity Monitoring:**
  - Detects online/offline state, triggers sync.
- **Sync Queue Management:**
  - Pending actions queued, retried with exponential backoff.
- **Room Sync Service:**
  - Ensures room data consistency across devices.

---

## 5. Computations & Data Processing

### Financial Calculations

- **Rent Formatting:**
  - Currency formatting, locale-aware.
- **Due Date Calculations:**
  - Computes next payment date, overdue status.
- **Currency Conversion:**
  - Handles KES (M-Pesa), supports formatting.

### Date & Time Operations

- **Booking Ranges:**
  - Validates booking start/end dates.
- **Payment Due Dates:**
  - Calculates based on booking, rent cycle.
- **Timestamp Sync:**
  - Ensures consistency across devices.

### Image Processing

- **Compression Algorithms:**
  - Reduces file size before upload.
- **Optimization:**
  - Balances quality and speed.
- **Upload Progress:**
  - Tracks and displays progress to user.

### Data Synchronization

- **Conflict Resolution:**
  - Handles concurrent updates, merges changes.
- **Retry Logic:**
  - Exponential backoff for failed syncs.
- **Pending Queue:**
  - Manages actions awaiting sync.

---

## 6. Reports & Analytics

### Student-Facing Reports

- Booking status
- Payment history
- Maintenance request status
- Room availability dashboard

### Admin-Facing Reports

- Total rooms count
- Occupied vs available rooms
- Pending payments summary
- Open maintenance requests
- Booking approval queue
- Payment status overview

### Real-Time Metrics

- Live room availability
- Active bookings count
- Payment status indicators
- Maintenance request statistics

---

## 7. Technical Architecture

### State Management

- **Real-Time Streams:**
  - Firestore streams, StreamBuilder for UI updates.
- **Usage Patterns:**
  - StreamBuilder wraps lists, dashboards, metrics.

### Firebase Integration

- **Firestore Collections:**
  - `rooms`, `bookings`, `payments`, `maintenance`, `users`.
- **Document Structure:**
  - Each entity has unique ID, timestamps, status fields.
- **Storage:**
  - Images stored in Firebase Storage, linked by URL.
- **Cloud Functions:**
  - M-Pesa payment callbacks, status updates.

### Offline-First Design

- **Hive Database:**
  - Local storage for rooms, bookings, payments.
- **Cache Strategy:**
  - Data cached, synced on connectivity.
- **Sync Mechanism:**
  - Sync manager handles retries, conflict resolution.

---

## 8. Security Features

- **Authentication Security:**
  - Firebase Auth, secure session tokens.
- **Data Encryption:**
  - Sensitive data stored with Flutter Secure Storage.
- **Role-Based Permissions:**
  - Access control enforced throughout app.
- **Transaction Security:**
  - M-Pesa integration, secure callbacks, validation.

---

## 9. User Experience Features

- **Responsive Design:**
  - Adapts to mobile, tablet, desktop.
- **Accessibility:**
  - Semantics, screen reader support.
- **Loading States:**
  - Progress indicators, skeleton screens.
- **Error Handling:**
  - User-friendly error messages, retry options.
- **Offline Indicators:**
  - Visual cues for offline/online status.

---

## Code Examples & Implementation Details

### Example: Room Booking (room_details_page.dart)

```dart
// Booking a room
void bookRoom(String roomId) async {
  final booking = Booking(
    roomId: roomId,
    userId: currentUser.id,
    status: 'pending',
    timestamp: DateTime.now(),
  );
  await bookingRepository.createBooking(booking);
}
```

### Example: Payment Processing (pay_rent_page.dart)

```dart
// Initiate M-Pesa payment
void initiatePayment(double amount) async {
  final result = await mpesaService.stkPush(amount, userPhone);
  if (result.success) {
    paymentRepository.recordPayment(result.transactionId);
  } else {
    offlineQueue.addPayment(amount, userPhone);
  }
}
```

### Example: Offline Sync (sync_manager.dart)

```dart
// Sync queued actions
void syncPendingActions() async {
  for (final action in syncQueue) {
    try {
      await action.execute();
      syncQueue.remove(action);
    } catch (e) {
      // Retry with exponential backoff
      await Future.delayed(Duration(seconds: backoff));
    }
  }
}
```

---

## Conclusion

SHMS is a robust, offline-capable hostel management solution with real-time updates, secure payments, and advanced reporting. Its modular architecture, strong security, and responsive design make it ideal for both students and administrators.

For further details, refer to the source code and guides included in the repository.
