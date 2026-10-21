import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/vault_service.dart';
import 'vault_home_screen.dart';

// ─── Design tokens matching StudyMate ─────────────────────────────────────────
const _kBg = Color(0xFFEEF0FF);
const _kPrimary = Color(0xFF5B6CF9);
const _kVaultPurple = Color(0xFF7C3AED);
const _kCard = Color(0xFFFFFFFF);
const _kTextHead = Color(0xFF1A1A2E);
const _kTextBody = Color(0xFF6B7280);
const _kRedTag = Color(0xFFEF4444);
const _kGreenTag = Color(0xFF059669);

enum _LockMode {
  createPin,
  confirmPin,
  enterPin,
}

class VaultLockScreen extends StatefulWidget {
  final bool isChangingPin;
  const VaultLockScreen({super.key, this.isChangingPin = false});

  @override
  State<VaultLockScreen> createState() => _VaultLockScreenState();
}

class _VaultLockScreenState extends State<VaultLockScreen>
    with SingleTickerProviderStateMixin {
  late _LockMode _mode;
  String _enteredPin = '';
  String _firstPin = '';
  String? _errorMessage;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    final hasPin = VaultService.instance.hasPin;
    if (widget.isChangingPin || !hasPin) {
      _mode = _LockMode.createPin;
    } else {
      _mode = _LockMode.enterPin;
    }

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPress(String digit) {
    if (_enteredPin.length >= 4) return;
    HapticFeedback.lightImpact();

    setState(() {
      _enteredPin += digit;
      _errorMessage = null;
    });

    if (_enteredPin.length == 4) {
      _handleCompletedPin();
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _onClear() {
    if (_enteredPin.isNotEmpty) {
      HapticFeedback.mediumImpact();
      setState(() {
        _enteredPin = '';
        _errorMessage = null;
      });
    }
  }

  Future<void> _handleCompletedPin() async {
    final pin = _enteredPin;

    if (_mode == _LockMode.enterPin) {
      final success = await VaultService.instance.unlock(pin);
      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VaultHomeScreen()),
        );
      } else if (mounted) {
        _triggerError('Incorrect PIN. Please try again.');
      }
    } else if (_mode == _LockMode.createPin) {
      setState(() {
        _firstPin = pin;
        _enteredPin = '';
        _mode = _LockMode.confirmPin;
      });
    } else if (_mode == _LockMode.confirmPin) {
      if (pin == _firstPin) {
        // Prompt for optional security hint
        final hint = await _showHintDialog();
        if (widget.isChangingPin) {
          await VaultService.instance.changePin(
            oldPin: _firstPin,
            newPin: pin,
            hint: hint,
          );
          if (mounted) {
            Navigator.pop(context, true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Vault PIN updated successfully!'),
                backgroundColor: _kGreenTag,
              ),
            );
          }
        } else {
          await VaultService.instance.setupPin(pin, hint: hint);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const VaultHomeScreen()),
            );
          }
        }
      } else {
        _triggerError('PINs do not match. Start over.');
        setState(() {
          _firstPin = '';
          _mode = _LockMode.createPin;
        });
      }
    }
  }

  void _triggerError(String msg) {
    HapticFeedback.heavyImpact();
    setState(() {
      _errorMessage = msg;
      _enteredPin = '';
    });
    _shakeController.forward(from: 0.0);
  }

  Future<String?> _showHintDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: _kVaultPurple),
            SizedBox(width: 10),
            Text(
              'Security Hint',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kTextHead,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add an optional hint in case you forget your vault PIN. (Never enter your actual PIN here!)',
              style: TextStyle(fontSize: 13, color: _kTextBody, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'e.g. Graduation year, favorite book',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Skip', style: TextStyle(color: _kTextBody)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kVaultPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save PIN & Enter'),
          ),
        ],
      ),
    );
  }

  void _showForgotPinDialog() {
    final hint = VaultService.instance.pinHint;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Forgot Vault PIN?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _kTextHead,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hint != null && hint.isNotEmpty) ...[
              const Text(
                'Your saved hint:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextHead),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kVaultPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  hint,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kVaultPurple),
                ),
              ),
              const SizedBox(height: 14),
            ] else ...[
              const Text(
                'No hint was configured during vault setup.',
                style: TextStyle(fontSize: 13, color: _kTextBody),
              ),
              const SizedBox(height: 14),
            ],
            const Text(
              'Your vault is encrypted with 256-bit AES. If you have permanently lost your PIN, the only recovery is an emergency reset (which safely erases the encrypted vault).',
              style: TextStyle(fontSize: 12, color: _kTextBody, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: _kTextBody)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmEmergencyReset();
            },
            child: const Text('Reset Vault', style: TextStyle(color: _kRedTag)),
          ),
        ],
      ),
    );
  }

  void _confirmEmergencyReset() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm Emergency Reset',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _kRedTag,
          ),
        ),
        content: const Text(
          'This will permanently erase all encrypted files, albums, and notes in the vault, and remove your PIN. Are you sure?',
          style: TextStyle(fontSize: 14, color: _kTextBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _kTextBody)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRedTag,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await VaultService.instance.resetVault();
              if (mounted) {
                setState(() {
                  _mode = _LockMode.createPin;
                  _enteredPin = '';
                  _firstPin = '';
                  _errorMessage = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vault reset successfully. You can create a new PIN.'),
                    backgroundColor: _kPrimary,
                  ),
                );
              }
            },
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
  }

  String get _titleText {
    switch (_mode) {
      case _LockMode.createPin:
        return widget.isChangingPin ? 'Create New PIN' : 'Set Up Vault PIN';
      case _LockMode.confirmPin:
        return 'Confirm Vault PIN';
      case _LockMode.enterPin:
        return 'Personal Vault';
    }
  }

  String get _subtitleText {
    switch (_mode) {
      case _LockMode.createPin:
        return 'Enter a 4-digit PIN to encrypt your vault';
      case _LockMode.confirmPin:
        return 'Re-enter your 4-digit PIN to confirm';
      case _LockMode.enterPin:
        return 'Enter your 4-digit PIN to unlock';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top back button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    color: _kTextHead,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const Spacer(),
                  if (_mode == _LockMode.enterPin)
                    TextButton.icon(
                      icon: const Icon(Icons.help_outline_rounded, size: 16, color: _kVaultPurple),
                      label: const Text('Forgot PIN?', style: TextStyle(color: _kVaultPurple, fontWeight: FontWeight.w600)),
                      onPressed: _showForgotPinDialog,
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Vault Shield Icon
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_kVaultPurple, Color(0xFF9333EA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _kVaultPurple.withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _titleText,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _kTextHead,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _subtitleText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _kTextBody,
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Animated PIN Dots
                      AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(_shakeAnimation.value, 0),
                            child: child,
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final filled = index < _enteredPin.length;
                            final hasError = _errorMessage != null;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: filled
                                    ? (hasError ? _kRedTag : _kVaultPurple)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: hasError
                                      ? _kRedTag
                                      : (filled ? _kVaultPurple : const Color(0xFFCBD5E1)),
                                  width: 2.2,
                                ),
                                boxShadow: filled
                                    ? [
                                        BoxShadow(
                                          color: (hasError ? _kRedTag : _kVaultPurple)
                                              .withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Error message if any
                      if (_errorMessage != null)
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kRedTag,
                          ),
                        )
                      else
                        const SizedBox(height: 16),
                      const SizedBox(height: 16),
                      // Keypad
                      _buildKeypad(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDigitButton('1'),
              _buildDigitButton('2'),
              _buildDigitButton('3'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDigitButton('4'),
              _buildDigitButton('5'),
              _buildDigitButton('6'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDigitButton('7'),
              _buildDigitButton('8'),
              _buildDigitButton('9'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Clear All
              _buildActionButton(
                icon: Icons.clear_rounded,
                onTap: _onClear,
                label: 'Clear',
              ),
              _buildDigitButton('0'),
              // Backspace
              _buildActionButton(
                icon: Icons.backspace_outlined,
                onTap: _onBackspace,
                label: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDigitButton(String digit) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeyPress(digit),
        borderRadius: BorderRadius.circular(36),
        child: Ink(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: _kCard,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: _kTextHead,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String label,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          child: Icon(icon, color: _kTextBody, size: 24),
        ),
      ),
    );
  }
}
