import 'dart:io' as io;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/pdf_document.dart';
import '../services/pdf_storage_service.dart';
import 'pdf_viewer_screen.dart';

// ─── Design tokens matching StudyMate ─────────────────────────────────────────
const _kBg = Color(0xFFEEF0FF);
const _kPrimary = Color(0xFF5B6CF9);
const _kCard = Color(0xFFFFFFFF);
const _kTextHead = Color(0xFF1A1A2E);
const _kTextBody = Color(0xFF6B7280);
const _kPdfTag = Color(0xFFE11D48);
const _kGreenTag = Color(0xFF059669);
const _kRedTag = Color(0xFFEF4444);

class PdfLibraryScreen extends StatefulWidget {
  const PdfLibraryScreen({super.key});

  @override
  State<PdfLibraryScreen> createState() => _PdfLibraryScreenState();
}

class _PdfLibraryScreenState extends State<PdfLibraryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _filterFavoritesOnly = false;
  String _searchQuery = '';
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    PdfStorageService.instance.initialize();
    PdfStorageService.instance.addListener(_onStorageUpdate);
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  void _onStorageUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    PdfStorageService.instance.removeListener(_onStorageUpdate);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndImportPdf() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);

    try {
      final files = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (files.isEmpty) {
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      final file = files.first;
      final fileName = file.name;

      // Robust byte reading across Web (bytes/fetch) and IO (saf/filesystem)
      Uint8List? bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (e) {
        debugPrint('file.readAsBytes() failed: $e');
      }

      if ((bytes == null || bytes.isEmpty) && !kIsWeb && file.path != null && file.path!.isNotEmpty) {
        try {
          final ioFile = io.File(file.path!);
          if (await ioFile.exists()) {
            bytes = await ioFile.readAsBytes();
          }
        } catch (e) {
          debugPrint('io.File read failed: $e');
        }
      }

      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read the selected PDF file. Please ensure the file is accessible and not empty.'),
              backgroundColor: _kRedTag,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      if (!PdfStorageService.instance.isValidPdf(fileName, bytes)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid document: Selected file is not a valid PDF (must have .pdf extension and valid PDF header).'),
              backgroundColor: _kRedTag,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      final res = await PdfStorageService.instance.importPdf(
        fileName: fileName,
        bytes: bytes,
      );

      if (!mounted) return;

      if (res.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported "${res.document!.name}" successfully.'),
            backgroundColor: _kGreenTag,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (res.isDuplicate) {
        // Allow user to cancel or import as copy
        final shouldImportCopy = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _kCard,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Duplicate PDF',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kTextHead,
              ),
            ),
            content: Text(
              'A document named "$fileName" with the same size is already saved in your library. Do you want to import it as an additional copy?',
              style: const TextStyle(fontSize: 14, color: _kTextBody),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: _kTextBody)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Import Copy'),
              ),
            ],
          ),
        );

        if (shouldImportCopy == true && mounted) {
          setState(() => _isImporting = true);
          final copyRes = await PdfStorageService.instance.importPdf(
            fileName: fileName,
            bytes: bytes,
            allowDuplicate: true,
          );
          if (mounted) {
            if (copyRes.isSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Imported "${copyRes.document!.name}" as a copy.'),
                  backgroundColor: _kGreenTag,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(copyRes.error ?? 'Failed to import copy.'),
                  backgroundColor: _kRedTag,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.error ?? 'Failed to import PDF.'),
            backgroundColor: _kRedTag,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import error: $e'),
            backgroundColor: _kRedTag,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _showRenameDialog(PdfDocument doc) async {
    final controller = TextEditingController(text: doc.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Rename PDF',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _kTextHead,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Display Name',
            hintText: 'Enter new name',
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
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty && mounted) {
      await PdfStorageService.instance
          .renamePdf(doc.id, controller.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document renamed.')),
        );
      }
    }
  }

  Future<void> _confirmDelete(PdfDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Saved PDF?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _kTextHead,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${doc.name}"? This removes the persistent local copy.',
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await PdfStorageService.instance.deletePdf(doc.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${doc.name}"')),
        );
      }
    }
  }

  Future<void> _openDocument(PdfDocument doc) async {
    final res = await PdfStorageService.instance.openPdfDocument(doc);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.isSuccess ? _kPrimary : _kRedTag,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<PdfDocument> _getFilteredPdfs() {
    var list = PdfStorageService.instance.pdfs;
    if (_filterFavoritesOnly) {
      list = list.where((p) => p.isFavorite).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((p) {
        final matchesName = p.name.toLowerCase().contains(_searchQuery);
        final matchesFile =
            p.originalFileName.toLowerCase().contains(_searchQuery);
        return matchesName || matchesFile;
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final allPdfs = PdfStorageService.instance.pdfs;
    final filteredPdfs = _getFilteredPdfs();
    final favoriteCount = allPdfs.where((p) => p.isFavorite).length;

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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  _buildFilterChip(
                    label: 'All Documents (${allPdfs.length})',
                    isSelected: !_filterFavoritesOnly,
                    onTap: () {
                      if (_filterFavoritesOnly) {
                        setState(() => _filterFavoritesOnly = false);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Favorites ($favoriteCount)',
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
            // Import loading indicator banner
            if (_isImporting)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _kPrimary.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _kPrimary,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Importing and saving PDF to internal storage...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Document List
            Expanded(
              child: filteredPdfs.isEmpty
                  ? _buildEmptyState(allPdfs.isEmpty)
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: filteredPdfs.length,
                      itemBuilder: (context, i) {
                        final doc = filteredPdfs[i];
                        return _buildPdfCard(doc);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: _isImporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.add_rounded),
        label: const Text(
          'Import PDF',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        onPressed: _isImporting ? null : _pickAndImportPdf,
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          // Back button
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
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: _kTextHead,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My PDFs',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kTextHead,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Personal study documents library',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kTextBody,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // Tool Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kPdfTag.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf_rounded, size: 14, color: _kPdfTag),
                SizedBox(width: 4),
                Text(
                  'Library',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kPdfTag,
                  ),
                ),
              ],
            ),
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
          hintText: 'Search PDFs by name or filename...',
          hintStyle: const TextStyle(fontSize: 13, color: _kTextBody),
          prefixIcon: const Icon(Icons.search_rounded, color: _kTextBody, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimary : _kCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : Colors.amber,
              ),
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

  Widget _buildPdfCard(PdfDocument doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PdfViewerScreen(document: doc),
              ),
            );
          },
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // PDF Icon badge
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _kPdfTag.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: _kPdfTag,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Title and details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kTextHead,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            doc.formattedSize,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _kTextBody,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '•',
                            style: TextStyle(fontSize: 10, color: _kTextBody),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            doc.formattedDate,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _kTextBody,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Favorite Star
                IconButton(
                  icon: Icon(
                    doc.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: doc.isFavorite ? Colors.amber : _kTextBody,
                    size: 22,
                  ),
                  onPressed: () {
                    PdfStorageService.instance.toggleFavorite(doc.id);
                  },
                ),
                // Popup Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: _kTextBody, size: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  onSelected: (val) {
                    if (val == 'open') {
                      _openDocument(doc);
                    } else if (val == 'details') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfViewerScreen(document: doc),
                        ),
                      );
                    } else if (val == 'rename') {
                      _showRenameDialog(doc);
                    } else if (val == 'delete') {
                      _confirmDelete(doc);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new_rounded,
                              size: 18, color: _kPrimary),
                          SizedBox(width: 10),
                          Text('Open PDF',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'details',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Rename'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 18, color: _kRedTag),
                          SizedBox(width: 10),
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

  Widget _buildEmptyState(bool isLibraryEmpty) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLibraryEmpty
                    ? Icons.upload_file_rounded
                    : Icons.search_off_rounded,
                color: _kPrimary,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isLibraryEmpty
                  ? 'Your PDF Library is Empty'
                  : 'No Matching PDFs Found',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kTextHead,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isLibraryEmpty
                  ? 'Import syllabus, lecture notes, textbook chapters, or question papers to keep them accessible anytime.'
                  : 'Try searching with a different filename or clear the search query.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _kTextBody,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            if (isLibraryEmpty) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Import Your First PDF',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _pickAndImportPdf,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
