/// A single prayer request that can be tracked over time.
class PrayerRequest {
  int? id;
  String title;
  String description;
  String category; // e.g. personal, family, church, nation
  String createdAt; // ISO 8601
  String? answeredAt; // ISO 8601, null if still pending
  String answerNote; // what happened when answered
  bool isAnswered;

  PrayerRequest({
    this.id,
    required this.title,
    this.description = '',
    this.category = 'personal',
    required this.createdAt,
    this.answeredAt,
    this.answerNote = '',
    this.isAnswered = false,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'description': description,
        'category': category,
        'createdAt': createdAt,
        'answeredAt': answeredAt ?? '',
        'answerNote': answerNote,
        'isAnswered': isAnswered ? 1 : 0,
      };

  factory PrayerRequest.fromMap(Map<String, dynamic> m) => PrayerRequest(
        id: m['id'] as int?,
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        category: m['category'] as String? ?? 'personal',
        createdAt: m['createdAt'] as String? ?? '',
        answeredAt: (m['answeredAt'] as String?)?.isEmpty ?? true
            ? null
            : m['answeredAt'] as String,
        answerNote: m['answerNote'] as String? ?? '',
        isAnswered: (m['isAnswered'] as int?) == 1,
      );
}
