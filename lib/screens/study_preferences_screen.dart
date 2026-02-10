import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/colors.dart';

class StudyPreferencesScreen extends StatefulWidget {
  const StudyPreferencesScreen({super.key});

  @override
  State<StudyPreferencesScreen> createState() => _StudyPreferencesScreenState();
}

class _StudyPreferencesScreenState extends State<StudyPreferencesScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _subjectsController = TextEditingController();
  final TextEditingController _examDateController = TextEditingController();

  bool _isSaving = false;
  DateTime? _selectedExamDate;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _subjectsController.dispose();
    _examDateController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore
        .collection('studyPreferences')
        .doc(user.uid)
        .get();
    if (!doc.exists) return;

    final data = doc.data();
    if (data == null) return;

    final hours = data['dailyHours'];
    if (hours != null) {
      _hoursController.text = hours.toString();
    }

    final subjects = data['subjects'];
    if (subjects is String) {
      _subjectsController.text = subjects;
    }

    final examDate = data['examDate'];
    if (examDate is String) {
      _examDateController.text = examDate;
      _selectedExamDate = DateTime.tryParse(examDate);
    }
  }

  Future<void> _pickExamDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExamDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: kTropicalGreen),
          textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Poppins'),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              textStyle: const TextStyle(fontFamily: 'Poppins'),
            ),
          ),
          dialogTheme: const DialogThemeData(
            titleTextStyle: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
            contentTextStyle: TextStyle(fontFamily: 'Poppins'),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedExamDate = picked;
        _examDateController.text = _formatDate(picked);
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _savePreferences() async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (_hoursController.text.isEmpty ||
        _subjectsController.text.isEmpty ||
        _examDateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _firestore.collection('studyPreferences').doc(user.uid).set({
        'dailyHours': int.tryParse(_hoursController.text.trim()) ?? 2,
        'subjects': _subjectsController.text.trim(),
        'examDate': _examDateController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved successfully!')),
      );

      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving preferences: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightMint,
      appBar: AppBar(
        backgroundColor: kTropicalGreen,
        foregroundColor: Colors.white,
        title: const Text(
          'Study Preferences',
          style: TextStyle(fontFamily: 'SummaryNotes', fontSize: 24),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.white,
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: kTropicalGreen,
                            child: Icon(
                              Icons.tune,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Customize Your Study Plan',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _PreferenceField(
                        label: 'Study hours per day',
                        controller: _hoursController,
                        hint: 'e.g. 3',
                        keyboardType: TextInputType.number,
                        icon: Icons.schedule,
                      ),
                      const SizedBox(height: 16),
                      _PreferenceField(
                        label: 'Subjects (comma-separated)',
                        controller: _subjectsController,
                        hint: 'Math, Physics, Chemistry',
                        icon: Icons.book_outlined,
                      ),
                      const SizedBox(height: 16),
                      _PreferenceField(
                        label: 'Exam date',
                        controller: _examDateController,
                        hint: 'Select date',
                        icon: Icons.event,
                        readOnly: true,
                        onTap: _pickExamDate,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _savePreferences,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kTropicalGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _isSaving ? 'Saving...' : 'Save Preferences',
                            style: const TextStyle(fontFamily: 'Poppins'),
                          ),
                        ),
                      ),
                    ],
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

class _PreferenceField extends StatelessWidget {
  const _PreferenceField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF4FBF8),
            prefixIcon: Icon(icon, color: kTropicalGreen),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kTropicalGreen, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}
