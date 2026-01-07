// ignore_for_file: unused_local_variable, prefer_const_constructors, depend_on_referenced_packages

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Student Dashboard — main page students see after logging in.
/// - Real-time streams from Firestore
/// - Responsive layout
/// - Drawer navigation
class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  final uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const _gradient = LinearGradient(
      colors: [Color(0xFF052A6E), Color(0xFF5BC0FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Student Dashboard',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1E3A8A),
        ),
        body: const Center(
          child: Text('Please sign in', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final userDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots();
    final roomsStream = FirebaseFirestore.instance
        .collection('rooms')
        .snapshots();
    final bookingsStream = FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .snapshots();
    final paymentsStream = FirebaseFirestore.instance
        .collection('payments')
        .where('userId', isEqualTo: uid)
        .snapshots();
    final maintenanceStream = FirebaseFirestore.instance
        .collection('maintenance_requests')
        .where('userId', isEqualTo: uid)
        .where('status', whereIn: ['open', 'pending'])
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Student Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications),
            tooltip: 'Notifications',
          ),
        ],
      ),
      drawer: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userDocStream,
        builder: (context, snap) {
          final name = snap.data?.data()?['name'] as String? ?? 'Student';
          return _AppDrawer(studentName: name);
        },
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(gradient: _gradient),
          child: RefreshIndicator(
            onRefresh: () async {
              // Simple refresh trigger - StreamBuilders will auto-update when remote changes
              setState(() {});
              await Future<void>.delayed(const Duration(milliseconds: 300));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: userDocStream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return _buildErrorCard(
                              'Failed to load profile',
                              () => setState(() {}),
                            );
                          }
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return SizedBox(
                              height: 120,
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            );
                          }

                          final data = snapshot.data?.data() ?? {};
                          final name = data['name'] as String? ?? 'Student';
                          final assignedRoomRaw = data['assignedRoom'];
                          final assignedRoom =
                              assignedRoomRaw?.toString() ?? '—';

                          return _SummaryCard(
                            studentName: name,
                            assignedRoom: assignedRoom,
                            bookingStatusStream: bookingsStream,
                            paymentsStream: paymentsStream,
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Metrics row
                      LayoutBuilder(
                        builder: (context, cstr) {
                          final w = cstr.maxWidth;
                          final isDesktop = w >= 1200;
                          final isTablet = w >= 600 && w < 1200;
                          final cols = isDesktop ? 3 : (isTablet ? 3 : 1);
                          return GridView.count(
                            crossAxisCount: cols,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            children: [
                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: paymentsStream,
                                builder: (context, snap) {
                                  if (snap.hasError) {
                                    return _MetricCard(
                                      title: 'Rent Status',
                                      value: 'Error',
                                      semanticHint: 'Rent status',
                                    );
                                  }
                                  if (snap.connectionState ==
                                      ConnectionState.waiting) {
                                    return _MetricCard(
                                      title: 'Rent Status',
                                      value: 'Loading',
                                      semanticHint: 'Rent status',
                                    );
                                  }

                                  final docs = snap.data?.docs ?? [];
                                  String status = 'No records';
                                  double amount = 0.0;
                                  DateTime? nextDue;

                                  if (docs.isNotEmpty) {
                                    // pick the nearest dueDate in future or the latest
                                    docs.sort((a, b) {
                                      final aDate =
                                          (a.data()['dueDate'] as Timestamp?)
                                              ?.toDate() ??
                                          DateTime.fromMillisecondsSinceEpoch(
                                            0,
                                          );
                                      final bDate =
                                          (b.data()['dueDate'] as Timestamp?)
                                              ?.toDate() ??
                                          DateTime.fromMillisecondsSinceEpoch(
                                            0,
                                          );
                                      return aDate.compareTo(bDate);
                                    });
                                    final next = docs.firstWhere((d) {
                                      final due =
                                          (d.data()['dueDate'] as Timestamp?)
                                              ?.toDate();
                                      return due == null ||
                                          due.isAfter(DateTime.now());
                                    }, orElse: () => docs.last);

                                    status =
                                        (next.data()['status'] as String?) ??
                                        'Due';
                                    amount =
                                        (next.data()['amount'] as num?)
                                            ?.toDouble() ??
                                        0.0;
                                    nextDue =
                                        (next.data()['dueDate'] as Timestamp?)
                                            ?.toDate();
                                  }

                                  return _MetricCard(
                                    title: 'Rent Status',
                                    value: status == 'paid'
                                        ? 'Paid'
                                        : 'Due KES ${_formatCurrency(amount)}',
                                    semanticHint:
                                        'Shows whether rent is paid or due',
                                  );
                                },
                              ),
                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: paymentsStream,
                                builder: (context, snap) {
                                  if (snap.hasError) {
                                    return _MetricCard(
                                      title: 'Next Payment',
                                      value: 'Error',
                                      semanticHint: 'Next payment date',
                                    );
                                  }
                                  if (snap.connectionState ==
                                      ConnectionState.waiting) {
                                    return _MetricCard(
                                      title: 'Next Payment',
                                      value: 'Loading',
                                      semanticHint: 'Next payment date',
                                    );
                                  }

                                  final docs = snap.data?.docs ?? [];
                                  DateTime? nextDue;
                                  if (docs.isNotEmpty) {
                                    final dates = docs
                                        .map(
                                          (d) =>
                                              (d.data()['dueDate']
                                                      as Timestamp?)
                                                  ?.toDate(),
                                        )
                                        .whereType<DateTime>()
                                        .toList();
                                    dates.sort();
                                    nextDue = dates.isNotEmpty
                                        ? dates.firstWhere(
                                            (d) => d.isAfter(DateTime.now()),
                                            orElse: () => dates.last,
                                          )
                                        : null;
                                  }
                                  final dateStr = nextDue == null
                                      ? 'No upcoming'
                                      : _formatDate(nextDue);
                                  return _MetricCard(
                                    title: 'Next Payment',
                                    value: dateStr,
                                    semanticHint: 'Next payment date',
                                  );
                                },
                              ),
                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: maintenanceStream,
                                builder: (context, snap) {
                                  if (snap.hasError) {
                                    return _MetricCard(
                                      title: 'Open Maintenance',
                                      value: 'Error',
                                      semanticHint: 'Open maintenance count',
                                    );
                                  }
                                  if (snap.connectionState ==
                                      ConnectionState.waiting) {
                                    return _MetricCard(
                                      title: 'Open Maintenance',
                                      value: '...',
                                      semanticHint: 'Open maintenance count',
                                    );
                                  }

                                  final count = snap.data?.docs.length ?? 0;
                                  return _MetricCard(
                                    title: 'Open Maintenance',
                                    value: '$count',
                                    semanticHint: 'Maintenance requests open',
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 24),
                      Text(
                        'Available Rooms',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: roomsStream,
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return _buildErrorCard(
                              'Failed to load rooms',
                              () => setState(() {}),
                            );
                          }
                          if (snap.connectionState == ConnectionState.waiting) {
                            return SizedBox(
                              height: 120,
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            );
                          }

                          final docs = snap.data?.docs ?? [];
                          if (docs.isEmpty)
                            return _buildEmptyCard('No rooms available');

                          return LayoutBuilder(
                            builder: (context, cstr) {
                              final w = cstr.maxWidth;
                              final cross = w >= 1200 ? 3 : (w >= 600 ? 2 : 1);

                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: cross,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 0.78,
                                    ),
                                itemCount: docs.length,
                                itemBuilder: (context, i) {
                                  final d = docs[i].data();
                                  final id = docs[i].id;
                                  return RoomCard(
                                    roomId: id,
                                    roomNumber:
                                        d['roomNumber']?.toString() ?? '—',
                                    price:
                                        (d['price'] as num?)?.toDouble() ?? 0.0,
                                    images:
                                        (d['images'] as List?)
                                            ?.cast<String>() ??
                                        const [],
                                    availability:
                                        d['availability'] as String? ??
                                        (d['isOccupied'] == true
                                            ? 'occupied'
                                            : 'available'),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message, VoidCallback onRetry) => Card(
    color: Colors.white.withOpacity(0.06),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.white70)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );

  Widget _buildEmptyCard(String message) => Card(
    color: Colors.white.withOpacity(0.06),
    child: Padding(
      padding: const EdgeInsets.all(18.0),
      child: Center(
        child: Text(message, style: TextStyle(color: Colors.white70)),
      ),
    ),
  );

  static String _formatCurrency(double amount) {
    // Basic thousands separator
    final s = amount.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final pos = s.length - i;
      buffer.write(s[i]);
      if (pos > 1 && pos % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ------------------------------
// Widgets
// ------------------------------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.studentName,
    required this.assignedRoom,
    required this.bookingStatusStream,
    required this.paymentsStream,
  });

  final String studentName;
  final String assignedRoom;
  final Stream<QuerySnapshot<Map<String, dynamic>>> bookingStatusStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> paymentsStream;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: 'Student summary',
      child: Card(
        color: Colors.white.withOpacity(0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Room: $assignedRoom',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.92),
                        ),
                      ),
                    ],
                  ),
                  // Booking status pill
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: bookingStatusStream,
                    builder: (context, snap) {
                      if (snap.hasError)
                        return _statusBadge('Unknown', Colors.white70);
                      if (snap.connectionState == ConnectionState.waiting)
                        return _statusBadge('Loading', Colors.white70);

                      final docs = snap.data?.docs ?? [];
                      final status = docs.isEmpty
                          ? 'No booking'
                          : (docs.last.data()['status'] as String? ??
                                'Unknown');

                      Color badgeColor;
                      switch (status.toLowerCase()) {
                        case 'active':
                          badgeColor = Colors.green.shade400;
                          break;
                        case 'pending':
                          badgeColor = Colors.amber.shade600;
                          break;
                        case 'expired':
                          badgeColor = Colors.red.shade400;
                          break;
                        default:
                          badgeColor = Colors.white70;
                      }

                      return _statusBadge(
                        status[0].toUpperCase() + status.substring(1),
                        badgeColor,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Quick actions
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/pay-rent'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF052A6E),
                    ),
                    child: const Text('Pay Rent'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/report-maintenance'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                    child: const Text('Report Maintenance'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String text, Color color) => Semantics(
    label: 'Booking status $text',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.semanticHint,
  });
  final String title;
  final String value;
  final String semanticHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: title,
      hint: semanticHint,
      liveRegion: true,
      child: Card(
        color: Colors.white.withOpacity(0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.92),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoomCard extends StatefulWidget {
  const RoomCard({
    required this.roomId,
    required this.roomNumber,
    required this.price,
    required this.images,
    required this.availability,
    super.key,
  });

  final String roomId;
  final String roomNumber;
  final double price;
  final List<String> images;
  final String availability;

  @override
  State<RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<RoomCard> {
  late final PageController _pc;
  int _page = 0;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _pc = PageController();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _prev() {
    final len = widget.images.length;
    if (len == 0) return;
    final prev = (_page - 1 + len) % len;
    _pc.animateToPage(
      prev,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _next() {
    final len = widget.images.length;
    if (len == 0) return;
    final next = (_page + 1) % len;
    _pc.animateToPage(
      next,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color badgeColor;
    String statusText;
    switch (widget.availability.toLowerCase()) {
      case 'available':
        badgeColor = Colors.green.shade400;
        statusText = 'Available';
        break;
      case 'occupied':
        badgeColor = Colors.red.shade400;
        statusText = 'Occupied';
        break;
      default:
        badgeColor = Colors.amber.shade600;
        statusText = 'Maintenance';
    }

    return Semantics(
      container: true,
      label: 'Room ${widget.roomNumber}',
      hint: 'Status: $statusText',
      child: Card(
        color: Colors.white.withOpacity(0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image carousel area
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  color: Colors.white10,
                ),
                child: MouseRegion(
                  onEnter: (_) => setState(() => _hover = true),
                  onExit: (_) => setState(() => _hover = false),
                  child: Stack(
                    children: [
                      // PageView (images or placeholder)
                      PageView.builder(
                        controller: _pc,
                        itemCount: widget.images.isNotEmpty
                            ? widget.images.length
                            : 1,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (context, index) {
                          if (widget.images.isEmpty) {
                            return Center(
                              child: Icon(
                                Icons.bed,
                                size: 48,
                                color: Colors.white70,
                              ),
                            );
                          }

                          final url = widget.images[index];
                          return CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, err) => Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.white70,
                              ),
                            ),
                          );
                        },
                      ),

                      // Left arrow
                      if (widget.images.length >= 2 && (kIsWeb ? _hover : true))
                        Positioned(
                          left: 8,
                          top: 0,
                          bottom: 0,
                          child: Semantics(
                            button: true,
                            label: 'Previous image',
                            child: GestureDetector(
                              onTap: _prev,
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Center(
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.chevron_left,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Right arrow
                      if (widget.images.length >= 2 && (kIsWeb ? _hover : true))
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Semantics(
                            button: true,
                            label: 'Next image',
                            child: GestureDetector(
                              onTap: _next,
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Center(
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.chevron_right,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Page indicators
                      if (widget.images.length >= 2)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 8,
                          child: Semantics(
                            label:
                                'Image ${_page + 1} of ${widget.images.length}',
                            liveRegion: true,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(widget.images.length, (
                                i,
                              ) {
                                final active = i == _page;
                                return Container(
                                  width: active ? 10 : 8,
                                  height: active ? 10 : 8,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Room ${widget.roomNumber}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'KES ${_formatCurrency(widget.price)}/month',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.92),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: badgeColor,
                        ),
                        child: Text(
                          statusText,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const Spacer(),
                      if (widget.availability.toLowerCase() == 'available')
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pushNamed(
                            '/room-details',
                            arguments: {'roomId': widget.roomId},
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF052A6E),
                          ),
                          child: const Text('View Details'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatCurrency(double amount) {
    return amount.round().toString();
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.studentName});
  final String studentName;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF052A6E), Color(0xFF5BC0FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Colors.transparent),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white24,
                      child: const Icon(Icons.school, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        studentName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _drawerItem(
                context,
                icon: Icons.house,
                label: 'View Rooms',
                route: '/student-dashboard',
                selected: true,
              ),
              _drawerItem(
                context,
                icon: Icons.payment,
                label: 'Pay Rent',
                route: '/pay-rent',
              ),
              _drawerItem(
                context,
                icon: Icons.build,
                label: 'Report Maintenance',
                route: '/report-maintenance',
              ),
              _drawerItem(
                context,
                icon: Icons.receipt_long,
                label: 'Payment History',
                route: '/payment-history',
              ),
              const Spacer(),
              Semantics(
                button: true,
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    final leave = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Sign out'),
                        content: const Text(
                          'Are you sure you want to sign out?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Sign out'),
                          ),
                        ],
                      ),
                    );
                    if (leave == true) await FirebaseAuth.instance.signOut();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    bool selected = false,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        selected: selected,
        selectedColor: Colors.white,
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(route);
        },
      ),
    );
  }
}
