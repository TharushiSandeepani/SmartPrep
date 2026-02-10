import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/colors.dart';
import 'create_quiz_screen.dart';
import 'quiz_screen.dart';
import 'personalized_quiz_screen.dart';

class QuizListScreen extends StatelessWidget {
  const QuizListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: kLightMint,
      appBar: AppBar(
        title: const Text(
          'Available Quizzes',
          style: TextStyle(
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
        stream: firestore.collection('quizzes').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No quizzes available yet!',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            );
          }

          final quizzes = snapshot.data!.docs;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(20),
                  leading: CircleAvatar(
                    backgroundColor: kTropicalGreen.withOpacity(0.12),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: kTropicalGreen,
                    ),
                  ),
                  title: const Text(
                    'Personalized Quiz',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 6.0),
                    child: Text(
                      'Adaptive set targeting weaker areas and balanced difficulty.',
                      style: TextStyle(
                        color: Colors.black87,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: kTropicalGreen,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PersonalizedQuizScreen(),
                      ),
                    );
                  },
                ),
              ),
              ...List.generate(quizzes.length, (index) {
                final quizDoc = quizzes[index];
                final quiz = quizDoc.data() as Map<String, dynamic>;
                final quizTitle = quiz['title'] ?? 'Untitled Quiz';
                final subjectsRaw = quiz['subjects'];
                final List<String> subjects = subjectsRaw is List
                    ? subjectsRaw.whereType<String>().toList()
                    : subjectsRaw is String
                    ? <String>[subjectsRaw]
                    : <String>[];
                final String primarySubject = subjects.isNotEmpty
                    ? subjects.first
                    : 'Unknown Subject';

                return Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: kTropicalGreen.withValues(alpha: 0.15),
                      child: const Icon(Icons.quiz, color: kTropicalGreen),
                    ),
                    title: Text(
                      quizTitle,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subject: $primarySubject',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: kTropicalGreen,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuizScreen(
                            quizId: quizDoc.id,
                            quizTitle: quizTitle,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateQuizScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Quiz', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: kTropicalGreen,
        foregroundColor: Colors.white,
      ),
    );
  }
}
