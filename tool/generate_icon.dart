// ignore_for_file: avoid_print
/// Generates the 1024x1024 app icon PNG using the `image` package (pure Dart).
/// Run:  dart run tool/generate_icon.dart
/// Then: dart run flutter_launcher_icons
library;

import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

const int size = 1024;
const double half = size / 2;

// App palette
const bg0 = (r: 13, g: 10, b: 5);
const bg1 = (r: 26, g: 18, b: 8);
const bg2 = (r: 46, g: 32, b: 16);
const gold = (r: 212, g: 175, b: 100);
const goldDeep = (r: 160, g: 120, b: 48);
const goldSoft = (r: 232, g: 212, b: 160);

void main() {
  print('Generating 1024x1024 app icon...');
  final image = img.Image(width: size, height: size);

  // Fill background
  _fillRect(image, 0, 0, size, size, bg0.r, bg0.g, bg0.b);

  // Radial glow
  _drawRadialGlow(image);

  // Subtle radiant rays
  _drawRays(image);

  // Ornamental rings
  _drawRing(image, half, half, size * 0.38, gold.r, gold.g, gold.b, 0.25, 3);
  _drawRingDots(image, half, half, size * 0.38, 8, gold.r, gold.g, gold.b, 0.5, 5);
  _drawRing(image, half, half, size * 0.30, gold.r, gold.g, gold.b, 0.18, 2);
  _drawRingDiamonds(image, half, half, size * 0.30, 4, gold.r, gold.g, gold.b, 0.35, 10);

  // Golden cross
  _drawCross(image);

  // Ornamental diamonds at cross tips
  _drawTipDiamonds(image);

  // Corner dots
  _drawCornerDots(image);

  // Save
  final dir = Directory('assets');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final file = File('assets/app_icon.png');
  file.writeAsBytesSync(img.encodePng(image));
  print('Saved to ${file.path} (${file.lengthSync()} bytes)');
  print('Now run:  dart run flutter_launcher_icons');
}

// ── Drawing helpers ──

void _fillRect(img.Image image, int x, int y, int w, int h, int r, int g, int b, [double a = 1.0]) {
  for (var py = y; py < y + h && py < size; py++) {
    for (var px = x; px < x + w && px < size; px++) {
      if (px >= 0 && py >= 0) {
        _blendPixel(image, px, py, r, g, b, a);
      }
    }
  }
}

void _blendPixel(img.Image image, int x, int y, int r, int g, int b, double a) {
  if (x < 0 || x >= size || y < 0 || y >= size) return;
  if (a >= 1.0) {
    image.setPixelRgba(x, y, r, g, b, 255);
    return;
  }
  if (a <= 0.0) return;
  final existing = image.getPixel(x, y);
  final er = existing.r.toInt();
  final eg = existing.g.toInt();
  final eb = existing.b.toInt();
  final nr = (r * a + er * (1 - a)).round().clamp(0, 255);
  final ng = (g * a + eg * (1 - a)).round().clamp(0, 255);
  final nb = (b * a + eb * (1 - a)).round().clamp(0, 255);
  image.setPixelRgba(x, y, nr, ng, nb, 255);
}

void _drawRadialGlow(img.Image image) {
  final maxR = size * 0.48;
  for (var py = 0; py < size; py++) {
    for (var px = 0; px < size; px++) {
      final dx = px - half;
      final dy = py - half;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist > maxR) continue;
      final t = dist / maxR;
      // Interpolate bg2 -> bg1 -> bg0
      int r, g, b;
      double a;
      if (t < 0.55) {
        final lt = t / 0.55;
        r = _lerp(bg2.r, bg1.r, lt);
        g = _lerp(bg2.g, bg1.g, lt);
        b = _lerp(bg2.b, bg1.b, lt);
        a = 1.0 - t * 0.3;
      } else {
        final lt = (t - 0.55) / 0.45;
        r = _lerp(bg1.r, bg0.r, lt);
        g = _lerp(bg1.g, bg0.g, lt);
        b = _lerp(bg1.b, bg0.b, lt);
        a = 0.8 - lt * 0.5;
      }
      _blendPixel(image, px, py, r, g, b, a.clamp(0.0, 1.0));
    }
  }
}

int _lerp(int a, int b, double t) => (a + (b - a) * t).round().clamp(0, 255);

void _drawRays(img.Image image) {
  for (var i = 0; i < 12; i++) {
    final angle = i * math.pi / 6;
    final inner = size * 0.08;
    final outer = size * 0.44;
    final opacity = i.isEven ? 0.09 : 0.04;
    final width = i.isEven ? 3 : 1;
    _drawLineAA(image,
      half + math.cos(angle) * inner, half + math.sin(angle) * inner,
      half + math.cos(angle) * outer, half + math.sin(angle) * outer,
      gold.r, gold.g, gold.b, opacity, width);
  }
}

