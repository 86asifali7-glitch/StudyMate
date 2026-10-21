import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/vault_item.dart';
import '../services/vault_service.dart';

const _kBg = Color(0xFFFFFFFF);
const _kCard = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE2E8F0);
const _kTextHead = Color(0xFF1E293B);
const _kTextBody = Color(0xFF64748B);
const _kVaultPurple = Color(0xFF2563EB);

class VaultNoteEditorScreen extends StatefulWidget {
  final VaultItem? existingItem;
  const VaultNoteEditorScreen({super.key, this.existingItem});

  @override
  State<VaultNoteEditorScreen> createState() => _VaultNoteEditorScreenState();
}

class _VaultNoteEditorScreenState extends State<VaultNoteEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      _loadExistingNote();
    }
  }

  Future<void> _loadExistingNote() async {
    setState(() => _isLoading = true);
    final item = widget.existingItem!;
    _titleController.text = item.name;

    try {
      final bytes = await VaultService.instance.getDecryptedBytes(item);
      if (bytes != null && mounted) {
        _contentController.text = utf8.decode(bytes);
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text;

    if (content.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note content cannot be empty.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.existingItem != null) {
        // If editing existing, delete old and create new with updated content
        await VaultService.instance.deleteItem(widget.existingItem!.id);
      }

      await VaultService.instance.createSecretNote(
        title: title.isEmpty ? 'Untitled Secret Note' : title,
        content: content,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Secret note encrypted and saved!'),
            backgroundColor: _kVaultPurple,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save note: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        title: Text(
          widget.existingItem != null ? 'Edit Secret Note' : 'New Secret Note',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kVaultPurple),
                  )
                : const Icon(Icons.check_rounded, color: _kVaultPurple, size: 28),
            onPressed: _isSaving ? null : _saveNote,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kVaultPurple))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kBorder, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: _titleController,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kTextHead),
                      decoration: const InputDecoration(
                        hintText: 'Note Title...',
                        hintStyle: TextStyle(color: _kTextBody),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _kBorder, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _contentController,
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(fontSize: 15, height: 1.5, color: _kTextHead),
                        decoration: const InputDecoration(
                          hintText: 'Write confidential note here... (encrypted with 256-bit AES)',
                          hintStyle: TextStyle(color: _kTextBody),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }
}
