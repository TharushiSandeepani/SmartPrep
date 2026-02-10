import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/colors.dart';
import 'study_preferences_screen.dart';

class StudyPlannerScreen extends StatefulWidget {
  const StudyPlannerScreen({super.key});

  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  DateTime? _selectedDate;
  final user = FirebaseAuth.instance.currentUser;
  late final TabController _tabController;
  bool _isGeneratingSchedule = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // Add a task to Firestore
  Future<void> _addTask() async {
    if (_titleController.text.trim().isEmpty) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('tasks')
        .add({
          'title': _titleController.text.trim(),
          'desc': _descController.text.trim(),
          'date': _selectedDate?.toIso8601String(),
          'completed': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

    _titleController.clear();
    _descController.clear();
    _dateController.clear();
    _selectedDate = null;
  }

  // Toggle task completion
  Future<void> _toggleTask(String id, bool completed) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('tasks')
        .doc(id)
        .update({'completed': completed});
  }

  // Delete task
  Future<void> _deleteTask(String id) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('tasks')
        .doc(id)
        .delete();
  }

  // Date picker (updates text field after selection)
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Poppins'),
          colorScheme: const ColorScheme.light(primary: kTropicalGreen),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  // Add Task Dialog
  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add New Task',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: kTropicalGreen,
            fontFamily: 'Poppins',
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                style: const TextStyle(fontFamily: 'Poppins'),
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(fontFamily: 'Poppins'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descController,
                style: const TextStyle(fontFamily: 'Poppins'),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(fontFamily: 'Poppins'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _dateController,
                readOnly: true,
                onTap: _pickDate,
                style: const TextStyle(fontFamily: 'Poppins'),
                decoration: InputDecoration(
                  labelText: 'Due Date',
                  hintText: 'Select a due date',
                  labelStyle: const TextStyle(fontFamily: 'Poppins'),
                  hintStyle: const TextStyle(fontFamily: 'Poppins'),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.calendar_today,
                      color: kTropicalGreen,
                    ),
                    onPressed: _pickDate,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black, fontFamily: 'Poppins'),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _addTask();
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kTropicalGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Add', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  double _calculateProgress(List<QueryDocumentSnapshot> tasks) {
    if (tasks.isEmpty) return 0;
    final completed = tasks
        .where((t) => (t['completed'] ?? false) == true)
        .length;
    return completed / tasks.length;
  }

