import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class AdaptiveQuestion {
  AdaptiveQuestion({
    required this.ref,
    required this.question,
    required this.options,
    required this.answer,
    required this.subjects,
    required this.difficulty,
  });

  final DocumentReference<Map<String, dynamic>> ref;
  final String question;
  final List<String> options;
  // May be an index (int) or text (String)
  final dynamic answer;
  final List<String> subjects;
  final String difficulty;
}

class AdaptiveQuizService {
  AdaptiveQuizService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const List<String> _difficulties = ['easy', 'medium', 'hard'];

  Future<Map<String, double>> _computeSubjectAverages(String userId) async {
    final Map<String, double> totals = {};
    final Map<String, int> counts = {};

    // Load recent results first; if index missing, fallback unsorted
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _firestore
          .collection('quizResults')
          .where('userId', isEqualTo: userId)
          .orderBy('submittedAt', descending: true)
          .limit(200)
          .get();
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        snap = await _firestore
            .collection('quizResults')
            .where('userId', isEqualTo: userId)
            .limit(200)
            .get();
      } else {
        rethrow;
      }
    }

    for (final doc in snap.docs) {
      final data = doc.data();
      final score = (data['scorePercent'] as num?)?.toDouble();
      // Some results may not store scorePercent; derive from score/totalQuestions if present
      double? percent = score;
      final rawScore = (data['score'] as num?)?.toDouble();
      final totalQ = (data['totalQuestions'] as num?)?.toDouble();
      if (percent == null && rawScore != null && totalQ != null && totalQ > 0) {
        percent = (rawScore / totalQ) * 100.0;
      }
      if (percent == null) continue;

      // Prefer per-result subjects (for personalized quizzes). Fallback to empty list.
      final subsRaw = data['subjects'];
      final List<String> subjects = subsRaw is List
          ? subsRaw
                .whereType<String>()
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList()
          : <String>[];

      if (subjects.isEmpty) continue;
      for (final s in subjects) {
        totals[s] = (totals[s] ?? 0) + percent;
        counts[s] = (counts[s] ?? 0) + 1;
      }
    }

    final Map<String, double> averages = {};
    totals.forEach((s, t) {
      final c = counts[s] ?? 1;
      averages[s] = (t / c).clamp(0, 100);
    });
    return averages;
  }

  String _chooseDifficulty(
    double? avg,
    Random rng, {
    String aggressiveness = 'balanced',
  }) {
    if (avg == null) {
      // No history: bias to medium
      final roll = rng.nextDouble();
      if (aggressiveness == 'conservative') {
        if (roll < 0.5) return 'easy';
        if (roll < 0.9) return 'medium';
        return 'hard';
      } else if (aggressiveness == 'challenging') {
        if (roll < 0.1) return 'easy';
        if (roll < 0.6) return 'medium';
        return 'hard';
      } else {
        if (roll < 0.2) return 'easy';
        if (roll < 0.8) return 'medium';
        return 'hard';
      }
    }
    if (avg < 60) {
      final roll = rng.nextDouble();
      if (aggressiveness == 'conservative') {
        return roll < 0.85 ? 'easy' : 'medium';
      } else if (aggressiveness == 'challenging') {
        return roll < 0.5 ? 'easy' : 'medium';
      } else {
        return roll < 0.7 ? 'easy' : 'medium';
      }
    } else if (avg < 80) {
      final roll = rng.nextDouble();
      if (aggressiveness == 'conservative') {
        if (roll < 0.35) return 'easy';
        if (roll < 0.9) return 'medium';
        return 'hard';
      } else if (aggressiveness == 'challenging') {
        if (roll < 0.1) return 'easy';
        if (roll < 0.6) return 'medium';
        return 'hard';
      } else {
        if (roll < 0.2) return 'easy';
        if (roll < 0.8) return 'medium';
        return 'hard';
      }
    } else {
      final roll = rng.nextDouble();
      if (aggressiveness == 'conservative') {
        return roll < 0.85 ? 'medium' : 'hard';
      } else if (aggressiveness == 'challenging') {
        return roll < 0.4 ? 'medium' : 'hard';
      } else {
        return roll < 0.7 ? 'medium' : 'hard';
      }
    }
  }

  List<String> _weightedSubjects(Map<String, double> averages, int count) {
    // Higher weight for lower averages
    final entries = averages.entries.toList();
    if (entries.isEmpty) return <String>[];
    // Build a weighted list where weight ~ (100 - avg) + 10 baseline
    final List<String> bag = [];
    for (final e in entries) {
      final w = max(1, (110 - e.value).round());
      for (int i = 0; i < w; i++) {
        bag.add(e.key);
      }
    }
    final rng = Random();
    final List<String> picks = [];
    for (int i = 0; i < count; i++) {
      picks.add(bag[rng.nextInt(bag.length)]);
    }
    return picks;
  }

  Future<List<String>> _fallbackSubjects() async {
    // Try subjects collection first
    try {
      final snap = await _firestore.collection('subjects').limit(50).get();
      final list = snap.docs
          .map((d) {
            final name = (d.data()['name'] as String?)?.trim();
            return name?.isNotEmpty == true ? name! : d.id;
          })
          .where((s) => s.trim().isNotEmpty)
          .toList();
      if (list.isNotEmpty) return list;
    } catch (_) {}
    // Fallback: scan a few quizzes for their subjects
    try {
      final snap = await _firestore.collection('quizzes').limit(50).get();
      final Set<String> all = {};
      for (final d in snap.docs) {
        final raw = d.data()['subjects'];
        final subs = raw is List
            ? raw
                  .whereType<String>()
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
            : raw is String
            ? <String>[raw.trim()]
            : <String>[];
        all.addAll(subs);
      }
      return all.toList();
    } catch (_) {
      return <String>[];
    }
  }

  Future<List<AdaptiveQuestion>> generatePersonalizedQuestions({
    required String userId,
    int count = 10,
    String aggressiveness = 'balanced',
  }) async {
    final rng = Random();
    final averages = await _computeSubjectAverages(userId);
    List<String> subjectPlan;
    if (averages.isEmpty) {
      final all = await _fallbackSubjects();
      if (all.isEmpty) {
        // No subjects at all, return any questions
        final any = await _firestore
            .collectionGroup('questions')
            .limit(count)
            .get();
        return any.docs.map((d) {
          final data = d.data();
          final optsRaw = data['options'];
          final options = optsRaw is List
              ? optsRaw.whereType().map<String>((e) => e.toString()).toList()
              : (optsRaw is String
                    ? optsRaw.split(',').map((s) => s.trim()).toList()
                    : <String>[]);
          final subsRaw = data['subjects'];
          final subs = subsRaw is List
              ? subsRaw.whereType<String>().toList()
              : subsRaw is String
              ? <String>[subsRaw]
              : <String>[];
          final difficulty =
              (data['difficulty'] as String?)?.toLowerCase() ?? 'medium';
          return AdaptiveQuestion(
            ref: d.reference,
            question: (data['question']?.toString() ?? '').trim(),
            options: options,
            answer: data['answer'],
            subjects: subs,
            difficulty: _difficulties.contains(difficulty)
                ? difficulty
                : 'medium',
          );
        }).toList();
      }
      // Randomly sample subjects uniformly
      subjectPlan = List.generate(count, (_) => all[rng.nextInt(all.length)]);
    } else {
      subjectPlan = _weightedSubjects(averages, count);
    }

    // Cache candidate pools by subject+difficulty to avoid many calls
    final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> pool =
        {};
    final List<AdaptiveQuestion> picked = [];
    final Set<String> usedQuestionIds = {};

    for (final subject in subjectPlan) {
      final avg = averages[subject];
      final diff = _chooseDifficulty(avg, rng, aggressiveness: aggressiveness);
      Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> loadPool(
        String subj,
        String? difficulty,
      ) async {
        final key = '$subj|${difficulty ?? '*'}';
        if (pool.containsKey(key)) return pool[key]!;
        Query<Map<String, dynamic>> q = _firestore
            .collectionGroup('questions')
            .where('subjects', arrayContains: subj);
        if (difficulty != null) {
          try {
            q = q.where('difficulty', isEqualTo: difficulty);
          } catch (_) {}
        }
        try {
          final snap = await q.limit(25).get();
          pool[key] = snap.docs;
        } on FirebaseException catch (e) {
          // Fallback: drop difficulty filter if index missing
          if (difficulty != null && e.code == 'failed-precondition') {
            try {
              final snap = await _firestore
                  .collectionGroup('questions')
                  .where('subjects', arrayContains: subj)
                  .limit(25)
                  .get();
              pool[key] = snap.docs;
            } catch (_) {
              pool[key] = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            }
          } else {
            pool[key] = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          }
        }
        return pool[key]!;
      }

      List<QueryDocumentSnapshot<Map<String, dynamic>>> candidates =
          await loadPool(subject, diff);
      if (candidates.isEmpty) {
        candidates = await loadPool(subject, null);
      }
      if (candidates.isEmpty) continue;

      // pick random unused
      final available = candidates
          .where((d) => !usedQuestionIds.contains(d.id))
          .toList();
      if (available.isEmpty) continue;
      final choice = available[rng.nextInt(available.length)];
      usedQuestionIds.add(choice.id);

      final data = choice.data();
      final optsRaw = data['options'];
      final options = optsRaw is List
          ? optsRaw.whereType().map<String>((e) => e.toString()).toList()
          : (optsRaw is String
                ? optsRaw.split(',').map((s) => s.trim()).toList()
                : <String>[]);
      final subsRaw = data['subjects'];
      final subs = subsRaw is List
          ? subsRaw.whereType<String>().toList()
          : subsRaw is String
          ? <String>[subsRaw]
          : <String>[];
      final difficulty = (data['difficulty'] as String?)?.toLowerCase() ?? diff;

      picked.add(
        AdaptiveQuestion(
          ref: choice.reference,
          question: (data['question']?.toString() ?? '').trim(),
          options: options,
          answer: data['answer'],
          subjects: subs,
          difficulty: _difficulties.contains(difficulty)
              ? difficulty
              : 'medium',
        ),
      );
      if (picked.length >= count) break;
    }

    // If still short, pad with any remaining across pool values
    if (picked.length < count) {
      try {
        final extra = await _firestore
            .collectionGroup('questions')
            .limit(count * 2)
            .get();
        for (final d in extra.docs) {
          if (usedQuestionIds.contains(d.id)) continue;
          final data = d.data();
          final subsRaw = data['subjects'];
          final subs = subsRaw is List
              ? subsRaw.whereType<String>().toList()
              : subsRaw is String
              ? <String>[subsRaw]
              : <String>[];
          final optsRaw = data['options'];
          final options = optsRaw is List
              ? optsRaw.whereType().map<String>((e) => e.toString()).toList()
              : (optsRaw is String
                    ? optsRaw.split(',').map((s) => s.trim()).toList()
                    : <String>[]);
          final difficulty =
              (data['difficulty'] as String?)?.toLowerCase() ?? 'medium';
          picked.add(
            AdaptiveQuestion(
              ref: d.reference,
              question: (data['question']?.toString() ?? '').trim(),
              options: options,
              answer: data['answer'],
              subjects: subs,
              difficulty: _difficulties.contains(difficulty)
                  ? difficulty
                  : 'medium',
            ),
          );
          if (picked.length >= count) break;
        }
      } catch (_) {}
    }

    return picked;
  }
}
