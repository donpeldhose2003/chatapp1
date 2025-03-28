import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For formatting timestamps

class MonitorChatsTab extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('messages').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No messages found.'));
        }

        var messages = snapshot.data!.docs;

        return ListView.builder(
          itemCount: messages.length,
          itemBuilder: (context, index) {
            var message = messages[index];

            // Check if the document exists before accessing fields
            if (!message.exists || message.data() == null) {
              return SizedBox(); // Skip this item if document doesn't exist
            }

            // Safe retrieval of fields using try-catch
            String sender = 'Unknown Sender';
            String receiver = 'Unknown Receiver';
            String text = 'No Content';
            DateTime timestamp = DateTime.now();

            try {
              sender = message.get('sender') ?? 'Unknown Sender';
              receiver = message.get('receiver') ?? 'Unknown Receiver';
              text = message.get('text') ?? 'No Content';

              // Fix Timestamp Error: Handle both Timestamp and String
              dynamic timestampRaw = message.get('timestamp');
              if (timestampRaw is Timestamp) {
                timestamp = timestampRaw.toDate();
              } else if (timestampRaw is String) {
                timestamp = DateTime.tryParse(timestampRaw) ?? DateTime.now();
              }
            } catch (e) {
              print("Error retrieving message data: $e");
            }

            String formattedTime = DateFormat('dd MMM yyyy, hh:mm a').format(timestamp);

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                title: Text("From: $sender → To: $receiver", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Message: $text"),
                    Text("Sent at: $formattedTime"),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
