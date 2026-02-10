import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/colors.dart';

class QuizScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;

  const QuizScreen({super.key, required this.quizId, required this.quizTitle});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String?> _selectedAnswers = {};
  final Map<String, String> _correctAnswers = {};

  bool _submitted = false;
  int _score = 0;

  String _norm(String s) => s.trim().toLowerCase();

  void _submitQuiz(List<QueryDocumentSnapshot> questions) async {
    int score = 0;
    _correctAnswers.clear();

    for (var q in questions) {
      final data = q.data() as Map<String, dynamic>;
      final questionId = q.id;
      final options = List<String>.from(
        (data['options'] is List)
            ? data['options']
            : (data['options'].toString().split(',').map((e) => e.trim())),
      );

      final rawAnswer = data['answer'];
      String correctText = '';

      if (rawAnswer is int && rawAnswer >= 0 && rawAnswer < options.length) {
        correctText = options[rawAnswer];
      } else {
        correctText = rawAnswer.toString();
      }

      _correctAnswers[questionId] = correctText;

      final selected = _selectedAnswers[questionId];
      if (selected != null && _norm(selected) == _norm(correctText)) {
        score++;
      }
    }

    setState(() {
      _submitted = true;
      _score = score;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Derive subjects from parent quiz for richer analytics
      List<String> subjects = <String>[];
      try {
        final quizDoc = await _firestore
            .collection('quizzes')
            .doc(widget.quizId)
            .get();
        final data = quizDoc.data();
        final raw = data?['subjects'];
        subjects = raw is List
            ? raw
                  .whereType<String>()
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList()
            : raw is String
            ? <String>[raw.trim()]
            : <String>[];
      } catch (_) {}
      await FirebaseFirestore.instance.collection('quizResults').add({
        'userId': user.uid,
        'quizId': widget.quizId,
        'quizTitle': widget.quizTitle,
        'score': score,
        'totalQuestions': questions.length,
        'subjects': subjects,
        'mode': 'standard',
        'submittedAt': Timestamp.now(),
      });
    }
  }

  Color _optionColor(String questionId, String option) {
    if (!_submitted) return Colors.white;
    final correct = _correctAnswers[questionId];
    final selected = _selectedAnswers[questionId];
    if (_norm(option) == _norm(correct ?? '')) return Colors.green.shade50;
    if (_norm(option) == _norm(selected ?? '') &&
        _norm(option) != _norm(correct ?? '')) {
      return Colors.red.shade50;
    }
    return Colors.white;
  }

  Icon? _optionIcon(String questionId, String option) {
    if (!_submitted) return null;
    final correct = _correctAnswers[questionId];
    final selected = _selectedAnswers[questionId];
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
        title: Text(
          widget.quizTitle,
          style: const TextStyle(
            fontFamily: 'SummaryNotes',
            fontSize: 26,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: kTropicalGreen,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('quizzes')
            .doc(widget.quizId)
            .collection('questions')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No questions available yet.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            );
          }

          final questions = snapshot.data!.docs;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...questions.map((q) {
                  final data = q.data() as Map<String, dynamic>;
                  final questionId = q.id;
                  final questionText = data['question']?.toString() ?? '';
                  final rawOptions = data['options'];

                  List<String> options;
                  if (rawOptions is List) {
                    options = List<String>.from(
                      rawOptions.map((e) => e.toString()),
                    );
                  } else if (rawOptions is String) {
                    options = rawOptions
                        .split(',')
                        .map((s) => s.trim())
                        .toList();
                  } else {
                    options = [];
                  }

                  final selected = _selectedAnswers[questionId];

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
                            questionText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                              color: kTropicalGreen,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...options.map((option) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: _optionColor(questionId, option),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              child: RadioListTile<String>(
                                title: Text(
                                  option,
                                  style: const TextStyle(fontFamily: 'Poppins'),
                                ),
                                value: option,
                                groupValue: selected,
                                activeColor: kTropicalGreen,
                                secondary: _optionIcon(questionId, option),
                                onChanged: _submitted
                                    ? null
                                    : (val) {
                                        setState(() {
                                          _selectedAnswers[questionId] = val;
                                        });
                                      },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 16),

                if (!_submitted)
                  ElevatedButton(
                    onPressed: () => _submitQuiz(questions),
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
                        'Score: $_score / ${questions.length}',
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
                            _selectedAnswers.clear();
                            _correctAnswers.clear();
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
                          'Retry Quiz',
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Simple add question flow via dialog for now
          await _showAddQuestionDialog();
        },
        label: const Text(
          'Add Question',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        icon: const Icon(Icons.add),
        backgroundColor: kTropicalGreen,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _showAddQuestionDialog() async {
    final questionController = TextEditingController();
    final optionControllers = List.generate(4, (_) => TextEditingController());
    int correctIndex = 0;
    String difficulty = 'medium';
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'Add Question',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: questionController,
                    decoration: const InputDecoration(labelText: 'Question'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter question' : null,
                  ),
                  const SizedBox(height: 12),
                  for (int i = 0; i < optionControllers.length; i++) ...[
                    TextFormField(
                      controller: optionControllers[i],
                      decoration: InputDecoration(labelText: 'Option ${i + 1}'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter option ${i + 1}'
                          : null,
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: correctIndex,
                    items: List.generate(
                      optionControllers.length,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text('Correct Option: ${i + 1}'),
                      ),
                    ),
                    onChanged: (v) => correctIndex = v ?? 0,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: difficulty,
                    decoration: const InputDecoration(labelText: 'Difficulty'),
                    items: const [
                      DropdownMenuItem(value: 'easy', child: Text('Easy')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'hard', child: Text('Hard')),
                    ],
                    onChanged: (v) => difficulty = v ?? 'medium',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (saving) return; // prevent double taps
                if (!formKey.currentState!.validate()) return;
                final questionText = questionController.text.trim();
                final options = optionControllers
                    .map((c) => c.text.trim())
                    .toList();

                // Additional validation: all distinct & non-empty
                final normalized = options.map((o) => o.toLowerCase()).toList();
                final distinctCount = normalized.toSet().length;
                if (options.any((o) => o.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All options must be non-empty.'),
                    ),
                  );
                  return;
                }
                if (distinctCount != options.length) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Options must be distinct.')),
                  );
                  return;
                }

                // Duplicate question check (case-insensitive)
                try {
                  saving = true;
                  final existingSnap = await _firestore
                      .collection('quizzes')
                      .doc(widget.quizId)
                      .collection('questions')
                      .get();
                  final exists = existingSnap.docs.any((d) {
                    final data = d.data();
                    final q =
                        data['question']?.toString().trim().toLowerCase() ?? '';
                    return q == questionText.toLowerCase();
                  });
                  if (exists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'A question with this text already exists.',
                        ),
                      ),
                    );
                    saving = false;
                    return;
                  }

                  // Fetch parent quiz meta for subjects to denormalize per question
                  List<String> subjects = <String>[];
                  try {
                    final quizDoc = await _firestore
                        .collection('quizzes')
                        .doc(widget.quizId)
                        .get();
                    final data = quizDoc.data();
                    final raw = data?['subjects'];
                    subjects = raw is List
                        ? raw
                              .whereType<String>()
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList()
                        : raw is String
                        ? <String>[raw.trim()]
                        : <String>[];
                  } catch (_) {}

                  await _firestore
                      .collection('quizzes')
                      .doc(widget.quizId)
                      .collection('questions')
                      .add({
                        'question': questionText,
                        'options': options,
                        'answer':
                            correctIndex, // store index referencing options list
                        'difficulty': difficulty,
                        'subjects': subjects,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                  if (mounted) Navigator.pop(ctx);
                } catch (e) {
                  saving = false;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add question: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    for (final c in optionControllers) {
      c.dispose();
    }
    questionController.dispose();
  }
}