void _drawLineAA(img.Image image, double x0, double y0, double x1, double y1,
    int r, int g, int b, double a, int width) {
  final dx = x1 - x0;
  final dy = y1 - y0;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len < 1) return;
  final steps = len.ceil() * 2;
  for (var s = 0; s <= steps; s++) {
    final t = s / steps;
    final cx = x0 + dx * t;
    final cy = y0 + dy * t;
    for (var w = -(width ~/ 2); w <= width ~/ 2; w++) {
      final px = (cx + (-dy / len) * w).round();
      final py = (cy + (dx / len) * w).round();
      _blendPixel(image, px, py, r, g, b, a);
    }
  }
}

void _drawRing(img.Image image, double cx, double cy, double radius,
    int r, int g, int b, double a, int thickness) {
  final steps = (radius * 2 * math.pi).ceil();
  for (var s = 0; s < steps; s++) {
    final angle = s * 2 * math.pi / steps;
    for (var t = -thickness ~/ 2; t <= thickness ~/ 2; t++) {
      final px = (cx + math.cos(angle) * (radius + t)).round();
      final py = (cy + math.sin(angle) * (radius + t)).round();
      _blendPixel(image, px, py, r, g, b, a);
    }
  }
}

void _drawRingDots(img.Image image, double cx, double cy, double radius,
    int count, int r, int g, int b, double a, int dotRadius) {
  for (var i = 0; i < count; i++) {
    final angle = i * 2 * math.pi / count;
    final dx = (cx + math.cos(angle) * radius).round();
    final dy = (cy + math.sin(angle) * radius).round();
    _fillCircle(image, dx, dy, dotRadius, r, g, b, a);
  }
}

void _drawRingDiamonds(img.Image image, double cx, double cy, double radius,
    int count, int r, int g, int b, double a, int diamondSize) {
  for (var i = 0; i < count; i++) {
    final angle = i * 2 * math.pi / count + math.pi / 4;
    final dx = cx + math.cos(angle) * radius;
    final dy = cy + math.sin(angle) * radius;
    _fillDiamond(image, dx, dy, diamondSize.toDouble(), r, g, b, a);
  }
}

void _fillCircle(img.Image image, int cx, int cy, int radius, int r, int g, int b, double a) {
  for (var py = cy - radius; py <= cy + radius; py++) {
    for (var px = cx - radius; px <= cx + radius; px++) {
      final dx = px - cx;
      final dy = py - cy;
      if (dx * dx + dy * dy <= radius * radius) {
        _blendPixel(image, px, py, r, g, b, a);
      }
    }
  }
}

void _fillDiamond(img.Image image, double cx, double cy, double d, int r, int g, int b, double a) {
  for (var py = (cy - d).round(); py <= (cy + d).round(); py++) {
    for (var px = (cx - d).round(); px <= (cx + d).round(); px++) {
      final adx = (px - cx).abs();
      final ady = (py - cy).abs();
      if (adx + ady <= d) {
        _blendPixel(image, px, py, r, g, b, a);
      }
    }
  }
}

void _drawCross(img.Image image) {
  final beamW = (size * 0.09).round();
  final vH = (size * 0.46).round();
  final hW = (size * 0.42).round();
  final centerY = half.round();
  final centerX = half.round();
  final crossTopY = centerY - vH ~/ 2;
  final armCenterY = centerY - (size * 0.02).round();

  // Shadow
  _fillRoundedRect(image, centerX - beamW ~/ 2 + 4, crossTopY + 4, beamW, vH,
      beamW ~/ 6, 0, 0, 0, 0.25);
  _fillRoundedRect(image, centerX - hW ~/ 2 + 4, armCenterY - beamW ~/ 2 + 4, hW, beamW,
      beamW ~/ 6, 0, 0, 0, 0.25);

  // Vertical beam — gold gradient (top to bottom: goldSoft -> gold -> goldDeep)
  _fillGradientRect(image, centerX - beamW ~/ 2, crossTopY, beamW, vH, beamW ~/ 6);

  // Horizontal beam
  _fillGradientRect(image, centerX - hW ~/ 2, armCenterY - beamW ~/ 2, hW, beamW, beamW ~/ 6);

  // Left edge highlight (vertical beam)
  for (var py = crossTopY + beamW ~/ 6; py < crossTopY + vH - beamW ~/ 6; py++) {
    _blendPixel(image, centerX - beamW ~/ 2, py, goldSoft.r, goldSoft.g, goldSoft.b, 0.45);
    _blendPixel(image, centerX - beamW ~/ 2 + 1, py, goldSoft.r, goldSoft.g, goldSoft.b, 0.25);
  }

  // Top edge highlight (horizontal beam)
  for (var px = centerX - hW ~/ 2 + beamW ~/ 6; px < centerX + hW ~/ 2 - beamW ~/ 6; px++) {
    _blendPixel(image, px, armCenterY - beamW ~/ 2, goldSoft.r, goldSoft.g, goldSoft.b, 0.45);
    _blendPixel(image, px, armCenterY - beamW ~/ 2 + 1, goldSoft.r, goldSoft.g, goldSoft.b, 0.25);
  }

  // Intersection glow
  _fillRect(image, centerX - beamW ~/ 2, armCenterY - beamW ~/ 2, beamW, beamW,
      goldSoft.r, goldSoft.g, goldSoft.b, 0.12);
}

