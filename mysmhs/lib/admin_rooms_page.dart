// ignore_for_file: prefer_const_constructors, unused_local_variable, depend_on_referenced_packages, unused_element_parameter

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Admin Rooms Management Page
/// - Shows all rooms with admin actions: Edit, Delete, Quick Status
class AdminRoomsPage extends StatefulWidget {
  const AdminRoomsPage({super.key});

  @override
  State<AdminRoomsPage> createState() => _AdminRoomsPageState();
}

class _AdminRoomsPageState extends State<AdminRoomsPage> {
  final TextEditingController _searchCtl = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      colors: [Color(0xFF052A6E), Color(0xFF5BC0FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final roomsStream = FirebaseFirestore.instance
        .collection('rooms')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () {
            // Navigate back to the admin dashboard route (guarded via /admin)
            Navigator.pushReplacementNamed(context, '/admin');
          },
          tooltip: 'Back',
        ),
        title: const Text(
          'Manage Rooms',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            color: Colors.white,
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.filter_list),
            color: Colors.white,
            tooltip: 'Filter',
          ),
        ],
      ),

      /// Add Room button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushNamed('/add-room'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF052A6E),
        icon: const Icon(Icons.add),
        label: const Text('Add Room'),
      ),

      /// Body with gradient background and room list
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(gradient: gradient),
          child: RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: Colors.white.withOpacity(0.06),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 8.0,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.search, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchCtl,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Search by room number',
                                        hintStyle: TextStyle(
                                          color: Colors.white70,
                                        ),
                                        border: InputBorder.none,
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  DropdownButton<String>(
                                    value: _filter,
                                    dropdownColor: const Color(0xFF1E3A8A),
                                    underline: const SizedBox.shrink(),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'all',
                                        child: Text(
                                          'All',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'available',
                                        child: Text(
                                          'Available',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'occupied',
                                        child: Text(
                                          'Occupied',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'maintenance',
                                        child: Text(
                                          'Maintenance',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _filter = v ?? 'all'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: roomsStream,
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return _buildError(
                            'Failed to load rooms',
                            () => setState(() {}),
                          );
                        }
                        if (snap.connectionState == ConnectionState.waiting) {
                          return SizedBox(
                            height: 240,
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
                        var filtered = docs.where((d) {
                          final data = d.data();
                          final rn = (data['roomNumber']?.toString() ?? '')
                              .toLowerCase();

                          final searchText = _searchCtl.text
                              .trim()
                              .toLowerCase();
                          final matchesSearch =
                              searchText.isEmpty || rn.contains(searchText);

                          // Normalize availability/status to handle case variations and missing fields
                          final statusRaw =
                              (data['availability'] as String?) ??
                              (data['isOccupied'] == true
                                  ? 'occupied'
                                  : 'available');
                          final status = statusRaw
                              .toString()
                              .trim()
                              .toLowerCase();

                          final filter = _filter.trim().toLowerCase();
                          final matchesFilter =
                              filter == 'all' || status == filter;

                          return matchesSearch && matchesFilter;
                        }).toList();

                        final total = docs.length;
                        final available = docs
                            .where(
                              (d) =>
                                  ((d.data()['availability'] as String?) ??
                                      (d.data()['isOccupied'] == true
                                          ? 'occupied'
                                          : 'available')) ==
                                  'available',
                            )
                            .length;
                        final occupied = docs
                            .where(
                              (d) =>
                                  ((d.data()['availability'] as String?) ??
                                      (d.data()['isOccupied'] == true
                                          ? 'occupied'
                                          : 'available')) ==
                                  'occupied',
                            )
                            .length;
                        final maintenance = docs
                            .where(
                              (d) =>
                                  ((d.data()['availability'] as String?) ??
                                      (d.data()['isOccupied'] == true
                                          ? 'occupied'
                                          : 'available')) ==
                                  'maintenance',
                            )
                            .length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              color: Colors.white.withOpacity(0.06),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    Text(
                                      'Total: $total',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Available: $available',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Occupied: $occupied',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Maintenance: $maintenance',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            LayoutBuilder(
                              builder: (context, cstr) {
                                final w = cstr.maxWidth;
                                final cross = w >= 1200
                                    ? 4
                                    : (w >= 600 ? 2 : 1);

                                if (filtered.isEmpty) {
                                  return _buildEmpty(
                                    'No rooms match your filters',
                                  );
                                }

                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: cross,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: 0.8,
                                      ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, i) {
                                    final d = filtered[i];
                                    final data = d.data();
                                    final id = d.id;
                                    return _AdminRoomCard(
                                      roomId: id,
                                      roomNumber:
                                          data['roomNumber']?.toString() ?? '—',
                                      price:
                                          (data['price'] as num?)?.toDouble() ??
                                          0.0,
                                      images:
                                          (data['images'] as List?)
                                              ?.cast<String>() ??
                                          const [],
                                      availability:
                                          (data['availability'] as String?) ??
                                          (data['isOccupied'] == true
                                              ? 'occupied'
                                              : 'available'),
                                      description:
                                          (data['description'] as String?) ??
                                          '',
                                      onDelete: () => _deleteRoom(
                                        id,
                                        data['roomNumber']?.toString() ?? '—',
                                        (d.data()['images'] as List?)
                                                ?.cast<String>() ??
                                            const [],
                                      ),
                                      onEdit: () =>
                                          Navigator.of(context).pushNamed(
                                            '/add-room',
                                            arguments: {
                                              'room': {...data, 'roomID': id},
                                            },
                                          ),
                                      onStatusChanged: (s) =>
                                          _updateStatus(id, s),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
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

  /// Error widget
  Widget _buildError(String message, VoidCallback onRetry) => Card(
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

  /// Empty state widget
  Widget _buildEmpty(String message) => Card(
    color: Colors.white.withOpacity(0.06),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(18.0),
      child: Column(
        children: [
          Text(message, style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed('/add-room'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF052A6E),
            ),
            child: const Text('Add First Room'),
          ),
        ],
      ),
    ),
  );

  /// Update room status helper
  Future<void> _updateStatus(String id, String status) async {
    try {
      await FirebaseFirestore.instance.collection('rooms').doc(id).update({
        'availability': status,
        'isOccupied': status == 'occupied',
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Status updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  /// Delete room helper
  Future<void> _deleteRoom(
    String id,
    String roomNumber,
    List<String> images,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete room'),
        content: Text(
          'Are you sure you want to delete Room $roomNumber? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Delete storage images
      for (final url in images) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(url);
          await ref.delete();
        } catch (_) {}
      }

      await FirebaseFirestore.instance.collection('rooms').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Room deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete room: $e')));
      }
    }
  }
}

class _AdminRoomCard extends StatefulWidget {
  const _AdminRoomCard({
    required this.roomId,
    required this.roomNumber,
    required this.price,
    required this.images,
    required this.availability,
    required this.description,
    this.onDelete,
    this.onEdit,
    this.onStatusChanged,
    super.key,
  });

  final String roomId;
  final String roomNumber;
  final double price;
  final List<String> images;
  final String availability;
  final String description;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final ValueChanged<String>? onStatusChanged;

  @override
  State<_AdminRoomCard> createState() => __AdminRoomCardState();
}

class __AdminRoomCardState extends State<_AdminRoomCard> {
  late final PageController _pc;
  int _page = 0;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _pc = PageController();
  }

  /// Next image
  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  /// Previous image
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

  /// Next image
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
    Color badgeColor;
    switch (widget.availability.toLowerCase()) {
      case 'available':
        badgeColor = Colors.green.shade400;
        break;
      case 'occupied':
        badgeColor = Colors.red.shade400;
        break;
      default:
        badgeColor = Colors.amber.shade600;
    }

    return Semantics(
      container: true,
      label:
          'Room ${widget.roomNumber}, Price KES ${widget.price.round()}, Status ${widget.availability}',
      child: Card(
        color: Colors.white.withOpacity(0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 140,
              width: double.infinity,
              child: MouseRegion(
                onEnter: (_) => setState(() => _hover = true),
                onExit: (_) => setState(() => _hover = false),
                child: Stack(
                  children: [
                    // PageView for images
                    PageView.builder(
                      controller: _pc,
                      itemCount: widget.images.isNotEmpty
                          ? widget.images.length
                          : 1,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (context, index) {
                        if (widget.images.isEmpty) {
                          return Container(
                            color: Colors.white10,
                            child: Center(
                              child: Icon(
                                Icons.bed,
                                size: 42,
                                color: Colors.white,
                              ),
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
                          errorWidget: (context, url, err) {
                            if (kIsWeb) {
                              print(
                                '❌ [Admin Rooms Card] Failed to load image: $url',
                              );
                              print('   Error: $err');
                            }
                            return Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.white,
                              ),
                            );
                          },
                        );
                      },
                    ),

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
                            children: List.generate(widget.images.length, (i) {
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
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Room ${widget.roomNumber}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onEdit,
                        icon: Icon(Icons.edit, color: Colors.white),
                        tooltip: 'Edit room',
                      ),
                      IconButton(
                        onPressed: widget.onDelete,
                        icon: Icon(Icons.delete, color: Colors.redAccent),
                        tooltip: 'Delete room',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'KES ${_formatCurrency(widget.price)}/month',
                    style: TextStyle(color: Colors.white.withOpacity(0.92)),
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
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.availability[0].toUpperCase() +
                              widget.availability.substring(1),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.description.length > 50
                              ? '${widget.description.substring(0, 50)}...'
                              : widget.description,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      DropdownButton<String>(
                        value: widget.availability,
                        dropdownColor: const Color(0xFF1E3A8A),
                        items: const [
                          DropdownMenuItem(
                            value: 'available',
                            child: Text(
                              'Available',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'occupied',
                            child: Text(
                              'Occupied',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'maintenance',
                            child: Text(
                              'Maintenance',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) widget.onStatusChanged?.call(v);
                        },
                        iconEnabledColor: Colors.white,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) =>
                              _RoomDetailsDialog(roomId: widget.roomId),
                        ),
                        child: const Text(
                          'View Details',
                          style: TextStyle(color: Colors.white),
                        ),
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

class _RoomDetailsDialog extends StatelessWidget {
  const _RoomDetailsDialog({required this.roomId});
  final String roomId;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E3A8A), // Solid background
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF052A6E), Color(0xFF5BC0FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('rooms')
              .doc(roomId)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    'Error loading room',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              );
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 120,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              );
            }

            final data = snap.data?.data() ?? {};
            final images =
                (data['images'] as List?)?.cast<String>() ?? const [];

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Room Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Image
                  if (images.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: images.first,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: Colors.white10,
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) {
                          if (kIsWeb) {
                            print(
                              '❌ [Admin Rooms Modal] Failed to load image: $url',
                            );
                            print('   Error: $error');
                          }
                          return Container(
                            height: 200,
                            color: Colors.white10,
                            child: Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 48,
                                color: Colors.white70,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(Icons.bed, size: 64, color: Colors.white),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Room details
                  Text(
                    'Room ${data['roomNumber'] ?? '—'}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'KES ${(data['price'] as num?)?.toString() ?? '-'} / month',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withOpacity(0.92),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['description'] ?? 'No description provided',
                    style: TextStyle(color: Colors.white.withOpacity(0.85)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Status',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        data['availability'] as String? ?? 'available',
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (data['availability'] as String? ?? 'available')
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pushNamed(
                              '/add-room',
                              arguments: {
                                'room': {...data, 'roomID': roomId},
                              },
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF052A6E),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                          ),
                          icon: const Icon(Icons.close),
                          label: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
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
