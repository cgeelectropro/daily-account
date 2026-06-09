// ignore_for_file: deprecated_member_use
/// Run this as a Flutter app to generate the master icon PNG:
///   flutter run -t tool/icon_generator_app.dart
///
/// It will render the icon, save it to assets/app_icon.png, and display it.
/// After the file is saved, stop the app and run:
///   dart run flutter_launcher_icons
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

void main() => runApp(const IconGeneratorApp());

class IconGeneratorApp extends StatelessWidget {
  const IconGeneratorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0D0A05),
        body: Center(child: IconGeneratorWidget()),
      ),
    );
  }
}

class IconGeneratorWidget extends StatefulWidget {
  @override
  State<IconGeneratorWidget> createState() => _IconGeneratorWidgetState();
}

class _IconGeneratorWidgetState extends State<IconGeneratorWidget> {
  final _repaintKey = GlobalKey();
  String _status = 'Generating icon...';

  @override
  void initState() {
    super.initState();
    // Wait for first frame to render, then capture
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureIcon());
  }

  Future<void> _captureIcon() async {
    try {
      // Paint programmatically to a 1024x1024 canvas
      const size = 1024.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
      _paintIcon(canvas, size);
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final file = File('assets/app_icon.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);

      if (mounted) {
        setState(() => _status = 'Icon saved to assets/app_icon.png (${bytes.length} bytes)\n\nStop the app and run:\n  dart run flutter_launcher_icons');
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          key: _repaintKey,
          child: SizedBox(
            width: 300,
            height: 300,
            child: CustomPaint(painter: _IconPreviewPainter()),
          ),
        ),
        const SizedBox(height: 24),
        Text(_status,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFD4AF64), fontSize: 16)),
      ],
    );
  }
}

class _IconPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _paintIcon(canvas, size.width);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void _paintIcon(Canvas canvas, double size) {
  final center = Offset(size / 2, size / 2);