void _fillRoundedRect(img.Image image, int x, int y, int w, int h, int r,
    int cr, int cg, int cb, double a) {
  for (var py = y; py < y + h; py++) {
    for (var px = x; px < x + w; px++) {
      // Check corners for rounding
      if (_isInRoundedRect(px, py, x, y, w, h, r)) {
        _blendPixel(image, px, py, cr, cg, cb, a);
      }
    }
  }
}

bool _isInRoundedRect(int px, int py, int x, int y, int w, int h, int r) {
  if (px < x || px >= x + w || py < y || py >= y + h) return false;
  // Top-left corner
  if (px < x + r && py < y + r) {
    final dx = px - (x + r);
    final dy = py - (y + r);
    return dx * dx + dy * dy <= r * r;
  }
  // Top-right corner
  if (px >= x + w - r && py < y + r) {
    final dx = px - (x + w - r);
    final dy = py - (y + r);
    return dx * dx + dy * dy <= r * r;
  }
  // Bottom-left corner
  if (px < x + r && py >= y + h - r) {
    final dx = px - (x + r);
    final dy = py - (y + h - r);
    return dx * dx + dy * dy <= r * r;
  }
  // Bottom-right corner
  if (px >= x + w - r && py >= y + h - r) {
    final dx = px - (x + w - r);
    final dy = py - (y + h - r);
    return dx * dx + dy * dy <= r * r;
  }
  return true;
}

void _fillGradientRect(img.Image image, int x, int y, int w, int h, int r) {
  for (var py = y; py < y + h; py++) {
    for (var px = x; px < x + w; px++) {
      if (!_isInRoundedRect(px, py, x, y, w, h, r)) continue;
      // Gradient based on distance from top-left to bottom-right
      final t = ((px - x) / w * 0.3 + (py - y) / h * 0.7).clamp(0.0, 1.0);
      int cr, cg, cb;
      if (t < 0.45) {
        final lt = t / 0.45;
        cr = _lerp(goldSoft.r, gold.r, lt);
        cg = _lerp(goldSoft.g, gold.g, lt);
        cb = _lerp(goldSoft.b, gold.b, lt);
      } else {
        final lt = (t - 0.45) / 0.55;
        cr = _lerp(gold.r, goldDeep.r, lt);
        cg = _lerp(gold.g, goldDeep.g, lt);
        cb = _lerp(gold.b, goldDeep.b, lt);
      }
      _blendPixel(image, px, py, cr, cg, cb, 1.0);
    }
  }
}

void _drawTipDiamonds(img.Image image) {
  final beamW = size * 0.09;
  final vH = size * 0.46;
  final hW = size * 0.42;
  final crossTopY = half - vH / 2;
  final armCenterY = half - size * 0.02;
  final d = size * 0.022;

  _fillDiamond(image, half, crossTopY - d * 0.7, d, gold.r, gold.g, gold.b, 1.0);
  _fillDiamond(image, half, crossTopY + vH + d * 0.7, d, gold.r, gold.g, gold.b, 1.0);
  _fillDiamond(image, half - hW / 2 - d * 0.7, armCenterY, d, gold.r, gold.g, gold.b, 1.0);
  _fillDiamond(image, half + hW / 2 + d * 0.7, armCenterY, d, gold.r, gold.g, gold.b, 1.0);
}

void _drawCornerDots(img.Image image) {
  final beamW = size * 0.09;
  final armCenterY = half - size * 0.02;
  final crossLeft = half - beamW / 2;
  final crossRight = half + beamW / 2;
  final armTop = armCenterY - beamW / 2;
  final armBot = armCenterY + beamW / 2;
  final offset = size * 0.02;
  final dotR = (size * 0.006).round();

  _fillCircle(image, (crossLeft - offset).round(), (armTop - offset).round(), dotR,
      goldSoft.r, goldSoft.g, goldSoft.b, 0.8);
  _fillCircle(image, (crossRight + offset).round(), (armTop - offset).round(), dotR,
      goldSoft.r, goldSoft.g, goldSoft.b, 0.8);
  _fillCircle(image, (crossLeft - offset).round(), (armBot + offset).round(), dotR,
      goldSoft.r, goldSoft.g, goldSoft.b, 0.8);
  _fillCircle(image, (crossRight + offset).round(), (armBot + offset).round(), dotR,
      goldSoft.r, goldSoft.g, goldSoft.b, 0.8);
}
