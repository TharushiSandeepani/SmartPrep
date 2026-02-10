import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/colors.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _QuizMeta {
  _QuizMeta({
    required this.title,
    required this.subjects,
    required this.questionCount,
  });

  final String title;
  final List<String> subjects;
  final int questionCount;
}

class _QuizHistoryItem {
  const _QuizHistoryItem({
    required this.quizId,
    required this.quizTitle,
    required this.scorePercent,
    required this.rawScore,
    required this.totalQuestions,
    required this.submittedAt,
    required this.subjects,
  });

  final String quizId;
  final String quizTitle;
  final double scorePercent;
  final double rawScore;
  final int? totalQuestions;
  final DateTime? submittedAt;
  final List<String> subjects;
}

class _SubjectStats {
  double totalScore = 0;
  int attempts = 0;
  final List<_QuizHistoryItem> entries = [];

  double get average =>
      attempts == 0 ? 0 : (totalScore / attempts).clamp(0, 100);

  double get recentDelta {
    if (entries.length < 2) return 0;
    return entries.first.scorePercent - entries[1].scorePercent;
  }
}

class _ImprovementSuggestion {
  const _ImprovementSuggestion({
    required this.subject,
    required this.average,
    required this.delta,
  });

  final String subject;
  final double average;
  final double delta;

  IconData get icon =>
      delta < -3 ? Icons.trending_down : Icons.lightbulb_outline;

  Color get color => delta < -3 ? Colors.redAccent : Colors.orangeAccent;

  String get message {
    if (average < 60) {
      return 'Average is ${average.toStringAsFixed(0)}%. Revisit fundamentals and schedule a focused revision block.';
    }
    if (delta < -3) {
      return 'Recent scores dipped by ${delta.abs().toStringAsFixed(1)} pts. Review recent attempts to bounce back.';
    }
    return 'Aim for higher consistency with an extra timed quiz session this week.';
  }
}

class _SubjectPerformanceRow extends StatelessWidget {
  const _SubjectPerformanceRow({
    required this.subject,
    required this.average,
    required this.delta,
    required this.formatter,
  });

  final String subject;
  final double average;
  final double delta;
  final String Function(double) formatter;

  @override
  Widget build(BuildContext context) {
    final progress = (average.clamp(0, 100)) / 100;
    IconData? indicator;
    Color? indicatorColor;

    if (delta > 2) {
      indicator = Icons.trending_up;
      indicatorColor = kTropicalGreen;
    } else if (delta < -2) {
      indicator = Icons.trending_down;
      indicatorColor = Colors.redAccent;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                subject,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${formatter(average)}%',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
            if (indicator != null) ...[
              const SizedBox(width: 6),
              Icon(indicator, size: 18, color: indicatorColor),
            ],
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          minHeight: 10,
          backgroundColor: Colors.grey.shade300,
          color: kTropicalGreen,
          borderRadius: BorderRadius.circular(10),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.subject,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subject;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subject,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'SummaryNotes',
              fontSize: 22,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.black54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  double _quizAverage = 0.0;
  List<_QuizHistoryItem> _quizHistory = [];
  Map<String, _SubjectStats> _subjectStats = {};
  String? _topSubject;
  String? _focusSubject;
  List<_ImprovementSuggestion> _suggestions = [];
  bool _isLoading = true;
  bool _showFullHistory = false;

  static const int _historyPreviewLimit = 4;

  @override
  void initState() {
    super.initState();
    _fetchPerformance();
  }

  Future<void> _fetchPerformance() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _quizAverage = 0;
          _quizHistory = [];
          _subjectStats = {};
          _topSubject = null;
          _focusSubject = null;
          _suggestions = [];
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final baseQuery = _firestore
        .collection('quizResults')
        .where('userId', isEqualTo: user.uid);

    QuerySnapshot<Map<String, dynamic>> resultsSnapshot;

    try {
      resultsSnapshot = await baseQuery
          .orderBy('submittedAt', descending: true)
          .get();
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        resultsSnapshot = await baseQuery.get();
      } else {
        debugPrint('Performance fetch error: ${e.message}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to load performance data.')),
          );
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Performance fetch error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load performance data.')),
        );
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    // Fallback query works without sorting if Firestore index is missing.
    // Suppress tip snack bar per user preference to keep UI quiet.

