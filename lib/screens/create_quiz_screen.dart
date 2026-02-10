import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import 'manage_subjects_screen.dart';

class CreateQuizScreen extends StatefulWidget {
  const CreateQuizScreen({super.key});

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _manualSubjectController = TextEditingController();

  late final Future<List<String>> _subjectsFuture;
  final List<String> _selectedSubjects = <String>[];

  @override
  void initState() {
    super.initState();
    _subjectsFuture = _loadSubjects();
  }

  Future<List<String>> _loadSubjects() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('subjects')
          .get();
      final subjects = snap.docs
          .map((d) {
            final data = d.data();
            final name = (data['name'] is String)
                ? (data['name'] as String).trim()
                : '';
            return name.isNotEmpty ? name : d.id;
          })
          .where((s) => s.trim().isNotEmpty)
          .toList();
      subjects.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return subjects;
    } catch (e) {
      // If the collection doesn't exist or any error occurs, fallback to empty list
      return <String>[];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _manualSubjectController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final manualSubject = _manualSubjectController.text.trim();
    final List<String> subjectsToSave = _selectedSubjects.isNotEmpty
        ? _selectedSubjects
        : (manualSubject.isNotEmpty ? <String>[manualSubject] : <String>[]);

    if (subjectsToSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter at least one subject.'),
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('quizzes').add({
        'title': title,
        'subjects': subjectsToSave,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create quiz: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightMint,
      appBar: AppBar(
        title: const Text(
          'Create Quiz',
          style: TextStyle(
            fontFamily: 'SummaryNotes',
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        backgroundColor: kTropicalGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Manage subjects',
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageSubjectsScreen(),
                ),
              );
              // Refresh subjects after returning
              if (mounted) {
                setState(() {
                  _subjectsFuture = _loadSubjects();
                  _selectedSubjects.clear();
                });
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Quiz title',
                  labelStyle: TextStyle(fontFamily: 'Poppins'),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter a title'
                    : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'Subjects',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<String>>(
                future: _subjectsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final subjects = snapshot.data ?? <String>[];

                  if (subjects.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: subjects.map((s) {
                            final selected = _selectedSubjects.contains(s);
                            return FilterChip(
                              label: Text(
                                s,
                                style: const TextStyle(fontFamily: 'Poppins'),
                              ),
                              selected: selected,
                              onSelected: (val) {
                                setState(() {
                                  if (val && !selected) {
                                    _selectedSubjects.add(s);
                                  } else if (!val && selected) {
                                    _selectedSubjects.remove(s);
                                  }
                                });
                              },
                              selectedColor: kTropicalGreen.withOpacity(0.15),
                              checkmarkColor: kTropicalGreen,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _manualSubjectController,
                                decoration: const InputDecoration(
                                  hintText: 'Add custom subject',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                final s = _manualSubjectController.text.trim();
                                if (s.isEmpty) return;
                                if (!_selectedSubjects.contains(s)) {
                                  setState(() {
                                    _selectedSubjects.add(s);
                                    _manualSubjectController.clear();
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kTropicalGreen,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text(
                                'Add',
                                style: TextStyle(fontFamily: 'Poppins'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_selectedSubjects.isEmpty)
                          const Text(
                            'Select one or more subjects above, or add a custom subject.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.black54,
                            ),
                          ),
                      ],
                    );
                  }

                  // Fallback: allow manual subject input
                  return TextFormField(
                    controller: _manualSubjectController,
                    decoration: const InputDecoration(
                      labelText: 'Enter subject',
                      labelStyle: TextStyle(fontFamily: 'Poppins'),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter a subject'
                        : null,
                  );
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTropicalGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _save,
                  label: const Text(
                    'Create',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
