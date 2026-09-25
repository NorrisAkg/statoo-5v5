class TeamInfo {
  const TeamInfo({
    required this.id,
    required this.name,
    this.format = '5v5',
    this.location,
    this.createdAt,
  });

  factory TeamInfo.fromMap(Map<String, dynamic> map) {
    return TeamInfo(
      id: map['id'] as String,
      name: map['name'] as String,
      format: (map['format'] as String?) ?? '5v5',
      location: map['location'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  final String id;
  final String name;
  final String format;
  final String? location;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'format': format,
      'location': location,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
