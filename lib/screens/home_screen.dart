import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smartprep/screens/login_screen.dart';
import 'package:smartprep/screens/notification_screen.dart';
import 'package:smartprep/screens/profile_screen.dart';
import 'package:smartprep/screens/study_planner_screen.dart';
import '../services/notification_service.dart';
import '../widgets/section_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? userName;
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    if (!mounted) return;

    if (doc.exists && doc.data()?.containsKey('name') == true) {
      setState(() {
        userName = doc['name'] as String?;
      });
    } else {
      setState(() {
        userName = user!.displayName ?? user!.email ?? 'User';
      });
    }
  }

  double _calculateProgress(List<QueryDocumentSnapshot> tasks) {
    if (tasks.isEmpty) return 0;
    final completed = tasks
        .where((t) => (t['completed'] ?? false) == true)
        .length;
    return completed / tasks.length;
  }

  String _computeInitials(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    final base = trimmed.contains('@') ? trimmed.split('@').first : trimmed;
    return base.isNotEmpty ? base[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF4FBF8),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'SmartPrep',
          style: TextStyle(
            fontSize: 26,
            color: Color(0xFF1EA77B),
            fontFamily: 'SummaryNotes',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF1EA77B),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF1EA77B)),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: userName == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _buildWelcomeCard(context),
                    const SizedBox(height: 16),
                    _buildTasksSection(),
                    const SizedBox(height: 24),
                    _buildProgressSection(),
                    const SizedBox(height: 24),
                    _buildReminderSection(),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    final initials = _computeInitials(
      (userName ?? user?.displayName ?? user?.email ?? 'U').toString(),
    );

    return Card(
      color: const Color(0xFF1EA77B).withOpacity(0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              child: CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF1EA77B).withOpacity(0.15),
                foregroundImage:
                    (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child:
                    (user?.photoURL == null ||
                        (user!.photoURL?.isEmpty ?? true))
                    ? Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, $userName!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const Text(
                    'Ready to crush your goals today?',
                    style: TextStyle(
                      color: Colors.black54,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksSection() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final currentUser = authSnap.data;
        if (currentUser == null) {
          return const SizedBox();
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .collection('tasks')
              .where('completed', isEqualTo: false)
              .orderBy('createdAt', descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('Tasks stream error: ${snapshot.error}');
              return Center(
                child: Text(
                  "Couldn't load tasks. Check your Firestore rules / index.",
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontFamily: 'Poppins',
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final tasks = snapshot.data?.docs ?? [];

            if (tasks.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      size: 70,
                      color: Color(0xFF1EA77B),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No upcoming studies!\nAdd a new topic to prepare ahead.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'SummaryNotes',
                        fontSize: 22,
                        color: Color(0xFF1EA77B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StudyPlannerScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'Add Task',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1EA77B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  icon: Icons.list_alt,
                  title: 'Upcoming Tasks',
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StudyPlannerScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        color: Color(0xFF1EA77B),
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...tasks.take(3).map((task) {
                  final title = task['title'] ?? 'Untitled Task';
                  final date = task['date'] != null
                      ? DateTime.tryParse(task['date'])
                      : null;
                  final formattedDate = date != null
                      ? 'Due: ${date.toLocal().toString().split(' ')[0]}'
                      : 'No due date';
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF1EA77B),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        formattedDate,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.black54,
                        ),
                      ),
                      onTap: () {},
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(icon: Icons.insights, title: 'Your Progress'),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .collection('tasks')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const LinearProgressIndicator(
                backgroundColor: Colors.white,
              );
            }
            final tasks = snapshot.data!.docs;
            final total = tasks.length;
            final completed = tasks
                .where((t) => (t['completed'] ?? false) == true)
                .length;
            final remaining = total - completed;
            final progress = _calculateProgress(tasks);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return LinearProgressIndicator(
                      value: value,
                      minHeight: 10,
                      backgroundColor: Colors.grey[300],
                      color: const Color(0xFF1EA77B),
                      borderRadius: BorderRadius.circular(10),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ProgressStat(
                      label: 'Completed',
                      value: completed.toString(),
                    ),
                    const SizedBox(width: 12),
                    _ProgressStat(
                      label: 'Remaining',
                      value: remaining.toString(),
                    ),
                    const SizedBox(width: 12),
                    _ProgressStat(label: 'Total', value: total.toString()),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).toInt()}% of tasks completed',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.black54,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildReminderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(icon: Icons.access_time, title: 'Stay on Track'),
        const SizedBox(height: 12),
        Card(
          color: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set a daily reminder to stay consistent with your study goals.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontFamily: 'Poppins',
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final granted =
                          await NotificationService.requestPermission();
                      if (granted) {
                        await NotificationService.showDailyReminder(
                          id: 1,
                          title: 'Study Reminder',
                          body: 'Time to study for 1 hour!',
                          hour: 18,
                          minute: 0,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Daily study reminder set!'),
                              backgroundColor: Color(0xFF1EA77B),
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Notification permission is required to set reminders.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.alarm),
                    label: const Text(
                      'Set Daily Study Reminder',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1EA77B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Color(0xFF1EA77B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
