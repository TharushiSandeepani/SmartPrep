import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdaptiveSettings {
  AdaptiveSettings({required this.questionCount, required this.aggressiveness});

  final int questionCount; // number of questions in personalized quiz
  final String aggressiveness; // conservative | balanced | challenging

  Map<String, dynamic> toMap() => {
    'questionCount': questionCount,
    'aggressiveness': aggressiveness,
  };

  static AdaptiveSettings fromMap(Map<String, dynamic> data) {
    final qcRaw = data['questionCount'];
    int qc = (qcRaw is int && qcRaw > 0) ? qcRaw : 10;
    final aggRaw = data['aggressiveness'];
    final agg = (aggRaw is String && aggRaw.trim().isNotEmpty)
        ? aggRaw.trim()
        : 'balanced';
    if (!['conservative', 'balanced', 'challenging'].contains(agg)) {
      return AdaptiveSettings(questionCount: qc, aggressiveness: 'balanced');
    }
    return AdaptiveSettings(questionCount: qc, aggressiveness: agg);
  }
}

class AdaptiveSettingsService {
  AdaptiveSettingsService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<AdaptiveSettings> load() async {
    final user = _auth.currentUser;
    if (user == null) {
      return AdaptiveSettings(questionCount: 10, aggressiveness: 'balanced');
    }
    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('adaptiveQuiz')
          .get();
      if (!doc.exists) {
        return AdaptiveSettings(questionCount: 10, aggressiveness: 'balanced');
      }
      final data = doc.data();
      if (data == null) {
        return AdaptiveSettings(questionCount: 10, aggressiveness: 'balanced');
      }
      return AdaptiveSettings.fromMap(data);
    } catch (_) {
      return AdaptiveSettings(questionCount: 10, aggressiveness: 'balanced');
    }
  }

  Future<void> save(AdaptiveSettings settings) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('adaptiveQuiz')
        .set(settings.toMap(), SetOptions(merge: true));
  }
}
