class MeetingModel {
  final String id;
  final String title;
  final String description;
  final String scheduledDate;
  final String location;

  /// The uid that created the meeting. firestore.rules requires this on
  /// create (`request.resource.data.createdBy == request.auth.uid`) and gates
  /// update and delete on it, so a meeting written without one is rejected
  /// outright and one written by an older build can only be touched by an
  /// admin. The web has always sent it; see src/pages/Meetings.tsx.
  final String createdBy;
  final String createdByName;

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
    this.createdBy = '',
    this.createdByName = '',
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
      createdBy: data['createdBy'] ?? '',
      createdByName: data['createdByName'] ?? '',
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
      'createdBy': createdBy,
      'createdByName': createdByName,
      // createdAt/updatedAt handled by the service via serverTimestamp().
    };
  }

  /// Whether [uid] may edit or delete this meeting, mirroring the rule:
  /// the creator, or an admin. Meetings written before createdBy was sent
  /// have an empty one and stay admin-only, which is what the rule does too.
  bool canBeEditedBy(String uid, {required bool isAdmin}) =>
      isAdmin || (createdBy.isNotEmpty && createdBy == uid);

  int get goingCount =>
      rsvps.values.where((v) => v == 'going').length;
}
