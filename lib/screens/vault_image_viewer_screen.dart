import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../models/vault_item.dart';
import '../services/vault_service.dart';

const _kCard = Color(0xFF1E1B2E);
const _kTextHead = Color(0xFFF3F4F6);
const _kTextBody = Color(0xFF9CA3AF);
const _kRedTag = Color(0xFFEF4444);
const _kVaultPurple = Color(0xFF8B5CF6);

class VaultImageViewerScreen extends StatefulWidget {
  final VaultItem item;
  const VaultImageViewerScreen({super.key, required this.item});

  @override
  State<VaultImageViewerScreen> createState() => _VaultImageViewerScreenState();
}

class _VaultImageViewerScreenState extends State<VaultImageViewerScreen>
    with SingleTickerProviderStateMixin {
  late VaultItem _item;
  Uint8List? _decryptedBytes;
  bool _isLoading = true;
  String? _error;
  String? _tempFilePath;

  // Image manipulation state
  final TransformationController _transCtrl = TransformationController();
  late AnimationController _animCtrl;
  Animation<Matrix4>? _zoomAnim;

  int _rotationQuarterTurns = 0; // 0, 1, 2, 3 (each is 90 deg)
  bool _showOverlays = true;
  ui.Image? _decodedImageInfo;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _loadDecryptedImage();
  }

  @override
  void dispose() {
    _transCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDecryptedImage() async {
    try {
      final bytes = await VaultService.instance.getDecryptedBytes(_item);
      if (!mounted) return;

      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _error = 'Unable to decrypt image. Corrupted or missing file.';
          _isLoading = false;
        });
        return;
      }

      _decryptedBytes = bytes;

      // Extract image dimensions
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        _decodedImageInfo = frame.image;
      } catch (_) {}

      // Prepare temp file for external viewing
      try {
        _tempFilePath =
            await VaultService.instance.prepareTempFileForOpening(_item);
      } catch (_) {}

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Decryption error: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _toggleDoubleTapZoom(TapDownDetails details) {
    final currentScale = _transCtrl.value.getMaxScaleOnAxis();
    final Matrix4 endMatrix;

    if (currentScale > 1.2) {
      // Reset to 1.0x
      endMatrix = Matrix4.identity();
    } else {
      // Zoom to 2.5x centered at tap
      final pos = details.localPosition;
      endMatrix = Matrix4.identity()
        // ignore: deprecated_member_use
        ..translate(-pos.dx * 1.5, -pos.dy * 1.5)
        // ignore: deprecated_member_use
        ..scale(2.5);
    }

    _zoomAnim = Matrix4Tween(begin: _transCtrl.value, end: endMatrix).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    )..addListener(() {
        _transCtrl.value = _zoomAnim!.value;
      });

    _animCtrl.forward(from: 0);
  }

  void _zoomIn() {
    final current = _transCtrl.value.getMaxScaleOnAxis();
    if (current < 4.5) {
      final newScale = (current + 0.5).clamp(0.5, 5.0);
      _setZoomScale(newScale);
    }
  }

  void _zoomOut() {
    final current = _transCtrl.value.getMaxScaleOnAxis();
    if (current > 0.6) {
      final newScale = (current - 0.5).clamp(0.5, 5.0);
      _setZoomScale(newScale);
    }
  }

  void _resetZoom() {
    _setZoomScale(1.0);
  }

  void _setZoomScale(double targetScale) {
    final center = MediaQuery.of(context).size / 2;
    final currentScale = _transCtrl.value.getMaxScaleOnAxis();
    final factor = targetScale / currentScale;

    final endMatrix = _transCtrl.value.clone()
      // ignore: deprecated_member_use
      ..translate(center.width * (1 - factor), center.height * (1 - factor))
      // ignore: deprecated_member_use
      ..scale(factor);

    _zoomAnim = Matrix4Tween(
      begin: _transCtrl.value,
      end: targetScale == 1.0 ? Matrix4.identity() : endMatrix,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic))
      ..addListener(() {
        _transCtrl.value = _zoomAnim!.value;
      });
    _animCtrl.forward(from: 0);
  }

  void _rotateClockwise() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _openInExternalApp() {
    if (_tempFilePath != null && File(_tempFilePath!).existsSync()) {
      OpenFilex.open(_tempFilePath!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing image for external app...')),
      );
      VaultService.instance.prepareTempFileForOpening(_item).then((path) {
        if (path != null) OpenFilex.open(path);
      });
    }
  }

  void _showInfoSheet() {
    final width = _decodedImageInfo?.width;
    final height = _decodedImageInfo?.height;
    final dateStr =
        '${_item.importDate.year}-${_item.importDate.month.toString().padLeft(2, '0')}-${_item.importDate.day.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.photo_outlined, color: _kVaultPurple, size: 22),
                SizedBox(width: 10),
                Text(
                  'Encrypted Image Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _kTextHead,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow('Name', _item.name),
            _buildInfoRow('Original File', _item.originalFileName),
            if (width != null && height != null)
              _buildInfoRow('Dimensions', '$width × $height px'),
            _buildInfoRow('File Size', _item.formattedSize),
            _buildInfoRow('Imported', dateStr),
            _buildInfoRow('Encryption', 'AES-256 (CBC) + PBKDF2 Key'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open in Device Photos App'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kVaultPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openInExternalApp();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: _kTextBody)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kTextHead,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete from Vault?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kTextHead),
        ),
        content: Text(
          'Permanently delete "${_item.name}" from your encrypted vault?',
          style: const TextStyle(fontSize: 14, color: _kTextBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _kTextBody)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRedTag,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await VaultService.instance.deleteItem(_item.id);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${_item.name}"')),
        );
      }
    }
  }

  Future<void> _showRenameDialog() async {
    final controller = TextEditingController(text: _item.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Rename Image',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kTextHead),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Display Name',
            labelStyle: const TextStyle(color: _kTextBody),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kVaultPurple, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _kTextBody)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kVaultPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty && mounted) {
      final newName = controller.text.trim();
      await VaultService.instance.renameItem(_item.id, newName);
      setState(() {
        _item = _item.copyWith(name: newName);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      extendBodyBehindAppBar: true,
      appBar: _showOverlays
          ? AppBar(
              backgroundColor: const Color(0xFF0A0A0F).withValues(alpha: 0.85),
              foregroundColor: Colors.white,
              elevation: 0,
              title: Text(
                _item.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: _item.isFavorite ? 'Remove Favorite' : 'Mark Favorite',
                  icon: Icon(
                    _item.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: _item.isFavorite ? Colors.amber : Colors.white,
                  ),
                  onPressed: () async {
                    await VaultService.instance.toggleFavorite(_item.id);
                    setState(() {
                      _item = _item.copyWith(isFavorite: !_item.isFavorite);
                    });
                  },
                ),
                IconButton(
                  tooltip: 'Image Details',
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: _showInfoSheet,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  color: _kCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (val) {
                    switch (val) {
                      case 'open_external':
                        _openInExternalApp();
                        break;
                      case 'rotate':
                        _rotateClockwise();
                        break;
                      case 'rename':
                        _showRenameDialog();
                        break;
                      case 'delete':
                        _confirmDelete();
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'open_external',
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 18, color: Colors.white),
                          SizedBox(width: 10),
                          Text('Open in Photos App', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rotate',
                      child: Row(
                        children: [
                          Icon(Icons.rotate_right_rounded, size: 18, color: Colors.white),
                          SizedBox(width: 10),
                          Text('Rotate 90°', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                          SizedBox(width: 10),
                          Text('Rename', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: _kRedTag),
                          SizedBox(width: 10),
                          Text('Delete', style: TextStyle(color: _kRedTag)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          // Main Image Canvas with gesture controls
          GestureDetector(
            onTap: () {
              setState(() => _showOverlays = !_showOverlays);
            },
            onDoubleTapDown: _toggleDoubleTapZoom,
            child: Center(
              child: _isLoading
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: _kVaultPurple),
                        SizedBox(height: 16),
                        Text(
                          'Decrypting image with AES-256...',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    )
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: _kRedTag.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.broken_image_rounded,
                                    size: 38, color: _kRedTag),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                label: const Text('Try Device Gallery App'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kVaultPurple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _openInExternalApp,
                              ),
                            ],
                          ),
                        )
                      : InteractiveViewer(
                          transformationController: _transCtrl,
                          minScale: 0.5,
                          maxScale: 5.0,
                          clipBehavior: Clip.none,
                          child: RotatedBox(
                            quarterTurns: _rotationQuarterTurns,
                            child: Image.memory(
                              _decryptedBytes!,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, stack) => Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.broken_image_rounded,
                                      size: 54, color: _kRedTag),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Cannot render this image format directly.',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: _openInExternalApp,
                                    child: const Text('Open in External Viewer'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
            ),
          ),

          // Bottom Floating Controls Toolbar
          if (_showOverlays && !_isLoading && _error == null)
            Positioned(
              left: 24,
              right: 24,
              bottom: 30,
              child: SafeArea(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161424).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildToolBtn(
                          icon: Icons.zoom_out_rounded,
                          tooltip: 'Zoom Out',
                          onTap: _zoomOut,
                        ),
                        _buildToolBtn(
                          icon: Icons.center_focus_strong_rounded,
                          tooltip: 'Reset Zoom (1:1)',
                          onTap: _resetZoom,
                        ),
                        _buildToolBtn(
                          icon: Icons.zoom_in_rounded,
                          tooltip: 'Zoom In',
                          onTap: _zoomIn,
                        ),
                        Container(
                          height: 22,
                          width: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          color: Colors.white24,
                        ),
                        _buildToolBtn(
                          icon: Icons.rotate_right_rounded,
                          tooltip: 'Rotate 90°',
                          onTap: _rotateClockwise,
                        ),
                        _buildToolBtn(
                          icon: Icons.open_in_new_rounded,
                          tooltip: 'Open in Photos App',
                          onTap: _openInExternalApp,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}
