import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/pdf_document.dart';
import '../services/pdf_storage_service.dart';

// ─── Design tokens matching StudyMate ─────────────────────────────────────────
const _kBg = Color(0xFFFFFFFF);
const _kPrimary = Color(0xFF2563EB);
const _kPrimaryLight = Color(0xFFEFF6FF);
const _kCard = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE2E8F0);
const _kTextHead = Color(0xFF1E293B);
const _kTextBody = Color(0xFF64748B);
const _kGreenTag = Color(0xFF10B981);
const _kRedTag = Color(0xFFEF4444);

class PdfViewerScreen extends StatefulWidget {
  final PdfDocument document;
  const PdfViewerScreen({super.key, required this.document});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfDocument _doc;
  bool _fileExists = true;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _doc = widget.document;
    _checkFile();
  }

  Future<void> _checkFile() async {
    final exists =
        await PdfStorageService.instance.verifyFileExists(_doc);
    if (mounted) {
      setState(() {
        _fileExists = exists;
        _isChecking = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    await PdfStorageService.instance.toggleFavorite(_doc.id);
    if (mounted) {
      setState(() {
        _doc = _doc.copyWith(isFavorite: !_doc.isFavorite);
      });
    }
  }

  Future<void> _showRenameDialog() async {
    final controller = TextEditingController(text: _doc.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Rename Document',
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
            labelText: 'Document Name',
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

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      final newName = controller.text.trim();
      await PdfStorageService.instance.renamePdf(_doc.id, newName);
      if (mounted) {
        setState(() {
          _doc = _doc.copyWith(name: newName);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document renamed successfully.')),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Document?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _kTextHead,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${_doc.name}"? This removes the persistent local copy from StudyMate.',
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
      await PdfStorageService.instance.deletePdf(_doc.id);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${_doc.name}"')),
        );
      }
    }
  }

  Future<void> _openExternal() async {
    final res = await PdfStorageService.instance.openPdfDocument(_doc);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.isSuccess ? _kPrimary : _kRedTag,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroCard(),
                    const SizedBox(height: 16),
                    _buildDetailsCard(),
                    const SizedBox(height: 16),
                    _buildActionsCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                border: Border.all(color: _kBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _doc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _kTextHead,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  _doc.originalFileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kTextBody,
                  ),
                ),
              ],
            ),
          ),
          // Favorite toggle
          IconButton(
            icon: Icon(
              _doc.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: _doc.isFavorite ? Colors.amber : _kTextBody,
              size: 26,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _kPrimaryLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kBorder, width: 1),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: _kPrimary,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _doc.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _kTextHead,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kPrimaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'PDF Document',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '•  ${_doc.formattedSize}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _kTextBody,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Storage Status Banner
          if (_isChecking) ...[
            const CircularProgressIndicator(strokeWidth: 2),
          ] else if (_fileExists) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _kGreenTag.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: _kGreenTag, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Stored safely in StudyMate app storage',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kGreenTag,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _kRedTag.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: _kRedTag, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Local file content is missing',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kRedTag,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Document Information',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _kTextHead,
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoRow('File Name', _doc.originalFileName),
          _buildInfoRow('Stored File', _doc.storedFileName),
          _buildInfoRow('File Size', _doc.formattedSize),
          _buildInfoRow('Imported On', _doc.formattedDate),
          _buildInfoRow(
            'Favorite',
            _doc.isFavorite ? 'Yes, starred' : 'No',
          ),
          _buildInfoRow(
            'Storage Platform',
            kIsWeb ? 'Browser IndexedDB Storage' : 'App Internal Storage (study_mate_pdfs)',
          ),
          if (_doc.localPath != null) ...[
            _buildInfoRow('File Path', _doc.localPath!, isPath: true),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isPath = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment:
            isPath ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _kTextBody,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: isPath ? 3 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kTextHead,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Open PDF Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text(
                'Open Document',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _openExternal,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Rename Button
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Rename'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kTextHead,
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _showRenameDialog,
                ),
              ),
              const SizedBox(width: 10),
              // Delete Button
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 16, color: _kRedTag),
                  label: const Text('Delete',
                      style: TextStyle(color: _kRedTag)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _kRedTag.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _confirmDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
