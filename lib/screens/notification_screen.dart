import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _markAllAsRead() async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked as read')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4FBF8),
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF1EA77B),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1EA77B)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 🔹 "Mark all as read" button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 4.0,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _markAllAsRead,
                child: const Text(
                  'Mark all as read',
                  style: TextStyle(
                    color: Color(0xFF1EA77B),
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),

          // 🔹 Notifications List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('notifications')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No notifications yet!',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                final notifications = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final data =
                        notifications[index].data() as Map<String, dynamic>;
                    final title = data['title'] ?? 'No Title';
                    final body = data['body'] ?? '';
                    final isRead = data['isRead'] ?? false;
                    final timestamp = (data['timestamp'] != null)
                        ? DateTime.tryParse(data['timestamp'].toString())
                        : null;

                    String formattedTime = '';
                    if (timestamp != null) {
                      formattedTime = DateFormat(
                        'MMM dd, yyyy – hh:mm a',
                      ).format(timestamp);
                    }

                    return Card(
                      color: isRead
                          ? Colors.white
                          : const Color(0xFF1EA77B).withOpacity(0.1),
                      elevation: isRead ? 1 : 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.notifications_active,
                          color: isRead ? Colors.grey : const Color(0xFF1EA77B),
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            fontWeight: isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              body,
                              style: const TextStyle(color: Colors.black87),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formattedTime,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        onTap: () async {
                          if (!isRead) {
                            await _firestore
                                .collection('notifications')
                                .doc(notifications[index].id)
                                .update({'isRead': true});
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
