/// Best-effort parse of duration strings like "45m", "1h 30m", "30 minutes", "1h15m".
int parseDurationMinutes(String s) {
  if (s.isEmpty || s == '✓') return 0;
  // Try "Xh Ym" or "XhYm"
  final hm = RegExp(r'(\d+)\s*h\s*(\d+)\s*m');
  final hmMatch = hm.firstMatch(s);
  if (hmMatch != null) {
    return int.parse(hmMatch.group(1)!) * 60 + int.parse(hmMatch.group(2)!);
  }
  // Try "Xh" only
  final hOnly = RegExp(r'(\d+)\s*h');
  final hMatch = hOnly.firstMatch(s);
  if (hMatch != null) return int.parse(hMatch.group(1)!) * 60;
  // Try "Xm" or "X minutes" or "X min"
  final mOnly = RegExp(r'(\d+)\s*m');
  final mMatch = mOnly.firstMatch(s);
  if (mMatch != null) return int.parse(mMatch.group(1)!);
  // Try "Xs" (seconds only, from timer)
  final sOnly = RegExp(r'^(\d+)\s*s$');
  final sMatch = sOnly.firstMatch(s);
  if (sMatch != null) return (int.parse(sMatch.group(1)!) / 60).ceil();
  // Try bare number (assume minutes)
  final n = int.tryParse(s.trim());
  if (n != null) return n;
  return 0;
}
