import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// A PIN / biometric lock screen shown before the app content.
class LockScreen extends StatefulWidget {
  final Widget child;
  const LockScreen({super.key, required this.child});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _unlocked = false;
  bool _loading = true;
  bool _lockEnabled = false;
  bool _useBiometrics = false;
  String _storedPin = '';
  String _enteredPin = '';
  String _error = '';
  final _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkLock();
  }

  Future<void> _checkLock() async {
    final s = StorageService.instance;
    _lockEnabled = (await s.getSetting('appLockEnabled', fallback: 'false')) == 'true';
    _useBiometrics = (await s.getSetting('useBiometrics', fallback: 'false')) == 'true';
    _storedPin = await s.getSetting('appPin', fallback: '');

    if (!_lockEnabled || _storedPin.isEmpty) {
      setState(() { _unlocked = true; _loading = false; });
      return;
    }

    setState(() => _loading = false);

    if (_useBiometrics) {
      // Defer to after the first frame so context/localization is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_unlocked) _tryBiometric();
      });
    }
  }

  Future<void> _tryBiometric() async {
    try {
      final canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheck || !mounted) return;

      // Check what biometric types are available
      final availableBiometrics = await _auth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty && !await _auth.isDeviceSupported()) return;

      if (!mounted) return;
      final l = S.of(context);
      final ok = await _auth.authenticate(
        localizedReason: l.useBiometricsPrompt,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // allow PIN/pattern fallback on device
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
      if (ok && mounted) {
        setState(() => _unlocked = true);
      }
    } catch (_) {
      // Biometric unavailable — fall back to PIN
    }
  }

  void _onDigit(String digit) {
    if (_enteredPin.length >= 4) return;
    setState(() {
      _enteredPin += digit;
      _error = '';
    });
    if (_enteredPin.length == 4) {
      if (_enteredPin == _storedPin) {
        setState(() => _unlocked = true);
      } else {
        setState(() {
          _error = S.of(context).wrongPin;
          _enteredPin = '';
        });
      }
    }
  }

  void _onDelete() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _error = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.isDark(context) ? AppTheme.bg0 : AppTheme.lightBg0,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accentGold(context))),
      );
    }
    if (_unlocked) return widget.child;

    final accent = AppTheme.accentGold(context);
    final textCol = AppTheme.textColor(context);
    final mutedCol = AppTheme.mutedColor(context);
    final l = S.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('\u{1F512}', style: TextStyle(fontSize: 48, color: accent)),
                const SizedBox(height: 16),
                Text(l.appTitle, style: AppTheme.display(24, color: accent)),
                const SizedBox(height: 8),
                Text(l.enterPin, style: AppTheme.serif(15, color: mutedCol)),
                const SizedBox(height: 32),

                // PIN dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _enteredPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? accent : Colors.transparent,
                        border: Border.all(color: accent, width: 1.5),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),

                if (_error.isNotEmpty)
                  Text(_error, style: AppTheme.serif(13, color: AppTheme.rust)),

                const SizedBox(height: 32),

                // Number pad
                _buildNumberPad(accent, textCol, mutedCol),

                const SizedBox(height: 16),

                // Biometric button
                if (_useBiometrics)
                  GestureDetector(
                    onTap: _tryBiometric,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fingerprint, color: accent, size: 22),
                          const SizedBox(width: 8),
                          Text(l.useBiometrics, style: AppTheme.serif(14, color: accent)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad(Color accent, Color textCol, Color mutedCol) {
    final digits = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '\u232B'],
    ];
    return Column(
      children: digits.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((d) {
              if (d.isEmpty) return const SizedBox(width: 72, height: 56);
              final isDelete = d == '\u232B';
              return GestureDetector(
                onTap: isDelete ? _onDelete : () => _onDigit(d),
                child: Container(
                  width: 72,
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: 0.2)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    d,
                    style: isDelete
                        ? TextStyle(fontSize: 22, color: mutedCol)
                        : AppTheme.display(22, color: textCol),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
