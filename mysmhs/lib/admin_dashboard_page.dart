// ignore_for_file: unused_local_variable, curly_braces_in_flow_control_structures

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'services/admin_repository.dart';

/// Admin Dashboard — displays real-time metrics and quick actions backed by Firestore.
/// UI aims to be production-ready: responsive, Material 3, and cleanly separated from Firestore queries.
class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isWide = mq.size.width > 800;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const _gradient = LinearGradient(
      colors: [Color(0xFF052A6E), Color(0xFF5BC0FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      // Transparent so the page gradient shows behind the scaffold
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: false,
        backgroundColor: const Color(
          0xFF1E3A8A,
        ), // dark blue that complements the gradient
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(gradient: _gradient),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overview',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Metrics — responsive grid (1/2/4 columns)
                    LayoutBuilder(
                      builder: (context, cstr) {
                        final w = cstr.maxWidth;
                        final isDesktop = w >= 1200;
                        final isTablet = w >= 600 && w < 1200;
                        final metricsColumns = isDesktop
                            ? 4
                            : (isTablet ? 2 : 1);
                        final metricChildAspect = (w / metricsColumns) > 360
                            ? 3.6
                            : 2.8;

                        final metrics = [
                          {
                            'title': 'Total Rooms',
                            'stream': AdminRepository.totalRoomsCount(),
                            'hint': 'Total number of rooms',
                          },
                          {
                            'title': 'Occupied Rooms',
                            'stream': AdminRepository.occupiedRoomsCount(),
                            'hint': 'Rooms currently occupied',
                          },
                          {
                            'title': 'Pending Payments',
                            'stream': AdminRepository.pendingPaymentsCount(),
                            'hint': 'Payments awaiting processing',
                          },
                          {
                            'title': 'Open Maintenance',
                            'stream': AdminRepository.openMaintenanceCount(),
                            'hint': 'Maintenance requests that are open',
                          },
                        ];

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: metricsColumns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: metricChildAspect,
                              ),
                          itemCount: metrics.length,
                          itemBuilder: (context, i) {
                            final m = metrics[i];
                            return _MetricCard(
                              title: m['title'] as String,
                              stream: m['stream'] as Stream<int>,
                              semanticHint: m['hint'] as String,
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                    Text(
                      'Quick Actions',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick actions grid (responsive columns)
                    Builder(
                      builder: (context) {
                        final w = MediaQuery.of(context).size.width;
                        final columns = w >= 1200 ? 4 : (w >= 600 ? 2 : 1);
                        return GridView.count(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _ActionCard(
                              label: 'Add Room',
                              icon: Icons.add,
                              onTap: () =>
                                  Navigator.of(context).pushNamed('/add-room'),
                              hint: 'Create a new room',
                            ),
                            _ActionCard(
                              label: 'Approve Bookings',
                              icon: Icons.check_circle_outline,
                              onTap: () => Navigator.of(
                                context,
                              ).pushNamed('/bookings-approval'),
                              hint: 'Review and approve pending bookings',
                            ),
                            _ActionCard(
                              label: 'View Payments',
                              icon: Icons.payment,
                              onTap: () =>
                                  Navigator.of(context).pushNamed('/payments'),
                              hint: 'View and manage payments',
                            ),
                            _ActionCard(
                              label: 'Assign Maintenance',
                              icon: Icons.build,
                              onTap: () => Navigator.of(
                                context,
                              ).pushNamed('/maintenance'),
                              hint: 'Assign maintenance requests',
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    const SizedBox(height: 8),
                    Text(
                      'Recent activity',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Placeholder for activity feed — keeps the layout from shrinking too small
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 120),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'No recent activity',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
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

// Small reusable metric card that listens to a numeric Stream<int>
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.stream,
    required this.semanticHint,
  });
  final String title;
  final Stream<int> stream;
  final String semanticHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
      color: Colors.white.withOpacity(0.92),
    );
    final valueStyle = theme.textTheme.headlineSmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    );

    /// Build the card with semantics
    return Semantics(
      container: true,
      label: title,
      hint: semanticHint,
      child: Card(
        // Slightly transparent card to sit on the gradient
        color: Colors.white.withOpacity(0.06),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: StreamBuilder<int>(
            stream: stream,
            builder: (context, snapshot) {
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;
              final value = snapshot.data ?? 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: titleStyle),
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    label: '$title value',
                    value: '$value',
                    child: isLoading
                        ? const SizedBox(
                            height: 28,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          )
                        : Text('$value', style: valueStyle),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// Action card button
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.label,
    required this.icon,
    required this.onTap,
    this.hint,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        hint: hint,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.12),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              onPressed: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 28, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(label, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------
// Minimal admin pages required by Quick Actions
// These are small, production-ready pages that operate directly on Firestore.
// -------------------------------------------

class AddRoomPage extends StatefulWidget {
  const AddRoomPage({super.key});

  @override
  State<AddRoomPage> createState() => _AddRoomPageState();
}

class _AddRoomPageState extends State<AddRoomPage> {
  final _formKey = GlobalKey<FormState>();
  final _roomNumberCtl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _roomNumberCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('rooms').add({
        'roomNumber': _roomNumberCtl.text.trim(),
        'isOccupied': false,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Room added')));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to add room')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Room')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _roomNumberCtl,
                decoration: const InputDecoration(labelText: 'Room Number'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter room number' : null,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookingsApprovalPage extends StatelessWidget {
  const BookingsApprovalPage({super.key});

  Future<void> _approve(String bookingId) async {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({'status': 'approved'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Approve Bookings')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AdminRepository.bookingsPendingStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty)
            return const Center(child: Text('No pending bookings'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data();
              return ListTile(
                title: Text('Booking for room ${d['roomId'] ?? '—'}'),
                subtitle: Text('Status: ${d['status'] ?? '—'}'),
                trailing: ElevatedButton(
                  onPressed: () => _approve(docs[i].id),
                  child: const Text('Approve'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});

  Future<void> _markPaid(String paymentId) async {
    await FirebaseFirestore.instance
        .collection('payments')
        .doc(paymentId)
        .update({'status': 'paid'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AdminRepository.paymentsPendingStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty)
            return const Center(child: Text('No pending payments'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final amount = (d['amount'] ?? 0).toString();
              return ListTile(
                title: Text('Payment: \$${amount}'),
                subtitle: Text('Status: ${d['status'] ?? '—'}'),
                trailing: ElevatedButton(
                  onPressed: () => _markPaid(docs[i].id),
                  child: const Text('Mark paid'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MaintenanceManagementPage extends StatelessWidget {
  const MaintenanceManagementPage({super.key});

  Future<void> _assign(String requestId) async {
    await FirebaseFirestore.instance
        .collection('maintenance_requests')
        .doc(requestId)
        .update({'status': 'assigned'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance Requests')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AdminRepository.maintenanceOpenStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty)
            return const Center(child: Text('No open maintenance requests'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data();
              return ListTile(
                title: Text('Room: ${d['roomID'] ?? '—'}'),
                subtitle: Text('Status: ${d['status'] ?? '—'}'),
                trailing: ElevatedButton(
                  onPressed: () => _assign(docs[i].id),
                  child: const Text('Assign'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
