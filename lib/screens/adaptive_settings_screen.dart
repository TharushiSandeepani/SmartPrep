import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../theme/colors.dart';
import '../services/adaptive_settings_service.dart';

class AdaptiveSettingsScreen extends StatefulWidget {
  const AdaptiveSettingsScreen({super.key});

  @override
  State<AdaptiveSettingsScreen> createState() => _AdaptiveSettingsScreenState();
}

class _AdaptiveSettingsScreenState extends State<AdaptiveSettingsScreen> {
  final AdaptiveSettingsService _service = AdaptiveSettingsService();
  AdaptiveSettings? _settings;
  bool _loading = true;
  bool _saving = false;

  final List<int> _questionOptions = const [5, 10, 15, 20];
  final List<String> _aggressivenessOptions = const [
    'conservative',
    'balanced',
    'challenging',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _settings = AdaptiveSettings(
          questionCount: 10,
          aggressiveness: 'balanced',
        );
      });
      return;
    }
    final s = await _service.load();
    setState(() {
      _settings = s;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_settings == null) return;
    setState(() => _saving = true);
    await _service.save(_settings!);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, true); // return true to trigger refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightMint,
      appBar: AppBar(
        title: const Text(
          'Adaptive Settings',
          style: TextStyle(
            fontFamily: 'SummaryNotes',
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        backgroundColor: kTropicalGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Question Count',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: _settings!.questionCount,
                    items: _questionOptions
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text('$c questions'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _settings = AdaptiveSettings(
                        questionCount: v ?? _settings!.questionCount,
                        aggressiveness: _settings!.aggressiveness,
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Difficulty Bias',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _settings!.aggressiveness,
                    items: _aggressivenessOptions
                        .map(
                          (a) => DropdownMenuItem(
                            value: a,
                            child: Text(a[0].toUpperCase() + a.substring(1)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _settings = AdaptiveSettings(
                        questionCount: _settings!.questionCount,
                        aggressiveness: v ?? _settings!.aggressiveness,
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _explainBias(_settings!.aggressiveness),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.black54,
                      height: 1.3,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.save),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTropicalGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      label: const Text(
                        'Save',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _explainBias(String a) {
    switch (a) {
      case 'conservative':
        return 'Leans easier until your subject averages rise above 70%. Great for rebuilding confidence.';
      case 'challenging':
        return 'Pushes harder questions earlier, especially in strong subjects (>80%). Ideal for peak training.';
      default:
        return 'Balanced mixture tuned to your current averages and recent trends.';
    }
  }
}