  List<Map<String, dynamic>> _sessionListFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final rawSessions = doc.data()['sessions'] as List<dynamic>? ?? [];
    return rawSessions
        .map(
          (session) => session is Map<String, dynamic>
              ? Map<String, dynamic>.from(session)
              : <String, dynamic>{},
        )
        .toList();
  }

  double _calculateScheduleProgress(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> days,
  ) {
    int totalSessions = 0;
    int completedSessions = 0;

    for (final doc in days) {
      final sessions = _sessionListFromDoc(doc);
      totalSessions += sessions.length;
      completedSessions += sessions
          .where((session) => session['completed'] == true)
          .length;
    }

    if (totalSessions == 0) return 0;
    return completedSessions / totalSessions;
  }

  Future<void> _toggleScheduleSession(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    int sessionIndex,
    bool completed,
  ) async {
    final sessions = _sessionListFromDoc(doc);
    if (sessionIndex < 0 || sessionIndex >= sessions.length) return;

    sessions[sessionIndex]['completed'] = completed;

    await doc.reference.update({'sessions': sessions});
  }

  Future<void> _clearSchedule() async {
    if (user == null) return;

    final scheduleCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('studySchedule');

    final existing = await scheduleCollection.get();
    if (existing.docs.isEmpty) return;

    WriteBatch batch = FirebaseFirestore.instance.batch();
    int operationCount = 0;

    Future<void> commitBatch() async {
      await batch.commit();
      batch = FirebaseFirestore.instance.batch();
      operationCount = 0;
    }

    for (final doc in existing.docs) {
      batch.delete(doc.reference);
      operationCount++;
      if (operationCount == 400) {
        await commitBatch();
      }
    }

    if (operationCount > 0) {
      await commitBatch();
    }
  }

  Future<void> _generateSchedule() async {
    if (user == null) return;

    setState(() => _isGeneratingSchedule = true);

    try {
      final prefsDoc = await FirebaseFirestore.instance
          .collection('studyPreferences')
          .doc(user!.uid)
          .get();

      if (!prefsDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Set your study preferences to generate a schedule.',
              ),
            ),
          );
        }
        return;
      }

      final data = prefsDoc.data() ?? {};
      final dailyHoursValue = data['dailyHours'];
      final dailyHours = dailyHoursValue is int
          ? dailyHoursValue
          : dailyHoursValue is num
          ? dailyHoursValue.toInt()
          : 2;
      final subjectsString = (data['subjects'] as String?) ?? '';
      final examDateString = data['examDate'] as String?;

      final subjects = subjectsString
          .split(',')
          .map((subject) => subject.trim())
          .where((subject) => subject.isNotEmpty)
          .toList();

      if (subjects.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Add at least one subject in preferences.'),
            ),
          );
        }
        return;
      }

      final examDate = examDateString != null
          ? DateTime.tryParse(examDateString)
          : null;

      if (examDate == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Exam date format is invalid.')),
          );
        }
        return;
      }

      final today = DateTime.now();
      final startDate = DateTime(today.year, today.month, today.day);
      final endDate = DateTime(examDate.year, examDate.month, examDate.day);

      if (!endDate.isAfter(startDate) && endDate != startDate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Exam date must be today or in the future.'),
            ),
          );
        }
        return;
      }

      if (dailyHours <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Daily hours must be greater than zero.'),
            ),
          );
        }
        return;
      }

      final totalDays = endDate.difference(startDate).inDays + 1;
      final scheduleCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('studySchedule');

      await _clearSchedule();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      int operationCount = 0;
      int sessionCounter = 0;

      Future<void> commitBatch() async {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        operationCount = 0;
      }

      for (int dayIndex = 0; dayIndex < totalDays; dayIndex++) {
        final currentDate = startDate.add(Duration(days: dayIndex));
        final sessions = <Map<String, dynamic>>[];

        for (int hour = 0; hour < dailyHours; hour++) {
          final subject = subjects[(sessionCounter + hour) % subjects.length];
          sessions.add({
            'subject': subject,
            'durationHours': 1,
            'completed': false,
          });
        }

        sessionCounter += dailyHours;

        final docRef = scheduleCollection.doc(
          '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}',
        );

        batch.set(docRef, {
          'date': Timestamp.fromDate(currentDate),
          'sessions': sessions,
          'createdAt': FieldValue.serverTimestamp(),
        });

        operationCount++;
        if (operationCount == 400) {
          await commitBatch();
        }
      }

      if (operationCount > 0) {
        await commitBatch();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New study schedule generated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating schedule: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingSchedule = false);
      }
    }
  }

  void _confirmClearSchedule() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Schedule'),
        content: const Text('Remove all generated sessions?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearSchedule();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Schedule cleared.')),
                );
              }
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('tasks')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data!.docs;
        final progress = _calculateProgress(tasks);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Progress',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kTropicalGreen,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.grey[300],
                color: kTropicalGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 10),
              Text(
                '${(progress * 100).toInt()}% of tasks completed',
                style: const TextStyle(fontFamily: 'Poppins'),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Text(
                          'No tasks added yet.',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontFamily: 'Poppins',
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          final taskId = task.id;
                          final taskTitle = task['title'];
                          final isCompleted = task['completed'] ?? false;
                          final date = task['date'] != null
                              ? DateTime.parse(task['date'])
                              : null;

                          return Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: ListTile(
                              leading: Checkbox(
                                value: isCompleted,
                                activeColor: kTropicalGreen,
                                onChanged: (value) =>
                                    _toggleTask(taskId, value ?? false),
                              ),
                              title: Text(
                                taskTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              subtitle: Text(
                                date != null
                                    ? 'Due: ${date.toLocal().toString().split(' ')[0]}'
                                    : 'No date',
                                style: const TextStyle(fontFamily: 'Poppins'),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _deleteTask(taskId),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildScheduleTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Planned Sessions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kTropicalGreen,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Generate a tailored plan from your study preferences.',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _isGeneratingSchedule
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StudyPreferencesScreen(),
                        ),
                      );
                    },
              style: TextButton.styleFrom(foregroundColor: kTropicalGreen),
              icon: const Icon(Icons.tune),
              label: const Text(
                'Edit Study Preferences',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingSchedule ? null : _generateSchedule,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTropicalGreen,
                    foregroundColor: Colors.white,
                  ),
                  icon: _isGeneratingSchedule
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.schedule),
                  label: Text(
                    _isGeneratingSchedule
                        ? 'Generating...'
                        : 'Generate Schedule',
                    style: const TextStyle(fontFamily: 'Poppins'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _isGeneratingSchedule ? null : _confirmClearSchedule,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
                child: const Text(
                  'Clear',
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('studySchedule')
                  .orderBy('date')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final scheduleDocs = snapshot.data!.docs;

                if (scheduleDocs.isEmpty) {
                  return Center(
                    child: Text(
                      'Generate your first smart schedule to see study sessions here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontFamily: 'Poppins',
                      ),
                    ),
                  );
                }

                final progress = _calculateScheduleProgress(scheduleDocs);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.grey[300],
                      color: kTropicalGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${(progress * 100).toInt()}% of study sessions completed',
                      style: const TextStyle(fontFamily: 'Poppins'),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: scheduleDocs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final dayDoc = scheduleDocs[index];
                          final dateTimestamp =
                              dayDoc.data()['date'] as Timestamp?;
                          final date = dateTimestamp?.toDate();
                          final sessions = _sessionListFromDoc(dayDoc);

                          return Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    date != null
                                        ? 'Study Plan • ${_formatDate(date)}'
                                        : 'Study Plan',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...List.generate(sessions.length, (
                                    sessionIndex,
                                  ) {
                                    final session = sessions[sessionIndex];
                                    final subject =
                                        session['subject'] as String? ??
                                        'Subject';
                                    final duration =
                                        session['durationHours'] as int? ?? 1;
                                    final completed =
                                        session['completed'] == true;

                                    return CheckboxListTile(
                                      value: completed,
                                      onChanged: (value) =>
                                          _toggleScheduleSession(
                                            dayDoc,
                                            sessionIndex,
                                            value ?? false,
                                          ),
                                      activeColor: kTropicalGreen,
                                      title: Text(
                                        subject,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                      subtitle: Text(
                                        '$duration hour${duration == 1 ? '' : 's'}',
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: kLightMint,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Study Planner',
          style: TextStyle(
            fontFamily: 'SummaryNotes',
            fontSize: 26,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: kTropicalGreen,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontFamily: 'SummaryNotes', fontSize: 20),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'SummaryNotes',
            fontSize: 18,
          ),
          tabs: const [
            Tab(text: 'Tasks'),
            Tab(text: 'Smart Schedule'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: _showAddTaskDialog,
              backgroundColor: kTropicalGreen,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [_buildTasksTab(), _buildScheduleTab()],
      ),
    );
  }
}
