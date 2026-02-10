import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../services/adaptive_quiz_service.dart' as svc;
import '../services/adaptive_settings_service.dart';
import 'adaptive_settings_screen.dart';

class PersonalizedQuizScreen extends StatefulWidget {
  const PersonalizedQuizScreen({super.key, this.questionCount = 10});

  final int questionCount;

  @override
  State<PersonalizedQuizScreen> createState() => _PersonalizedQuizScreenState();
}

class _PersonalizedQuizScreenState extends State<PersonalizedQuizScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final svc.AdaptiveQuizService _service = svc.AdaptiveQuizService();
  final AdaptiveSettingsService _settingsService = AdaptiveSettingsService();

  bool _loading = true;
  String? _error;
  List<svc.AdaptiveQuestion> _questions = [];
  final Map<String, String?> _selected = {};
  final Map<String, String> _correctByQuestion = {};
  bool _submitted = false;
  int _score = 0;
  AdaptiveSettings? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Not signed in';
      });
      return;
    }
    try {
      // Load user settings first
      final s = await _settingsService.load();
      _settings = s;
      final qs = await _service.generatePersonalizedQuestions(
        userId: user.uid,
        count: s.questionCount,
        aggressiveness: s.aggressiveness,
      );
      setState(() {
        _questions = qs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to generate quiz: $e';
        _loading = false;
      });
    }
  }

  String _norm(String s) => s.trim().toLowerCase();

  void _submit() async {
    int score = 0;
    _correctByQuestion.clear();
    for (final q in _questions) {
      String correctText = '';
      final ans = q.answer;
      if (ans is int && ans >= 0 && ans < q.options.length) {
        correctText = q.options[ans];
      } else {
        correctText = ans.toString();
      }
      _correctByQuestion[q.ref.id] = correctText;
      final selected = _selected[q.ref.id];
      if (selected != null && _norm(selected) == _norm(correctText)) {
        score++;
      }
    }
    setState(() {
      _score = score;
      _submitted = true;
    });

    final user = _auth.currentUser;
    if (user == null) return;

    // Aggregate subjects across selected questions
    final Set<String> subjects = {};
    for (final q in _questions) {
      subjects.addAll(q.subjects);
    }

    try {
      await _firestore.collection('quizResults').add({
        'userId': user.uid,
        'quizId': 'adaptive-${DateTime.now().millisecondsSinceEpoch}',
        'quizTitle': 'Personalized Quiz',
        'mode': 'adaptive',
        'score': score,
        'totalQuestions': _questions.length,
        'subjects': subjects.toList(),
        'submittedAt': Timestamp.now(),
      });
    } catch (_) {}
  }

  Color _optionColor(String qid, String option) {
    if (!_submitted) return Colors.white;
    final correct = _correctByQuestion[qid];
    final selected = _selected[qid];
    if (_norm(option) == _norm(correct ?? '')) return Colors.green.shade50;
    if (_norm(option) == _norm(selected ?? '') &&
        _norm(option) != _norm(correct ?? '')) {
      return Colors.red.shade50;
    }
    return Colors.white;
  }

  Icon? _optionIcon(String qid, String option) {
    if (!_submitted) return null;
    final correct = _correctByQuestion[qid];
    final selected = _selected[qid];
    if (_norm(option) == _norm(correct ?? '')) {
      return const Icon(Icons.check_circle, color: Colors.green);
    } else if (_norm(option) == _norm(selected ?? '')) {
      return const Icon(Icons.cancel, color: Colors.red);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightMint,
      appBar: AppBar(
        title: const Text(
          'Personalized Quiz',
          style: TextStyle(
            fontFamily: 'SummaryNotes',
            fontSize: 26,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: kTropicalGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final changed = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdaptiveSettingsScreen(),
                ),
              );
              if (changed == true) {
                setState(() {
                  _loading = true;
                  _questions = [];
                  _selected.clear();
                  _correctByQuestion.clear();
                  _submitted = false;
                  _score = 0;
                });
                await _load();
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _error!,
                  style: const TextStyle(fontFamily: 'Poppins'),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : (_questions.isEmpty)
          ? const Center(
              child: Text(
                'No questions available for a personalized quiz yet.',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.grey),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_settings != null)
                    Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.tune, color: kTropicalGreen),
                        title: const Text(
                          'Quiz settings',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${_settings!.questionCount} questions • ${_settings!.aggressiveness[0].toUpperCase()}${_settings!.aggressiveness.substring(1)} bias',
                          style: const TextStyle(fontFamily: 'Poppins'),
                        ),
                      ),
                    ),
                  ..._questions.map((q) {
                    final qid = q.ref.id;
                    final selected = _selected[qid];
                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              q.question,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                                color: kTropicalGreen,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: q.subjects
                                  .map(
                                    (s) => Chip(
                                      backgroundColor: kTropicalGreen
                                          .withOpacity(0.1),
                                      label: Text(
                                        s,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          color: kTropicalGreen,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 10),
                            ...q.options.map(
                              (option) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: _optionColor(qid, option),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.3),
                                  ),
                                ),
                                child: RadioListTile<String>(
                                  title: Text(
                                    option,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  value: option,
                                  groupValue: selected,
                                  activeColor: kTropicalGreen,
                                  secondary: _optionIcon(qid, option),
                                  onChanged: _submitted
                                      ? null
                                      : (val) => setState(
                                          () => _selected[qid] = val,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  if (!_submitted)
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTropicalGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Submit Quiz',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        Text(
                          'Score: $_score / ${_questions.length}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kTropicalGreen,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _submitted = false;
                              _score = 0;
                              _selected.clear();
                              _correctByQuestion.clear();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kTropicalGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Retry',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}
