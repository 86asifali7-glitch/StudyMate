import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/vault_item.dart';
import '../services/vault_service.dart';
import 'vault_audio_player_screen.dart';
import 'vault_image_viewer_screen.dart';
import 'vault_lock_screen.dart';
import 'vault_note_editor_screen.dart';
import 'vault_video_player_screen.dart';
import 'vault_pdf_viewer_screen.dart';

// ─── Design tokens matching StudyMate ─────────────────────────────────────────
const _kBg = Color(0xFFEEF0FF);
const _kVaultPurple = Color(0xFF7C3AED);
const _kCard = Color(0xFFFFFFFF);
const _kTextHead = Color(0xFF1A1A2E);
const _kTextBody = Color(0xFF6B7280);
const _kGreenTag = Color(0xFF059669);
const _kRedTag = Color(0xFFEF4444);
const _kSkyTag = Color(0xFF0284C7);
const _kAmberTag = Color(0xFFF59E0B);

class VaultHomeScreen extends StatefulWidget {
  const VaultHomeScreen({super.key});

  @override
  State<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

class _VaultHomeScreenState extends State<VaultHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isImporting = false;
  bool _filterFavoritesOnly = false;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _lockVault() {
    VaultService.instance.lock();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const VaultLockScreen()),
    );
  }

  String get _fabLabel {
    switch (_tabController.index) {
      case 0:
        return 'Add Image';
      case 1:
        return 'Add Video';
      case 2:
        return 'Add Music';
      case 3:
        return 'Add PDF / Note';
      default:
        return 'Add to Vault';
    }
  }

  IconData get _fabIcon {
    switch (_tabController.index) {
      case 0:
        return Icons.add_photo_alternate_rounded;
      case 1:
        return Icons.video_call_rounded;
      case 2:
        return Icons.music_note_rounded;
      case 3:
        return Icons.note_add_rounded;
      default:
        return Icons.add_rounded;
    }
  }

  void _onFabPressed() {
    switch (_tabController.index) {
      case 0:
        _importImage();
        break;
      case 1:
        _importVideo();
        break;
      case 2:
        _importAudio();
        break;
      case 3:
        _showPdfNotesChoiceModal();
        break;
      default:
        _showAddModal();
        break;
    }
  }

  void _showPdfNotesChoiceModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Add PDF or Secret Note',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kTextHead,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose what to encrypt in your PDF & Notes album:',
              style: TextStyle(fontSize: 13, color: _kTextBody),
            ),
            const SizedBox(height: 20),
            _buildModalItem(
              icon: Icons.picture_as_pdf_rounded,
              iconColor: _kRedTag,
              title: 'Import PDF Document',
              subtitle: 'Select and encrypt PDF files from your device',
              onTap: () {
                Navigator.pop(ctx);
                _importPdf();
              },
            ),
            _buildModalItem(
              icon: Icons.edit_note_rounded,
              iconColor: _kGreenTag,
              title: 'Write Secret Note',
              subtitle: 'Type a secure private text note right in the vault',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VaultNoteEditorScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<VaultItem> _getFilteredItems(VaultCategory category) {
    var list = VaultService.instance.getItemsByCategory(category);
    if (_filterFavoritesOnly) {
      list = list.where((e) => e.isFavorite).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((e) {
        final matchName = e.name.toLowerCase().contains(_searchQuery);
        final matchFile = e.originalFileName.toLowerCase().contains(_searchQuery);
        final matchSnippet = e.noteSnippet?.toLowerCase().contains(_searchQuery) ?? false;
        return matchName || matchFile || matchSnippet;
      }).toList();
    }
    return list;
  }

  Future<void> _importImage() async {
    try {
      Uint8List? bytes;
      String? fileName;

      try {
        final XFile? picked = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 95,
        );
        if (picked != null) {
          bytes = await picked.readAsBytes();
          fileName = picked.name;
        }
      } catch (e) {
        debugPrint('ImagePicker failed, trying FilePicker fallback: $e');
      }

      if (bytes == null || bytes.isEmpty) {
        final files = await FilePickerPlatform.instance.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'],
        );
        if (files.isNotEmpty) {
          final file = files.first;
          fileName = file.name;
          try {
            bytes = await file.readAsBytes();
          } catch (_) {}
          if ((bytes == null || bytes.isEmpty) && !kIsWeb && file.path != null) {
            try {
              bytes = await File(file.path!).readAsBytes();
            } catch (_) {}
          }
        }
      }

      if (bytes == null || bytes.isEmpty || fileName == null) return;

      setState(() => _isImporting = true);
      await VaultService.instance.importFile(
        fileName: fileName,
        bytes: bytes,
        category: VaultCategory.image,
      );

      if (mounted) {
        _tabController.animateTo(0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image encrypted & saved to vault!'),
            backgroundColor: _kVaultPurple,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _importVideo() async {
    try {
      final files = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mkv', 'mov', 'webm', '3gp', 'avi'],
      );
      if (files.isEmpty) return;

      final file = files.first;
      setState(() => _isImporting = true);

      Uint8List? bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (_) {}

      if ((bytes == null || bytes.isEmpty) && !kIsWeb && file.path != null) {
        try {
          bytes = await File(file.path!).readAsBytes();
        } catch (_) {}
      }

      if (bytes != null && bytes.isNotEmpty) {
        await VaultService.instance.importFile(
          fileName: file.name,
          bytes: bytes,
          category: VaultCategory.video,
        );
        if (mounted) {
          _tabController.animateTo(1);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video encrypted & saved to vault!'),
              backgroundColor: _kVaultPurple,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import video: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _importAudio() async {
    try {
      final files = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
      );
      if (files.isEmpty) return;

      final file = files.first;
      setState(() => _isImporting = true);

      Uint8List? bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (_) {}

      if ((bytes == null || bytes.isEmpty) && !kIsWeb && file.path != null) {
        try {
          bytes = await File(file.path!).readAsBytes();
        } catch (_) {}
      }

      if (bytes != null && bytes.isNotEmpty) {
        await VaultService.instance.importFile(
          fileName: file.name,
          bytes: bytes,
          category: VaultCategory.audio,
        );
        if (mounted) {
          _tabController.animateTo(2);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Audio track encrypted & saved to vault!'),
              backgroundColor: _kVaultPurple,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import audio: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _importPdf() async {
    try {
      final files = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (files.isEmpty) return;

      final file = files.first;
      setState(() => _isImporting = true);

      Uint8List? bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (_) {}

      if ((bytes == null || bytes.isEmpty) && !kIsWeb && file.path != null) {
        try {
          bytes = await File(file.path!).readAsBytes();
        } catch (_) {}
      }

      if (bytes != null && bytes.isNotEmpty) {
        await VaultService.instance.importFile(
          fileName: file.name,
          bytes: bytes,
          category: VaultCategory.pdfNotes,
        );
        if (mounted) {
          _tabController.animateTo(3);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF encrypted & saved to vault!'),
              backgroundColor: _kVaultPurple,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showAddModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Add to Encrypted Vault',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kTextHead,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select what kind of confidential study material to encrypt:',
              style: TextStyle(fontSize: 13, color: _kTextBody),
            ),
            const SizedBox(height: 20),
            _buildModalItem(
              icon: Icons.photo_library_rounded,
              iconColor: _kVaultPurple,
              title: 'Photos & Images',
              subtitle: 'Encrypt personal photos, screenshots, or scans',
              onTap: () {
                Navigator.pop(ctx);
                _importImage();
              },
            ),
            _buildModalItem(
              icon: Icons.video_library_rounded,
              iconColor: _kSkyTag,
              title: 'Private Video',
              subtitle: 'Import MP4, MKV, or MOV video files',
              onTap: () {
                Navigator.pop(ctx);
                _importVideo();
              },
            ),
            _buildModalItem(
              icon: Icons.music_note_rounded,
              iconColor: _kAmberTag,
              title: 'Music & Audio',
              subtitle: 'Save lecture voice notes, MP3 songs, or audio clips',
              onTap: () {
                Navigator.pop(ctx);
                _importAudio();
              },
            ),
            _buildModalItem(
              icon: Icons.picture_as_pdf_rounded,
              iconColor: _kRedTag,
              title: 'Confidential PDF',
              subtitle: 'Encrypt sensitive PDF assignments, exams, or books',
              onTap: () {
                Navigator.pop(ctx);
                _importPdf();
              },
            ),
            _buildModalItem(
              icon: Icons.edit_note_rounded,
              iconColor: _kGreenTag,
              title: 'Write Secret Note',
              subtitle: 'Type a secure private text note right in the vault',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VaultNoteEditorScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kTextHead),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: _kTextBody),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _kTextBody),
    );
  }

  Future<void> _openItem(VaultItem item) async {
    switch (item.category) {
      case VaultCategory.image:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VaultImageViewerScreen(item: item)),
        );
        break;
      case VaultCategory.audio:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VaultAudioPlayerScreen(item: item)),
        );
        break;
      case VaultCategory.video:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VaultVideoPlayerScreen(item: item)),
        );
        break;
      case VaultCategory.pdfNotes:
        if (item.isNote) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VaultNoteEditorScreen(existingItem: item)),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VaultPdfViewerScreen(item: item)),
          );
        }
        break;
    }
  }

  Future<void> _showRenameDialog(VaultItem item) async {
    final controller = TextEditingController(text: item.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename Item', style: TextStyle(fontWeight: FontWeight.w700, color: _kTextHead)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Display Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await VaultService.instance.renameItem(item.id, controller.text.trim());
    }
  }

  Future<void> _confirmDelete(VaultItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete from Vault?', style: TextStyle(fontWeight: FontWeight.w700, color: _kTextHead)),
        content: Text('Are you sure you want to permanently delete "${item.name}" from your encrypted vault?'),
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

    if (confirmed == true) {
      await VaultService.instance.deleteItem(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VaultService.instance,
      builder: (context, _) {
        final totalItems = VaultService.instance.items.length;
        final favCount = VaultService.instance.items.where((e) => e.isFavorite).length;

        return Scaffold(
          backgroundColor: _kBg,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: _buildSearchBar(),
                ),
                // Filter Tabs (All / Favorites)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'All Items ($totalItems)',
                        isSelected: !_filterFavoritesOnly,
                        onTap: () {
                          if (_filterFavoritesOnly) {
                            setState(() => _filterFavoritesOnly = false);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Favorites ($favCount)',
                        icon: Icons.star_rounded,
                        isSelected: _filterFavoritesOnly,
                        onTap: () {
                          if (!_filterFavoritesOnly) {
                            setState(() => _filterFavoritesOnly = true);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                // Category Album TabBar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: _kVaultPurple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: _kTextBody,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    tabs: const [
                      Tab(text: 'Images'),
                      Tab(text: 'Videos'),
                      Tab(text: 'Audio'),
                      Tab(text: 'PDFs & Notes'),
                    ],
                  ),
                ),
                // Import Progress banner if importing
                if (_isImporting)
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kVaultPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _kVaultPurple),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Encrypting and locking file in vault...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kVaultPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCategoryList(VaultCategory.image),
                      _buildCategoryList(VaultCategory.video),
                      _buildCategoryList(VaultCategory.audio),
                      _buildCategoryList(VaultCategory.pdfNotes),
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: _kVaultPurple,
            foregroundColor: Colors.white,
            elevation: 4,
            icon: Icon(_fabIcon),
            label: Text(_fabLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
            onPressed: _onFabPressed,
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: _kTextHead, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Personal Vault',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _kTextHead,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kGreenTag.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 11, color: _kGreenTag),
                          SizedBox(width: 4),
                          Text(
                            'AES-256',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _kGreenTag,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Encrypted private study documents & media',
                  style: TextStyle(fontSize: 12, color: _kTextBody),
                ),
              ],
            ),
          ),
          // Lock Button
          IconButton(
            tooltip: 'Lock Vault',
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kVaultPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_rounded, color: _kVaultPurple, size: 18),
            ),
            onPressed: _lockVault,
          ),
          // Settings Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: _kTextBody),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              if (val == 'change_pin') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VaultLockScreen(isChangingPin: true)),
                );
              } else if (val == 'lock') {
                _lockVault();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'change_pin',
                child: Row(
                  children: [
                    Icon(Icons.pin_rounded, size: 18, color: _kVaultPurple),
                    SizedBox(width: 10),
                    Text('Change Vault PIN'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'lock',
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Lock Vault'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Search encrypted vault...',
          hintStyle: const TextStyle(fontSize: 14, color: _kTextBody),
          prefixIcon: const Icon(Icons.search_rounded, color: _kTextBody, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: _kTextBody),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? _kVaultPurple : _kCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.amber),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : _kTextHead,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList(VaultCategory cat) {
    final items = _getFilteredItems(cat);

    if (items.isEmpty) {
      return _buildEmptyState(cat);
    }

    if (cat == VaultCategory.image) {
      // 2-column image grid
      return GridView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) => _buildImageGridTile(items[i]),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
      itemCount: items.length,
      itemBuilder: (context, i) => _buildItemCard(items[i]),
    );
  }

  Widget _buildImageGridTile(VaultItem item) {
    return GestureDetector(
      onTap: () => _openItem(item),
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: FutureBuilder(
                future: VaultService.instance.getDecryptedBytes(item),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                    );
                  }
                  return Container(
                    color: _kVaultPurple.withValues(alpha: 0.08),
                    child: const Center(
                      child: Icon(Icons.lock_rounded, color: _kVaultPurple, size: 28),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kTextHead,
                          ),
                        ),
                        Text(
                          item.formattedSize,
                          style: const TextStyle(fontSize: 10, color: _kTextBody),
                        ),
                      ],
                    ),
                  ),
                  if (item.isFavorite)
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(VaultItem item) {
    IconData icon;
    Color iconColor;

    switch (item.category) {
      case VaultCategory.video:
        icon = Icons.play_circle_filled_rounded;
        iconColor = _kSkyTag;
        break;
      case VaultCategory.audio:
        icon = Icons.headphones_rounded;
        iconColor = _kAmberTag;
        break;
      case VaultCategory.pdfNotes:
        icon = item.isNote ? Icons.description_rounded : Icons.picture_as_pdf_rounded;
        iconColor = item.isNote ? _kGreenTag : _kRedTag;
        break;
      default:
        icon = Icons.lock_rounded;
        iconColor = _kVaultPurple;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openItem(item),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kTextHead,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.isNote && item.noteSnippet != null
                            ? item.noteSnippet!
                            : '${item.formattedSize}  •  ${item.formattedDate}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: _kTextBody),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    item.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: item.isFavorite ? Colors.amber : _kTextBody,
                    size: 20,
                  ),
                  onPressed: () => VaultService.instance.toggleFavorite(item.id),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: _kTextBody),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (val) {
                    if (val == 'open') {
                      _openItem(item);
                    } else if (val == 'rename') {
                      _showRenameDialog(item);
                    } else if (val == 'delete') {
                      _confirmDelete(item);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(Icons.lock_open_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('Open'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('Rename'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: _kRedTag),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: _kRedTag)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(VaultCategory category) {
    IconData icon;
    String title;
    String subtitle;

    switch (category) {
      case VaultCategory.image:
        icon = Icons.photo_library_outlined;
        title = 'No Encrypted Photos';
        subtitle = 'Import secret photos, scans, and screenshots here.';
        break;
      case VaultCategory.video:
        icon = Icons.video_library_outlined;
        title = 'No Encrypted Videos';
        subtitle = 'Import confidential study and lecture videos here.';
        break;
      case VaultCategory.audio:
        icon = Icons.music_note_rounded;
        title = 'No Encrypted Audio';
        subtitle = 'Store confidential recordings and music tracks.';
        break;
      case VaultCategory.pdfNotes:
        icon = Icons.menu_book_rounded;
        title = 'No Encrypted PDFs or Notes';
        subtitle = 'Keep private exams, study guides, and secret notes safe.';
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _kVaultPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _kVaultPurple, size: 38),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kTextHead,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _kTextBody, height: 1.4),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              icon: Icon(
                category == VaultCategory.image
                    ? Icons.add_photo_alternate_rounded
                    : category == VaultCategory.video
                        ? Icons.video_call_rounded
                        : category == VaultCategory.audio
                            ? Icons.music_note_rounded
                            : Icons.note_add_rounded,
                size: 18,
              ),
              label: Text(
                category == VaultCategory.image
                    ? 'Add Image'
                    : category == VaultCategory.video
                        ? 'Add Video'
                        : category == VaultCategory.audio
                            ? 'Add Music'
                            : 'Add PDF / Note',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kVaultPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                switch (category) {
                  case VaultCategory.image:
                    _importImage();
                    break;
                  case VaultCategory.video:
                    _importVideo();
                    break;
                  case VaultCategory.audio:
                    _importAudio();
                    break;
                  case VaultCategory.pdfNotes:
                    _showPdfNotesChoiceModal();
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
