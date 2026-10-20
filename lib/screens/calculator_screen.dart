import 'package:flutter/material.dart';

// ─── Design tokens matching StudyMate ─────────────────────────────────────────
const _kBg = Color(0xFFEEF0FF);
const _kPrimary = Color(0xFF5B6CF9);
const _kCard = Color(0xFFFFFFFF);
const _kTextHead = Color(0xFF1A1A2E);
const _kTextBody = Color(0xFF6B7280);
const _kSkyTag = Color(0xFF0284C7);
const _kRedTag = Color(0xFFEF4444);
const _kGreenTag = Color(0xFF059669);

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _expression = '';
  String _result = '0';
  String? _errorMessage;
  bool _hasEvaluated = false;

  // ── Engine ──────────────────────────────────────────────────────────────────

  void _onNumberTap(String number) {
    setState(() {
      _errorMessage = null;

      if (_hasEvaluated) {
        _expression = number;
        _result = number;
        _hasEvaluated = false;
        return;
      }

      if (_expression == '0' && number != '.') {
        _expression = number;
      } else {
        _expression += number;
      }

      _computeLivePreview();
    });
  }

  void _onDecimalTap() {
    setState(() {
      _errorMessage = null;

      if (_hasEvaluated) {
        _expression = '0.';
        _result = '0.';
        _hasEvaluated = false;
        return;
      }

      if (_expression.isEmpty) {
        _expression = '0.';
        _result = '0.';
        return;
      }

      // Check current operand doesn't already contain a decimal
      final lastToken = _getLastOperand(_expression);
      if (!lastToken.contains('.')) {
        if (_isOperator(_expression[_expression.length - 1])) {
          _expression += '0.';
        } else {
          _expression += '.';
        }
      }
      _computeLivePreview();
    });
  }

  void _onOperatorTap(String op) {
    setState(() {
      _errorMessage = null;

      if (_hasEvaluated) {
        _expression = _result + ' $op ';
        _hasEvaluated = false;
        return;
      }

      if (_expression.isEmpty) {
        if (op == '−' || op == '-') {
          _expression = '-';
        }
        return;
      }

      final trimmed = _expression.trimRight();
      final lastChar = trimmed[trimmed.length - 1];

      if (_isOperator(lastChar)) {
        // Replace previous operator
        _expression =
            trimmed.substring(0, trimmed.length - 1).trimRight() + ' $op ';
      } else {
        _expression += ' $op ';
      }
    });
  }

  void _onPercentTap() {
    setState(() {
      _errorMessage = null;
      if (_expression.isEmpty) return;

      // Extract last operand and divide by 100
      final lastNumStr = _getLastOperand(_expression);
      final lastNum = double.tryParse(lastNumStr);
      if (lastNum != null) {
        final percentVal = lastNum / 100.0;
        final formatted = _formatNumber(percentVal);
        final prefix =
            _expression.substring(0, _expression.length - lastNumStr.length);
        _expression = prefix + formatted;
        _computeLivePreview();
      }
    });
  }

  void _onClear() {
    setState(() {
      _expression = '';
      _result = '0';
      _errorMessage = null;
      _hasEvaluated = false;
    });
  }

  void _onDelete() {
    setState(() {
      _errorMessage = null;

      if (_hasEvaluated) {
        _expression = '';
        _result = '0';
        _hasEvaluated = false;
        return;
      }

      if (_expression.isEmpty) return;

      if (_expression.endsWith(' ')) {
        // Operator with padding e.g. " + "
        _expression = _expression.trimRight();
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1).trimRight();
        }
      } else {
        _expression = _expression.substring(0, _expression.length - 1);
      }

      if (_expression.isEmpty) {
        _result = '0';
      } else {
        _computeLivePreview();
      }
    });
  }

  void _onEquals() {
    setState(() {
      if (_expression.isEmpty) return;

      final res = _evaluateExpression(_expression);
      if (res.isError) {
        _errorMessage = res.error;
        _result = 'Error';
      } else {
        _result = _formatNumber(res.value!);
        _hasEvaluated = true;
      }
    });
  }

  void _computeLivePreview() {
    if (_expression.isEmpty) {
      _result = '0';
      return;
    }
    final res = _evaluateExpression(_expression);
    if (!res.isError && res.value != null) {
      _result = _formatNumber(res.value!);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  bool _isOperator(String ch) {
    return ch == '+' || ch == '−' || ch == '-' || ch == '×' || ch == '*' || ch == '÷' || ch == '/';
  }

  String _getLastOperand(String expr) {
    final parts = expr.split(RegExp(r'[\s+−\-×*÷/]+'));
    return parts.isNotEmpty ? parts.last : '';
  }

  String _formatNumber(double val) {
    if (val.isNaN || val.isInfinite) {
      return 'Error';
    }
    // Round to avoid float precision drift (e.g. 0.1 + 0.2 = 0.3)
    final rounded = double.parse(val.toStringAsPrecision(12));
    if (rounded == rounded.truncateToDouble()) {
      return rounded.toInt().toString();
    }
    // Remove trailing zeros
    String str = rounded.toString();
    if (str.contains('.')) {
      str = str.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return str;
  }

  _EvalResult _evaluateExpression(String input) {
    try {
      final sanitized = input
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('−', '-')
          .trim();

      if (sanitized.isEmpty) return const _EvalResult.value(0);

      // Tokenize
      final tokens = <String>[];
      var currentNumber = StringBuffer();

      for (var i = 0; i < sanitized.length; i++) {
        final char = sanitized[i];

        if (char == ' ') continue;

        if (_isOperatorChar(char)) {
          // Negative number check
          if (char == '-' &&
              (tokens.isEmpty || _isOperatorChar(tokens.last)) &&
              currentNumber.isEmpty) {
            currentNumber.write(char);
          } else {
            if (currentNumber.isNotEmpty) {
              tokens.add(currentNumber.toString());
              currentNumber = StringBuffer();
            }
            tokens.add(char);
          }
        } else {
          currentNumber.write(char);
        }
      }

      if (currentNumber.isNotEmpty) {
        tokens.add(currentNumber.toString());
      }

      if (tokens.isEmpty) return const _EvalResult.value(0);

      // If expression ends with an operator, evaluate up to the last operator
      if (_isOperatorChar(tokens.last)) {
        tokens.removeLast();
      }

      if (tokens.isEmpty) return const _EvalResult.value(0);

      // Evaluate precedence: * and / first
      final step1Tokens = <String>[];
      var idx = 0;
      while (idx < tokens.length) {
        final token = tokens[idx];
        if (token == '*' || token == '/') {
          if (step1Tokens.isEmpty || idx + 1 >= tokens.length) {
            return const _EvalResult.error('Invalid expression');
          }
          final prev = double.tryParse(step1Tokens.removeLast());
          final next = double.tryParse(tokens[idx + 1]);

          if (prev == null || next == null) {
            return const _EvalResult.error('Invalid number');
          }

          if (token == '/') {
            if (next == 0.0) {
              return const _EvalResult.error('Cannot divide by zero');
            }
            step1Tokens.add((prev / next).toString());
          } else {
            step1Tokens.add((prev * next).toString());
          }
          idx += 2;
        } else {
          step1Tokens.add(token);
          idx++;
        }
      }

      // Evaluate precedence: + and -
      if (step1Tokens.isEmpty) return const _EvalResult.value(0);
      var total = double.tryParse(step1Tokens[0]);
      if (total == null) return const _EvalResult.error('Invalid number');

      idx = 1;
      while (idx < step1Tokens.length) {
        final op = step1Tokens[idx];
        if (idx + 1 >= step1Tokens.length) break;
        final nextVal = double.tryParse(step1Tokens[idx + 1]);
        if (nextVal == null) return const _EvalResult.error('Invalid number');

        if (op == '+') {
          total = total! + nextVal;
        } else if (op == '-') {
          total = total! - nextVal;
        }
        idx += 2;
      }

      return _EvalResult.value(total!);
    } catch (_) {
      return const _EvalResult.error('Invalid input');
    }
  }

  bool _isOperatorChar(String ch) {
    return ch == '+' || ch == '-' || ch == '*' || ch == '/';
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 8),
            // Display Screen Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildDisplayCard(),
            ),
            const SizedBox(height: 16),
            // Keypad
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _buildKeypad(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                  'Calculator',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kTextHead,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Mini study & quick calculations',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kTextBody,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // Tool badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kSkyTag.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calculate_rounded, size: 14, color: _kSkyTag),
                SizedBox(width: 4),
                Text(
                  'Tool',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kSkyTag,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Expression line
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Text(
              _expression.isEmpty ? ' ' : _expression,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _kTextBody,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Error or Main Result
          if (_errorMessage != null) ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _kRedTag,
                ),
              ),
            ),
          ] else ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                _result,
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: _kTextHead,
                  letterSpacing: -1.0,
                  fontFeatures: [
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildKey(
                  label: 'AC',
                  textColor: _kRedTag,
                  bgColor: _kRedTag.withValues(alpha: 0.10),
                  onTap: _onClear,
                ),
                _buildKey(
                  icon: Icons.backspace_outlined,
                  textColor: _kTextHead,
                  bgColor: _kBg,
                  onTap: _onDelete,
                ),
                _buildKey(
                  label: '%',
                  textColor: _kSkyTag,
                  bgColor: _kSkyTag.withValues(alpha: 0.12),
                  onTap: _onPercentTap,
                ),
                _buildKey(
                  label: '÷',
                  textColor: _kPrimary,
                  bgColor: _kPrimary.withValues(alpha: 0.14),
                  onTap: () => _onOperatorTap('÷'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _buildKey(label: '7', onTap: () => _onNumberTap('7')),
                _buildKey(label: '8', onTap: () => _onNumberTap('8')),
                _buildKey(label: '9', onTap: () => _onNumberTap('9')),
                _buildKey(
                  label: '×',
                  textColor: _kPrimary,
                  bgColor: _kPrimary.withValues(alpha: 0.14),
                  onTap: () => _onOperatorTap('×'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _buildKey(label: '4', onTap: () => _onNumberTap('4')),
                _buildKey(label: '5', onTap: () => _onNumberTap('5')),
                _buildKey(label: '6', onTap: () => _onNumberTap('6')),
                _buildKey(
                  label: '−',
                  textColor: _kPrimary,
                  bgColor: _kPrimary.withValues(alpha: 0.14),
                  onTap: () => _onOperatorTap('−'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _buildKey(label: '1', onTap: () => _onNumberTap('1')),
                _buildKey(label: '2', onTap: () => _onNumberTap('2')),
                _buildKey(label: '3', onTap: () => _onNumberTap('3')),
                _buildKey(
                  label: '+',
                  textColor: _kPrimary,
                  bgColor: _kPrimary.withValues(alpha: 0.14),
                  onTap: () => _onOperatorTap('+'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _buildKey(label: '0', onTap: () => _onNumberTap('0')),
                _buildKey(label: '00', onTap: () => _onNumberTap('00')),
                _buildKey(label: '.', onTap: _onDecimalTap),
                _buildKey(
                  label: '=',
                  textColor: Colors.white,
                  bgColor: _kPrimary,
                  isEquals: true,
                  onTap: _onEquals,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKey({
    String? label,
    IconData? icon,
    Color textColor = _kTextHead,
    Color bgColor = _kBg,
    bool isEquals = false,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              alignment: Alignment.center,
              decoration: isEquals
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _kPrimary.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    )
                  : null,
              child: icon != null
                  ? Icon(icon, color: textColor, size: 20)
                  : Text(
                      label ?? '',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EvalResult {
  final double? value;
  final String? error;

  const _EvalResult.value(double this.value) : error = null;
  const _EvalResult.error(String this.error) : value = null;

  bool get isError => error != null;
}
