/// A user-defined spiritual activity for stopwatch tracking.
class CustomActivity {
  final String id; // UUID-like, generated at creation
  String name;
  String icon; // emoji
  /// Optional list of field labels the user wants to fill before starting.
  List<String> fieldLabels;

  CustomActivity({
    required this.id,
    required this.name,
    this.icon = '\u2728', // sparkles default
    List<String>? fieldLabels,
  }) : fieldLabels = fieldLabels ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'fieldLabels': fieldLabels,
      };

  factory CustomActivity.fromMap(Map<String, dynamic> m) => CustomActivity(
        id: m['id'] as String,
        name: m['name'] as String,
        icon: m['icon'] as String? ?? '\u2728',
        fieldLabels: (m['fieldLabels'] as List?)?.cast<String>() ?? [],
      );
}
