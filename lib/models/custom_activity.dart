/// Field types available for custom activities.
enum CustomFieldType { text, number, duration, yesNo, notes }

/// A single configurable field within a custom activity.
class CustomField {
  String label;
  CustomFieldType type;

  CustomField({required this.label, this.type = CustomFieldType.text});

  Map<String, dynamic> toMap() => {
        'label': label,
        'type': type.name,
      };

  factory CustomField.fromMap(Map<String, dynamic> m) => CustomField(
        label: m['label'] as String,
        type: CustomFieldType.values.byName(
          m['type'] as String? ?? 'text',
        ),
      );
}

/// A user-defined spiritual activity for stopwatch tracking.
class CustomActivity {
  final String id;
  String name;
  String icon;
  List<CustomField> fields;
  bool countsForCompleteness;

  CustomActivity({
    required this.id,
    required this.name,
    this.icon = '\u2728',
    List<CustomField>? fields,
    this.countsForCompleteness = true,
  }) : fields = fields ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'fields': fields.map((f) => f.toMap()).toList(),
        'countsForCompleteness': countsForCompleteness,
      };

  factory CustomActivity.fromMap(Map<String, dynamic> m) {
    // Migrate old fieldLabels format to new fields format
    List<CustomField> fields;
    if (m.containsKey('fields') && m['fields'] is List) {
      fields = (m['fields'] as List)
          .map((f) => f is Map<String, dynamic>
              ? CustomField.fromMap(f)
              : CustomField(label: f.toString()))
          .toList();
    } else if (m.containsKey('fieldLabels') && m['fieldLabels'] is List) {
      fields = (m['fieldLabels'] as List)
          .cast<String>()
          .map((l) => CustomField(label: l))
          .toList();
    } else {
      fields = [];
    }

    return CustomActivity(
      id: m['id'] as String,
      name: m['name'] as String,
      icon: m['icon'] as String? ?? '\u2728',
      fields: fields,
      countsForCompleteness: m['countsForCompleteness'] as bool? ?? true,
    );
  }
}
