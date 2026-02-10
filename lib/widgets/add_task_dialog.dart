import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/colors.dart';

Future<void> showAddTaskDialog(BuildContext context) async {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  DateTime? selectedDate;

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: kTropicalGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      selectedDate = picked;
      dateController.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: kLightMint,
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
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Task Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: dateController,
              readOnly: true,
              onTap: pickDate,
              decoration: const InputDecoration(
                labelText: 'Due Date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today, color: kTropicalGreen),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () async {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .collection('tasks')
                .add({
                  'title': titleController.text.trim(),
                  'desc': descController.text.trim(),
                  'date': selectedDate?.toIso8601String(),
                  'completed': false,
                  'createdAt': FieldValue.serverTimestamp(),
                });
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: kTropicalGreen,
            foregroundColor: Colors.white,
          ),
          child: const Text('Add'),
        ),
      ],
    ),
  );
}
