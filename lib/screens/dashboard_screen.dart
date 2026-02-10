import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'quiz_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();

  // ✅ Add a toggle for marking completion
  Future<void> _toggleTaskCompletion(String taskId, bool currentStatus) async {
    await _firestore.collection('tasks').doc(taskId).update({
      'isCompleted': !currentStatus,
    });
  }

  // ✅ Add a new task
  Future<void> _addTask() async {
    final user = _auth.currentUser;
    if (user == null || _taskController.text.trim().isEmpty) return;

    await _firestore.collection('tasks').add({
      'title': _taskController.text.trim(),
      'subject': _subjectController.text.trim(),
      'dueDate': _dueDateController.text.trim(),
      'isCompleted': false,
      'userId': user.uid,
      'createdAt': Timestamp.now(),
    });

    _taskController.clear();
    _subjectController.clear();
    _dueDateController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Study Plan Dashboard"),
        backgroundColor: Colors.deepPurple,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('tasks')
            .where('userId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No tasks yet!"));
          }

          final tasks = snapshot.data!.docs;
          final totalTasks = tasks.length;
          final completedTasks = tasks
              .where((t) => t['isCompleted'] == true)
              .length;
          final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

          return Column(
            children: [
              // 🔹 Progress Overview Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      "Your Study Progress",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 120,
                          width: 120,
                          child: CircularProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[300],
                            color: Colors.deepPurple,
                            strokeWidth: 10,
                          ),
                        ),
                        Text(
                          "${(progress * 100).toStringAsFixed(0)}%",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text("Completed $completedTasks of $totalTasks tasks"),
                  ],
                ),
              ),

              // 🔹 Task List Section
              Expanded(
                child: ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final isCompleted = task['isCompleted'] ?? false;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: Checkbox(
                          value: isCompleted,
                          onChanged: (_) =>
                              _toggleTaskCompletion(task.id, isCompleted),
                        ),
                        title: Text(
                          task['title'] ?? '',
                          style: TextStyle(
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        subtitle: Text(
                          "Subject: ${task['subject']}\nDue: ${task['dueDate']}",
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _firestore
                              .collection('tasks')
                              .doc(task.id)
                              .delete(),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 🔹 Add Task Input Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _taskController,
                      decoration: const InputDecoration(
                        labelText: 'Task Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _dueDateController,
                      decoration: const InputDecoration(
                        labelText: 'Due Date (YYYY.MM.DD)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _addTask,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        "Add Task",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 🔹 Go to Quiz Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuizListScreen()),
                    );
                  },
                  icon: const Icon(Icons.quiz),
                  label: const Text(
                    'Go to Quizzes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
