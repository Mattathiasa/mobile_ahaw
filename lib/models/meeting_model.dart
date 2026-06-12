class MeetingModel {
  final String id;
  final String title;
  final String description;
  final String scheduledDate;
  final dynamic createdAt;
  final dynamic updatedAt;

  MeetingModel({
    required this.id,
    required this.title,
    required this.description,
    required this.scheduledDate,
    this.createdAt,
    this.updatedAt,
  });

  factory MeetingModel.fromFirestore(String id, Map<String, dynamic> data) {
    return MeetingModel(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      scheduledDate: data['scheduledDate'] ?? '',
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'scheduledDate': scheduledDate,
      // createdAt and updatedAt should be handled by the service using FieldValue.serverTimestamp()
    };
  }
}
