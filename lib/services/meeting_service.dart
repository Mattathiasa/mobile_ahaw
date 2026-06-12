import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meeting_model.dart';

class MeetingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<MeetingModel>> getMeetingsStream() {
    return _db
        .collection('meetings')
        .orderBy('scheduledDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MeetingModel.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  Future<void> createMeeting(MeetingModel meeting) async {
    await _db.collection('meetings').add({
      ...meeting.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMeeting(String id, Map<String, dynamic> data) async {
    await _db.collection('meetings').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMeeting(String id) async {
    await _db.collection('meetings').doc(id).delete();
  }
}
