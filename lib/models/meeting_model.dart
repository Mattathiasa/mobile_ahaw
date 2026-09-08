class MeetingModel {
  final String id;
  final String title;
  final String description;
  final String scheduledDate;
  final String location;
  /// uid → 'going' | 'not_going'
  final Map<String, dynamic> rsvps;
  final dynamic createdAt;
  final dynamic updatedAt;

  MeetingModel({
    required this.id,
    required this.title,
    required this.description,
    required this.scheduledDate,
    this.location = '',
    this.rsvps = const {},
    this.createdAt,
    this.updatedAt,
  });

  factory MeetingModel.fromFirestore(String id, Map<String, dynamic> data) {
    return MeetingModel(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      scheduledDate: data['scheduledDate'] ?? '',
      location: data['location'] ?? '',
      rsvps: (data['rsvps'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'scheduledDate': scheduledDate,
      'location': location,
      // createdAt/updatedAt handled by the service via serverTimestamp().
    };
  }

  int get goingCount =>
      rsvps.values.where((v) => v == 'going').length;
}
