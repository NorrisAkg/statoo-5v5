class TeamInfo {
  const TeamInfo({
    required this.id,
    required this.name,
    this.shortName = '',
    this.format = '5v5',
    this.location,
    this.createdAt,
  });

  factory TeamInfo.fromMap(Map<String, dynamic> map) {
    return TeamInfo(
      id: map['id'] as String,
      name: map['name'] as String,
      shortName: (map['short_name'] as String? ?? '').trim(),
      format: (map['format'] as String?) ?? '5v5',
      location: map['location'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  final String id;
  final String name;
  final String shortName;
  String get displayName => shortName.trim().isEmpty ? name : shortName.trim();
  final String format;
  final String? location;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'short_name': shortName.trim(),
      'format': format,
      'location': location,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