  // ── Background ──
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size, size),
    Paint()..color = const Color(0xFF0D0A05),
  );

  // Warm radial glow
  canvas.drawCircle(
    center,
    size * 0.48,
    Paint()
      ..shader = ui.Gradient.radial(center, size * 0.48, [
        const Color(0xFF2E2010),
        const Color(0xFF1A1208),
        const Color(0xFF0D0A05),
      ], [
        0.0,
        0.55,
        1.0
      ]),
  );

  // ── Radiant rays ──
  for (var i = 0; i < 12; i++) {
    final angle = i * math.pi / 6;
    final inner = size * 0.08;
    final outer = size * 0.44;
    canvas.drawLine(
      center + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
      center + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
      Paint()
        ..color = Color(0x18D4AF64).withOpacity(i.isEven ? 0.09 : 0.04)
        ..strokeWidth = size * (i.isEven ? 0.004 : 0.002),
    );
  }

  // ── Ornamental rings ──
  canvas.drawCircle(
    center,
    size * 0.38,
    Paint()
      ..color = const Color(0x40D4AF64)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.004,
  );

  // Dots on outer ring
  for (var i = 0; i < 8; i++) {
    final angle = i * math.pi / 4;
    final pos =
        center + Offset(math.cos(angle) * size * 0.38, math.sin(angle) * size * 0.38);
    canvas.drawCircle(pos, size * 0.007, Paint()..color = const Color(0x80D4AF64));
  }

  canvas.drawCircle(
    center,
    size * 0.30,
    Paint()
      ..color = const Color(0x30D4AF64)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.003,
  );

  // Diamonds on inner ring at 45 degree angles
  for (var i = 0; i < 4; i++) {
    final angle = i * math.pi / 2 + math.pi / 4;
    final pos =
        center + Offset(math.cos(angle) * size * 0.30, math.sin(angle) * size * 0.30);
    final d = size * 0.012;
    final path = Path()
      ..moveTo(pos.dx, pos.dy - d)
      ..lineTo(pos.dx + d, pos.dy)
      ..lineTo(pos.dx, pos.dy + d)
      ..lineTo(pos.dx - d, pos.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0x60D4AF64));
  }

  // ── Cross ──
  final beamW = size * 0.09;
  final vH = size * 0.46;
  final hW = size * 0.42;
  final crossTopY = center.dy - vH / 2;
  final armCenterY = center.dy - size * 0.02; // cross arms slightly above center
  final r = beamW * 0.15;

  // Shadow
  final shadowPaint = Paint()
    ..color = const Color(0x50000000)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.008);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(center.dx + 2, center.dy + 2), width: beamW, height: vH),
      Radius.circular(r),
    ),
    shadowPaint,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(center.dx + 2, armCenterY + 2), width: hW, height: beamW),
      Radius.circular(r),
    ),
    shadowPaint,
  );

  // Main cross — gold gradient
  final crossPaint = Paint()
    ..shader = ui.Gradient.linear(
      Offset(center.dx - beamW / 2, crossTopY),
      Offset(center.dx + beamW / 2, crossTopY + vH),
      [const Color(0xFFE8D4A0), const Color(0xFFD4AF64), const Color(0xFFA07830)],
      [0.0, 0.45, 1.0],
    );

  // Vertical beam
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: beamW, height: vH),
      Radius.circular(r),
    ),
    crossPaint,
  );
  // Horizontal beam
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center.dx, armCenterY), width: hW, height: beamW),
      Radius.circular(r),
    ),
    crossPaint,
  );

  // Left edge highlight
  canvas.drawLine(
    Offset(center.dx - beamW / 2, crossTopY + r),
    Offset(center.dx - beamW / 2, crossTopY + vH - r),
    Paint()
      ..color = const Color(0x80E8D4A0)
      ..strokeWidth = size * 0.003,
  );
  // Top edge highlight on horizontal beam
  canvas.drawLine(
    Offset(center.dx - hW / 2 + r, armCenterY - beamW / 2),
    Offset(center.dx + hW / 2 - r, armCenterY - beamW / 2),
    Paint()
      ..color = const Color(0x80E8D4A0)
      ..strokeWidth = size * 0.003,
  );

  // Intersection glow
  canvas.drawRect(
    Rect.fromCenter(center: Offset(center.dx, armCenterY), width: beamW, height: beamW),
    Paint()..color = const Color(0x25E8D4A0),
  );

  // ── Ornamental diamonds at cross tips ──
  final dSize = size * 0.022;
  final diamondPaint = Paint()..color = const Color(0xFFD4AF64);
  for (final pos in [
    Offset(center.dx, crossTopY - dSize * 0.7),
    Offset(center.dx, crossTopY + vH + dSize * 0.7),
    Offset(center.dx - hW / 2 - dSize * 0.7, armCenterY),
    Offset(center.dx + hW / 2 + dSize * 0.7, armCenterY),
  ]) {
    final path = Path()
      ..moveTo(pos.dx, pos.dy - dSize)
      ..lineTo(pos.dx + dSize, pos.dy)
      ..lineTo(pos.dx, pos.dy + dSize)
      ..lineTo(pos.dx - dSize, pos.dy)
      ..close();
    canvas.drawPath(path, diamondPaint);
  }

  // ── Corner ornament dots ──
  final dotR = size * 0.006;
  final dotPaint = Paint()..color = const Color(0xFFE8D4A0);
  final crossLeft = center.dx - beamW / 2;
  final crossRight = center.dx + beamW / 2;
  final armTop = armCenterY - beamW / 2;
  final armBot = armCenterY + beamW / 2;
  final offset = size * 0.02;
  for (final pos in [
    Offset(crossLeft - offset, armTop - offset),
    Offset(crossRight + offset, armTop - offset),
    Offset(crossLeft - offset, armBot + offset),
    Offset(crossRight + offset, armBot + offset),
  ]) {
    canvas.drawCircle(pos, dotR, dotPaint);
  }
}