    if (resultsSnapshot.docs.isEmpty) {
      setState(() {
        _isLoading = false;
        _quizAverage = 0;
        _quizHistory = [];
        _subjectStats = {};
        _topSubject = null;
        _focusSubject = null;
        _suggestions = [];
      });
      return;
    }

    final Map<String, _QuizMeta?> quizCache = {};

    Future<_QuizMeta?> loadQuizMeta(String quizId) async {
      if (quizCache.containsKey(quizId)) return quizCache[quizId];
      try {
        final doc = await _firestore.collection('quizzes').doc(quizId).get();
        if (!doc.exists) {
          quizCache[quizId] = null;
          return null;
        }

        final data = doc.data();
        if (data == null) {
          quizCache[quizId] = null;
          return null;
        }

        final titleRaw = data['title'];
        final title = (titleRaw is String && titleRaw.trim().isNotEmpty)
            ? titleRaw.trim()
            : 'Untitled Quiz';

        final rawSubjects = data['subjects'];
        final subjects = rawSubjects is List
            ? rawSubjects
                  .whereType<String>()
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList()
            : rawSubjects is String && rawSubjects.trim().isNotEmpty
            ? <String>[rawSubjects.trim()]
            : <String>[];

        int questionCount = 0;
        final questionCountRaw = data['questionCount'];
        if (questionCountRaw is int && questionCountRaw > 0) {
          questionCount = questionCountRaw;
        } else {
          final questionsSnap = await doc.reference
              .collection('questions')
              .get();
          questionCount = questionsSnap.size;
        }

        final meta = _QuizMeta(
          title: title,
          subjects: subjects,
          questionCount: questionCount,
        );
        quizCache[quizId] = meta;
        return meta;
      } catch (e) {
        debugPrint('Failed to load quiz meta for $quizId: $e');
        quizCache[quizId] = null;
        return null;
      }
    }

    double totalPercent = 0;
    final List<_QuizHistoryItem> history = [];

    String resolveQuizId(dynamic rawValue, String fallback) {
      if (rawValue is String && rawValue.trim().isNotEmpty) {
        return rawValue.trim();
      }
      if (rawValue is DocumentReference) {
        return rawValue.id;
      }
      return fallback;
    }

    for (final doc in resultsSnapshot.docs) {
      final data = doc.data();
      final quizId = resolveQuizId(data['quizId'], doc.id);
      if (quizId.isEmpty) {
        continue;
      }

      final rawScore = (data['score'] as num?)?.toDouble() ?? 0;
      String quizTitle = (data['quizTitle'] as String?)?.trim() ?? '';
      final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();

      final meta = await loadQuizMeta(quizId);

      // Prefer subjects stored on result (e.g., personalized quizzes). Fallback to quiz meta or ['General']
      List<String> subjects = (() {
        final raw = data['subjects'];
        if (raw is List) {
          return raw
              .whereType<String>()
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        } else if (raw is String && raw.trim().isNotEmpty) {
          return <String>[raw.trim()];
        }
        return <String>[];
      })();

      int? totalQuestions = (data['totalQuestions'] as num?)?.toInt();
      if (meta != null) {
        if (quizTitle.isEmpty) {
          quizTitle = meta.title;
        }
        if (subjects.isEmpty && meta.subjects.isNotEmpty) {
          subjects = meta.subjects;
        }
        if ((totalQuestions == null || totalQuestions <= 0) &&
            meta.questionCount > 0) {
          totalQuestions = meta.questionCount;
        }
      }

      double percentScore = rawScore;
      if (totalQuestions != null && totalQuestions > 0) {
        percentScore = ((rawScore / totalQuestions) * 100).clamp(0, 100);
      }

      final fallbackLabel = quizId.length >= 4
          ? quizId.substring(0, 4)
          : quizId;

      history.add(
        _QuizHistoryItem(
          quizId: quizId,
          quizTitle: quizTitle.isNotEmpty ? quizTitle : 'Quiz $fallbackLabel',
          scorePercent: percentScore,
          rawScore: rawScore,
          totalQuestions: totalQuestions,
          submittedAt: submittedAt,
          subjects: subjects,
        ),
      );

      totalPercent += percentScore;
    }

