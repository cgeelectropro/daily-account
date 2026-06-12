/// A saved/archived weekly report with send history.
class SavedReport {
  final int? id;
  final String weekStart; // 'yyyy-MM-dd' of Monday
  final String weekEnd;   // 'yyyy-MM-dd' of Sunday
  final String fullReport;
  final String compactReport;
  final String generatedAt; // ISO-8601
  final String sentVia;     // 'email', 'whatsapp', 'share', or '' if not sent
  final String sentAt;      // ISO-8601 or ''

  SavedReport({
    this.id,
    required this.weekStart,
    required this.weekEnd,
    required this.fullReport,
    required this.compactReport,
    required this.generatedAt,
    this.sentVia = '',
    this.sentAt = '',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'weekStart': weekStart,
        'weekEnd': weekEnd,
        'fullReport': fullReport,
        'compactReport': compactReport,
        'generatedAt': generatedAt,
        'sentVia': sentVia,
        'sentAt': sentAt,
      };

  factory SavedReport.fromMap(Map<String, dynamic> m) => SavedReport(
        id: m['id'] as int?,
        weekStart: m['weekStart'] as String? ?? '',
        weekEnd: m['weekEnd'] as String? ?? '',
        fullReport: m['fullReport'] as String? ?? '',
        compactReport: m['compactReport'] as String? ?? '',
        generatedAt: m['generatedAt'] as String? ?? '',
        sentVia: m['sentVia'] as String? ?? '',
        sentAt: m['sentAt'] as String? ?? '',
      );
}
