import 'package:flutter/material.dart';

class LockScreen extends StatefulWidget {
  final String expectedPin;
  final VoidCallback onUnlocked;
  final VoidCallback onBiometricTap;
  final void Function(String msg) onMessage;

  const LockScreen({
    super.key,
    required this.expectedPin,
    required this.onUnlocked,
    required this.onBiometricTap,
    required this.onMessage,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _pinCtrl = TextEditingController();
  int _pinAttempts = 0;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _tryPin() {
    if (_pinCtrl.text.trim() == widget.expectedPin) {
      _pinCtrl.clear();
      _pinAttempts = 0;
      widget.onUnlocked();
    } else {
      _pinAttempts++;
      _pinCtrl.clear();
      if (_pinAttempts >= 5) {
        widget.onMessage('Too many wrong attempts. Wait a moment.');
      } else {
        widget.onMessage('Incorrect PIN! (${5 - _pinAttempts} left)');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fingerprint,
                  size: 68,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'EasyRent Tracker Locked',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: 'Enter PIN',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _tryPin(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _tryPin,
                    icon: const Icon(Icons.lock_open, size: 18),
                    label: const Text('Unlock with PIN'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onBiometricTap,
                    icon: const Icon(Icons.fingerprint, size: 20),
                    label: const Text('Fingerprint'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