    if (history.isEmpty) {
      setState(() {
        _quizAverage = 0;
        _quizHistory = [];
        _subjectStats = {};
        _topSubject = null;
        _focusSubject = null;
        _suggestions = [];
      });
      return;
    }

    history.sort((a, b) {
      final aDate = a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    final Map<String, _SubjectStats> subjectStats = {};

    for (final item in history) {
      for (final subject in item.subjects) {
        final stats = subjectStats.putIfAbsent(subject, () => _SubjectStats());
        stats.totalScore += item.scorePercent;
        stats.attempts += 1;
        stats.entries.add(item);
      }
    }

    String? topSubject;
    String? focusSubject;
    double highestAverage = -1;
    double lowestAverage = double.infinity;

    subjectStats.forEach((subject, stats) {
      final average = stats.average;
      if (average > highestAverage) {
        highestAverage = average;
        topSubject = subject;
      }
      if (average < lowestAverage) {
        lowestAverage = average;
        focusSubject = subject;
      }
    });

    final List<_ImprovementSuggestion> suggestions = [];

    subjectStats.forEach((subject, stats) {
      final average = stats.average;
      final delta = stats.recentDelta;
      if (average < 75 || delta < -3) {
        suggestions.add(
          _ImprovementSuggestion(
            subject: subject,
            average: average,
            delta: delta,
          ),
        );
      }
    });

    suggestions.sort((a, b) => a.average.compareTo(b.average));

    if (mounted) {
      setState(() {
        _isLoading = false;
        _quizAverage = totalPercent / history.length;
        _quizHistory = history;
        _subjectStats = subjectStats;
        _topSubject = topSubject;
        _focusSubject = focusSubject;
        _suggestions = suggestions.take(3).toList();
      });
    }
  }

  String _formatPercent(double value) {
    final rounded = value.isFinite ? value : 0;
    return (rounded - rounded.truncateToDouble()).abs() < 0.05
        ? rounded.round().toString()
        : rounded.toStringAsFixed(1);
  }

  String _formatScore(double value) {
    return (value - value.truncateToDouble()).abs() < 0.05
        ? value.round().toString()
        : value.toStringAsFixed(1);
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('MMM d, yyyy • HH:mm').format(date);
  }

  Widget _buildStrengthCards() {
    if (_subjectStats.isEmpty) return const SizedBox.shrink();

    final subjectCount = _subjectStats.length;
    final top = _topSubject;
    final focus = _focusSubject;
    final topStats = top != null ? _subjectStats[top] : null;
    final focusStats = focus != null ? _subjectStats[focus] : null;

    if (subjectCount <= 1 || top == focus) {
      if (top == null || topStats == null) return const SizedBox.shrink();
      return _InsightCard(
        title: 'Key Strength',
        subject: top,
        value: '${_formatPercent(topStats.average)}%',
        caption: 'Keep challenging yourself here to stay sharp.',
        icon: Icons.emoji_events_outlined,
        color: kTropicalGreen,
      );
    }

    Widget? topCard;
    Widget? focusCard;

    if (top != null && topStats != null) {
      topCard = _InsightCard(
        title: 'Top Strength',
        subject: top,
        value: '${_formatPercent(topStats.average)}%',
        caption: 'Maintain momentum with advanced practice.',
        icon: Icons.trending_up,
        color: kTropicalGreen,
      );
    }

    if (focus != null && focusStats != null) {
      focusCard = _InsightCard(
        title: 'Needs Focus',
        subject: focus,
        value: '${_formatPercent(focusStats.average)}%',
        caption: 'Plan extra revision sessions this week.',
        icon: Icons.flag_outlined,
        color: Colors.orangeAccent,
      );
    }

    if (topCard == null && focusCard == null) return const SizedBox.shrink();
    if (topCard != null && focusCard == null) return topCard;
    if (topCard == null && focusCard != null) return focusCard;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [topCard!, const SizedBox(height: 12), focusCard!],
          );
        }
        return Row(
          children: [
            Expanded(child: topCard!),
            const SizedBox(width: 12),
            Expanded(child: focusCard!),
          ],
        );
      },
    );
  }

  Widget _buildSubjectBreakdownCard() {
    if (_subjectStats.isEmpty) return const SizedBox.shrink();

    final entries = _subjectStats.entries.toList()
      ..sort((a, b) => b.value.average.compareTo(a.value.average));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Subject Performance',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            for (final entry in entries) ...[
              _SubjectPerformanceRow(
                subject: entry.key,
                average: entry.value.average,
                delta: entry.value.recentDelta,
                formatter: _formatPercent,
              ),
              if (entry != entries.last) const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImprovementCard() {
    if (_subjectStats.isEmpty) return const SizedBox.shrink();

    if (_suggestions.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: const [
              Icon(Icons.celebration_outlined, color: kTropicalGreen),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Great job! Your scores are trending positively across subjects. Keep practising to stay ahead.',
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Improvement Ideas',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            for (final suggestion in _suggestions) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(suggestion.icon, color: suggestion.color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          suggestion.subject,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          suggestion.message,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (suggestion != _suggestions.last)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryToggle() {
    final label = _showFullHistory ? 'Show less' : 'View all history';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: kTropicalGreen,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () {
            setState(() {
              _showFullHistory = !_showFullHistory;
            });
          },
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleHistoryCount = _showFullHistory
        ? _quizHistory.length
        : (_quizHistory.length > _historyPreviewLimit
              ? _historyPreviewLimit
              : _quizHistory.length);
    final hasHistoryOverflow = _quizHistory.length > _historyPreviewLimit;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF8),
      appBar: AppBar(
        backgroundColor: kTropicalGreen,
        foregroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: const Text(
          'Performance Overview',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _quizHistory.isEmpty
          ? const Center(
              child: Text(
                'No quiz results yet!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            )
          : SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Center(
                          child: Column(
                            children: [
                              const Text(
                                'Your Average Score',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1EA77B),
                                ),
                              ),
                              const SizedBox(height: 15),
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    height: 110,
                                    width: 110,
                                    child: CircularProgressIndicator(
                                      value: (_quizAverage.clamp(0, 100)) / 100,
                                      color: const Color(0xFF1EA77B),
                                      backgroundColor: Colors.grey.shade300,
                                      strokeWidth: 10,
                                    ),
                                  ),
                                  Text(
                                    '${_formatPercent(_quizAverage)}%',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1EA77B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 25),
                            ],
                          ),
                        ),
                        if (_subjectStats.isNotEmpty) ...[
                          const Text(
                            'Strengths & Focus Areas',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1EA77B),
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildStrengthCards(),
                          const SizedBox(height: 20),
                          _buildSubjectBreakdownCard(),
                          const SizedBox(height: 20),
                          _buildImprovementCard(),
                          const SizedBox(height: 24),
                        ],
                        const Text(
                          'Your Quiz History',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1EA77B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (hasHistoryOverflow) _buildHistoryToggle(),
                      ]),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final quiz = _quizHistory[index];
                      final scoreLabel =
                          '${_formatPercent(quiz.scorePercent)}%';
                      final totalLabel = quiz.totalQuestions != null
                          ? ' (${_formatScore(quiz.rawScore)}/${quiz.totalQuestions})'
                          : '';
                      final dateLabel = _formatDateTime(quiz.submittedAt);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Card(
                          color: Colors.white,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(
                                0xFF1EA77B,
                              ).withOpacity(0.1),
                              child: const Icon(
                                Icons.quiz_outlined,
                                color: Color(0xFF1EA77B),
                              ),
                            ),
                            title: Text(
                              quiz.quizTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Quiz ID: ${quiz.quizId}',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Score: $scoreLabel$totalLabel',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                Text(
                                  'Date: $dateLabel',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                if (quiz.subjects.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: quiz.subjects
                                        .map(
                                          (subject) => Chip(
                                            backgroundColor: kTropicalGreen
                                                .withOpacity(0.12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              side: BorderSide(
                                                color: kTropicalGreen
                                                    .withOpacity(0.6),
                                              ),
                                            ),
                                            label: Text(
                                              subject,
                                              style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                color: kTropicalGreen,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        ),
                      );
                    }, childCount: visibleHistoryCount),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],
              ),
            ),
    );
  }
}
