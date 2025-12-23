// ignore_for_file: unused_import, unused_local_variable

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';

import 'services/room_sync_service.dart';

/// AddEditRoomPage
/// - Uses Hive via RoomSyncService for offline persistence and syncing
/// - Keeps UI & styling consistent with landing/auth pages
class AddEditRoomPage extends StatefulWidget {
  const AddEditRoomPage({super.key});

  @override
  State<AddEditRoomPage> createState() => _AddEditRoomPageState();
}

class _AddEditRoomPageState extends State<AddEditRoomPage> {
  final _formKey = GlobalKey<FormState>();
  final _roomNumberCtl = TextEditingController();
  final _priceCtl = TextEditingController();
  final _descriptionCtl = TextEditingController();
  String _availability = 'available';

  // Local copies of image file paths (mobile) and in-memory bytes (web)
  final List<String> _localImagePaths = [];
  final List<Uint8List> _webImageBytes = [];
  bool _loading = false;
  bool _isEdit = false;
  String? _roomId; // for edit mode

  final ImagePicker _picker = ImagePicker();

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _online = true;

  @override
  void initState() {
    super.initState();

    // Initialize sync service
    RoomSyncService.instance.init();

    // detect connectivity
    Connectivity().checkConnectivity().then((results) {
      final first = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      setState(() => _online = first != ConnectivityResult.none);
    });
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final first = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      final nowOnline = first != ConnectivityResult.none;
      if (nowOnline && !_online) {
        // regained connectivity: attempt sync
        RoomSyncService.instance.syncPendingRooms();
      }
      setState(() => _online = nowOnline);
    });

    // Check for edit data in route args
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['room'] != null) {
        _loadRoomForEdit(args['room'] as Map<String, dynamic>);
      }
    });
  }

  @override
  void dispose() {
    _roomNumberCtl.dispose();
    _priceCtl.dispose();
    _descriptionCtl.dispose();
    _connSub?.cancel();
    super.dispose();
  }

  void _loadRoomForEdit(Map<String, dynamic> room) {
    setState(() {
      _isEdit = true;
      _roomId = room['roomID'] as String? ?? room['id'] as String?;
      _roomNumberCtl.text = room['roomNumber']?.toString() ?? '';
      _priceCtl.text = (room['price'] ?? '').toString();
      _descriptionCtl.text = room['description'] ?? '';
      _availability = room['availability'] ?? 'available';
      final images = (room['images'] as List?)?.cast<String>() ?? [];
      // Note: we do not auto-download remote images — only local picks show in preview
      // The images array will be shown via remote fetch in list pages
    });
  }

  Future<void> _pickImage() async {
    final total = _localImagePaths.length + _webImageBytes.length;
    if (total >= 3) return;
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _webImageBytes.add(bytes);
      });
      return;
    }

    // Mobile: Copy file to app documents for safe persistence
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = p.basename(picked.path);
    final dest = File(
      '${appDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName',
    );
    await File(picked.path).copy(dest.path);

    setState(() {
      _localImagePaths.add(dest.path);
    });
  }

  void _removeImageAt(int index) {
    setState(() {
      final localCount = _localImagePaths.length;
      if (index < localCount) {
        final path = _localImagePaths.removeAt(index);
        try {
          File(path).deleteSync();
        } catch (_) {}
      } else {
        final webIndex = index - localCount;
        if (webIndex >= 0 && webIndex < _webImageBytes.length) {
          _webImageBytes.removeAt(webIndex);
        }
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final room = {
      'roomID': _roomId ?? '',
      'roomNumber': _roomNumberCtl.text.trim(),
      'price': double.tryParse(_priceCtl.text.trim()) ?? 0.0,
      'isOccupied': _availability == 'occupied',
      'description': _descriptionCtl.text.trim(),
      'availability': _availability,
    };

    final combinedImages = <dynamic>[];
    combinedImages.addAll(_localImagePaths);
    combinedImages.addAll(_webImageBytes);

    try {
      final online = _online;
      if (online) {
        // Try online submit
        final success = await RoomSyncService.instance.addOrUpdateRoomOnline(
          room,
          combinedImages,
        );
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_isEdit ? 'Room updated' : 'Room added')),
          );
          Navigator.of(context).pop(true);
          return;
        }
      }

      // If we reached here, save locally for sync later
      await RoomSyncService.instance.savePendingRoom(room, combinedImages);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved locally - will sync when online')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildImagePicker(BuildContext context, double width) {
    final isWide = width > 720;
    final cross = isWide ? 3 : (width > 420 ? 2 : 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Images',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount:
              (_localImagePaths.length + _webImageBytes.length) +
              ((_localImagePaths.length + _webImageBytes.length) < 3 ? 1 : 0),
          itemBuilder: (context, i) {
            final totalLocal = _localImagePaths.length;
            final totalWeb = _webImageBytes.length;
            final total = totalLocal + totalWeb;

            if (i < totalLocal) {
              final pth = _localImagePaths[i];
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: FileImage(File(pth)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: InkWell(
                      onTap: () => _removeImageAt(i),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black54,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(6.0),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            if (i < total) {
              // web image
              final webIndex = i - totalLocal;
              final bytes = _webImageBytes[webIndex];
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: MemoryImage(bytes),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: InkWell(
                      onTap: () => _removeImageAt(i),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black54,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(6.0),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return InkWell(
              onTap: _pickImage,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add_a_photo, color: Colors.white),
                      SizedBox(height: 6),
                      Text('Add', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
    filled: true,
    fillColor: Colors.white.withOpacity(0.06),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width.clamp(0.0, 1200.0);
    final maxWidth = media.size.width > 1200 ? 1200.0 : media.size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Room' : 'Add Room',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder<int>(
            stream: RoomSyncService.instance.pendingCountStream,
            builder: (context, snap) {
              final pending = snap.data ?? 0;
              final color = pending == 0 ? Colors.white : Colors.amber;
              return IconButton(
                onPressed: () {},
                icon: Icon(Icons.cloud, color: color),
                tooltip: pending == 0 ? 'All synced' : '$pending pending',
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF052A6E), Color(0xFF5BC0FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: Colors.white.withOpacity(0.06),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Form(
                          key: _formKey,
                          child: LayoutBuilder(
                            builder: (context, cstr) {
                              final isWide = cstr.maxWidth > 720;
                              return Column(
                                children: [
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      SizedBox(
                                        width: isWide
                                            ? (cstr.maxWidth / 2) - 12
                                            : double.infinity,
                                        child: TextFormField(
                                          controller: _roomNumberCtl,
                                          decoration: _inputDecoration(
                                            'Room Number',
                                          ),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.92,
                                            ),
                                          ),
                                          validator: (v) =>
                                              v == null || v.trim().isEmpty
                                              ? 'Enter room number'
                                              : null,
                                        ),
                                      ),
                                      SizedBox(
                                        width: isWide
                                            ? (cstr.maxWidth / 2) - 12
                                            : double.infinity,
                                        child: TextFormField(
                                          controller: _priceCtl,
                                          decoration: _inputDecoration('Price'),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.92,
                                            ),
                                          ),
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty)
                                              return 'Enter price';
                                            final parsed = double.tryParse(
                                              v.trim(),
                                            );
                                            if (parsed == null || parsed <= 0)
                                              return 'Enter valid positive number';
                                            return null;
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        width: isWide
                                            ? (cstr.maxWidth / 2) - 12
                                            : double.infinity,
                                        child: DropdownButtonFormField<String>(
                                          value: _availability,
                                          decoration: _inputDecoration(
                                            'Availability',
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'available',
                                              child: Text('Available'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'occupied',
                                              child: Text('Occupied'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'maintenance',
                                              child: Text('Maintenance'),
                                            ),
                                          ],
                                          onChanged: (v) => setState(
                                            () => _availability =
                                                v ?? 'available',
                                          ),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.92,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: isWide
                                            ? (cstr.maxWidth / 2) - 12
                                            : double.infinity,
                                        child: TextFormField(
                                          controller: _descriptionCtl,
                                          decoration: _inputDecoration(
                                            'Description (optional)',
                                          ),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.92,
                                            ),
                                          ),
                                          minLines: 3,
                                          maxLines: 5,
                                          maxLength: 500,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  _buildImagePicker(context, cstr.maxWidth),

                                  const SizedBox(height: 16),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: _loading
                                            ? null
                                            : () async {
                                                if (RoomSyncService.instance
                                                    .pendingEntries()
                                                    .isNotEmpty) {
                                                  final leave = await showDialog<bool>(
                                                    context: context,
                                                    builder: (_) => AlertDialog(
                                                      title: const Text(
                                                        'Unsynced changes',
                                                      ),
                                                      content: const Text(
                                                        'There are pending changes that have not been synced. Are you sure you want to leave?',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                context,
                                                              ).pop(false),
                                                          child: const Text(
                                                            'Cancel',
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                context,
                                                              ).pop(true),
                                                          child: const Text(
                                                            'Leave',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (leave != true) return;
                                                }
                                                Navigator.of(context).pop();
                                              },
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: const Color(
                                            0xFF052A6E,
                                          ),
                                        ),
                                        onPressed: _loading ? null : _submit,
                                        child: _loading
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(),
                                              )
                                            : Text(
                                                _isEdit
                                                    ? 'Update Room'
                                                    : 'Add Room',
                                              ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
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
