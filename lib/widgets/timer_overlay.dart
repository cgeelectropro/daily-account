import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Floating timer overlay displayed over other apps.
///
/// This widget runs in a separate isolate via [overlayMain] and receives
/// timer updates from the main app through [FlutterOverlayWindow.overlayListener].
///
/// Data format (sent via FlutterOverlayWindow.shareData):
///   { "elapsed": "12:34", "icon": "🙏", "label": "Prayer", "paused": false }
///   { "action": "close" }
class TimerOverlay extends StatefulWidget {
  const TimerOverlay({super.key});

  @override
  State<TimerOverlay> createState() => _TimerOverlayState();
}

class _TimerOverlayState extends State<TimerOverlay> {
  String _elapsed = '00:00';
  String _icon = '\u23F1';
  String _label = '';
  bool _paused = false;
  bool _expanded = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map) {
        if (data['action'] == 'close') {
          FlutterOverlayWindow.closeOverlay();
          return;
        }
        setState(() {
          _elapsed = data['elapsed'] ?? _elapsed;
          _icon = data['icon'] ?? _icon;
          _label = data['label'] ?? _label;
          _paused = data['paused'] ?? _paused;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_expanded) return _buildExpanded();
    return _buildBubble();
  }

  Widget _buildBubble() {
    return GestureDetector(
      onTap: () => setState(() => _expanded = true),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _paused ? const Color(0xFF241A0C) : const Color(0xFF1A1208),
          border: Border.all(
            color: const Color(0xFFD4AF64),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x60000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _icon,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              _elapsed,
              style: const TextStyle(
                color: Color(0xFFD4AF64),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpanded() {
    return GestureDetector(
      onTap: () => setState(() => _expanded = false),
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF1A1208),
          border: Border.all(
            color: const Color(0xFFD4AF64),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x60000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(_icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _label,
                    style: const TextStyle(
                      color: Color(0xFFF0E8D8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _paused ? 'Paused  $_elapsed' : _elapsed,
              style: TextStyle(
                color: _paused
                    ? const Color(0xFFA09070)
                    : const Color(0xFFD4AF64),
                fontSize: 22,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
