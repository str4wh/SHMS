// ignore_for_file: depend_on_referenced_packages, curly_braces_in_flow_control_structures

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RoomDetailsPage extends StatelessWidget {
  const RoomDetailsPage({super.key, this.roomId});
  final String? roomId;

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final id = roomId ?? args?['roomId'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Room Details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
      ),
      body: id == null
          ? const Center(
              child: Text(
                'No room selected',
                style: TextStyle(color: Colors.white),
              ),
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(id)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError)
                  return Center(
                    child: Text(
                      'Error loading room',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                if (snap.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                final data = snap.data?.data() ?? {};
                final images = (data['images'] as List?)?.cast<String>() ?? [];

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (images.isNotEmpty)
                        SizedBox(
                          height: 220,
                          child: CachedNetworkImage(
                            imageUrl: images.first,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      else
                        SizedBox(
                          height: 220,
                          child: Center(
                            child: Icon(
                              Icons.bed,
                              size: 64,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'Room ${data['roomNumber'] ?? '—'}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'KES ${(data['price'] as num?)?.toString() ?? '-'} / month',
                        style: TextStyle(color: Colors.white.withOpacity(0.92)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Description',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data['description'] ?? 'No details',
                        style: TextStyle(color: Colors.white.withOpacity(0.8)),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
