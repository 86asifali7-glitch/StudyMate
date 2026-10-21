import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../models/vault_item.dart';
import '../services/vault_service.dart';

const _kBg = Color(0xFFFFFFFF);
const _kCard = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE2E8F0);
const _kTextHead = Color(0xFF1E293B);
const _kTextBody = Color(0xFF64748B);
const _kVaultPurple = Color(0xFF2563EB);
const _kPrimaryLight = Color(0xFFEFF6FF);
const _kRedTag = Color(0xFFEF4444);
const _kGreenTag = Color(0xFF10B981);

class VaultPdfViewerScreen extends StatefulWidget {
  final VaultItem item;
  const VaultPdfViewerScreen({super.key, required this.item});

  @override
  State<VaultPdfViewerScreen> createState() => _VaultPdfViewerScreenState();
}

class _VaultPdfViewerScreenState extends State<VaultPdfViewerScreen> {
  late VaultItem _item;
  bool _isOpening = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  Future<void> _openPdf() async {
    setState(() => _isOpening = true);
    try {
      final tmpPath = await VaultService.instance.prepareTempFileForOpening(_item);
      if (tmpPath != null) {
        await OpenFilex.open(tmpPath);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to decrypt PDF document.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  Future<void> _showRenameDialog() async {
    final controller = TextEditingController(text: _item.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename PDF', style: TextStyle(fontWeight: FontWeight.w700, color: _kTextHead)),
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

    if (confirmed == true && controller.text.trim().isNotEmpty && mounted) {
      final newName = controller.text.trim();
      await VaultService.instance.renameItem(_item.id, newName);
      setState(() {
        _item = _item.copyWith(name: newName);
      });
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete from Vault?', style: TextStyle(fontWeight: FontWeight.w700, color: _kTextHead)),
        content: Text('Are you sure you want to permanently delete "${_item.name}" from your vault?'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _kTextHead,
        title: const Text(
          'Encrypted PDF Document',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _item.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: _item.isFavorite ? Colors.amber : _kTextBody,
            ),
            onPressed: () async {
              await VaultService.instance.toggleFavorite(_item.id);
              setState(() {
                _item = _item.copyWith(isFavorite: !_item.isFavorite);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _showRenameDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: _kRedTag),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // PDF Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _kBorder, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
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
                        color: _kVaultPurple,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _item.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _kTextHead,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _item.originalFileName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: _kTextBody),
                    ),
                    const SizedBox(height: 16),
                    // Security badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kGreenTag.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_rounded, size: 14, color: _kGreenTag),
                          SizedBox(width: 6),
                          Text(
                            'Encrypted with 256-bit AES',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _kGreenTag,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Document Details',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kTextHead),
                    ),
                    const SizedBox(height: 14),
                    _buildRow('File Size', _item.formattedSize),
                    _buildRow('Imported On', _item.formattedDate),
                    _buildRow('Stored Key', _item.storedFileName),
                    _buildRow('Category', 'PDF Study Document'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Open Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isOpening
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.open_in_new_rounded, size: 20),
                  label: const Text(
                    'Open PDF Reader',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kVaultPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isOpening ? null : _openPdf,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: _kTextBody)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kTextHead)),
        ],
      ),
    );
  }
}
