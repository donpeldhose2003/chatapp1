import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class PersonalChatScreen extends StatefulWidget {
  final String userEmail;
  final String userId;

  const PersonalChatScreen({Key? key, required this.userEmail, required this.userId}) : super(key: key);

  @override
  _PersonalChatScreenState createState() => _PersonalChatScreenState();
}

class _PersonalChatScreenState extends State<PersonalChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  User? _user;
  late ScrollController _scrollController;

  @override
  @override
void initState() {
  super.initState();
  _user = _auth.currentUser;
  _scrollController = ScrollController();

  if (_user != null) {
    _markMessagesAsRead();
  }
}

void _markMessagesAsRead() async {
  try {
    DocumentReference unreadRef = _firestore
        .collection('unreadMessages')
        .doc(_user!.uid) // Current user's UID
        .collection('personal')
        .doc(widget.userId); // Chat partner's UID

    await unreadRef.delete(); // Remove unread count when user opens chat

    print("✅ Marked messages as read");
  } catch (e) {
    print("❌ Error marking messages as read: $e");
  }
}

  /// ✅ Generate a unique chat ID based on emails
  String _getChatId(String email1, String email2) {
    List<String> emails = [email1, email2];
    emails.sort(); // Ensure consistent order
    return "${emails[0]}_${emails[1]}";
  }

  
Future<void> sendPushNotification(String token, String sender, String message) async {
  try {
    const String serverKey = 'YOUR_SERVER_KEY_HERE'; // Replace with Firebase Server Key

    final Map<String, dynamic> data = {
      "to": token,
      "notification": {
        "title": "New message from $sender",
        "body": message,
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
        "sound": "default"
      },
      "data": {
        "sender": sender,
        "message": message
      }
    };

    final response = await http.post(
      Uri.parse("https://fcm.googleapis.com/fcm/send"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "key=$serverKey",
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      print("✅ Push notification sent successfully.");
    } else {
      print("❌ Failed to send push notification: ${response.body}");
    }
  } catch (e) {
    print("❌ Error sending push notification: $e");
  }
}

  /// ✅ Send a message
  void _sendMessage() async {
  if (_messageController.text.isNotEmpty && _user != null) {
    try {
      String chatId = _getChatId(_user!.email!, widget.userEmail);
      String messageText = _messageController.text.trim();

      // Add message to Firestore
      await _firestore.collection('messages').add({
        'text': messageText,
        'sender': _user?.email,
        'receiver': widget.userEmail,
        'timestamp': FieldValue.serverTimestamp(),
        'chatId': chatId,
        'read': false, // New field to track read status
      });

      // Update last message in chats collection
      await _firestore.collection('chats').doc(chatId).set({
        'participants': [_user?.email, widget.userEmail],
        'lastMessage': messageText,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSender': _user?.email,
      }, SetOptions(merge: true));

      // 🔥 Increment unread count for the receiver
      DocumentReference unreadRef = _firestore
          .collection('unreadMessages')
          .doc(widget.userId) // Receiver's UID
          .collection('personal')
          .doc(_user!.uid); // Sender's UID

      await unreadRef.set({
        'count': FieldValue.increment(1),
      }, SetOptions(merge: true));

      print("✅ Message sent successfully");

      // Fetch receiver's FCM token and send push notification
      DocumentSnapshot receiverSnapshot =
          await _firestore.collection('users').doc(widget.userEmail).get();

      if (receiverSnapshot.exists) {
        String? receiverToken = receiverSnapshot['fcmToken'];

        if (receiverToken != null && receiverToken.isNotEmpty) {
          await sendPushNotification(receiverToken, _user!.email!, messageText);
        }
      }

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print("❌ Error sending message: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error sending message")));
    }
  }
}


  /// ✅ Scroll to bottom after sending a message
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Authentication Required')),
        body: const Center(child: Text('Please log in to access chat')),
      );
    }

    String chatId = _getChatId(_user!.email!, widget.userEmail);

    return Scaffold(
  appBar: AppBar(title: Text(widget.userEmail)),
  body: Column(
    children: [
      // ✅ Messages List
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('messages')
              .where('chatId', isEqualTo: chatId)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              print("🔥 Firestore Error: ${snapshot.error}");
              return Center(child: Text("Error: ${snapshot.error}"));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No messages yet"));
            }

            var messages = snapshot.data!.docs;

            // ✅ Mark messages as read when chat opens
            

            return ListView.builder(
              controller: _scrollController,
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return _buildMessageItem(messages[index]);
              },
            );
          },
        ),
      ),

      // ✅ Message Input Box
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.blue),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    ],
  ),
);

  }

  /// ✅ Message Item Builder with Long Press to Delete
  Widget _buildMessageItem(DocumentSnapshot message) {
    Map<String, dynamic>? data = message.data() as Map<String, dynamic>?;
    if (data == null) return const SizedBox.shrink();

    bool isMe = data['sender'] == _user?.email;
    Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
    String messageId = message.id; // Get Firestore document ID

    String formattedTime;
    DateTime dateTime = timestamp.toDate();
    DateTime now = DateTime.now();

    if (dateTime.day == now.day && dateTime.month == now.month && dateTime.year == now.year) {
      formattedTime = DateFormat('h:mm a').format(dateTime);
    } else {
      formattedTime = DateFormat('MMM d, yyyy h:mm a').format(dateTime);
    }

    return GestureDetector(
      onLongPress: () {
        if (isMe) {
          _showDeleteConfirmation(messageId);
        }
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? Colors.blueAccent : Colors.grey[300],
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                data['text'] ?? "",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                formattedTime,
                style: TextStyle(fontSize: 12, color: isMe ? Colors.white70 : Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ Show delete confirmation dialog
  void _showDeleteConfirmation(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Message"),
        content: const Text("Are you sure you want to delete this message?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _firestore.collection('messages').doc(messageId).delete();

                // ✅ Check if any messages remain in the chat
                String chatId = _getChatId(_user!.email!, widget.userEmail);
                QuerySnapshot messagesSnapshot = await _firestore
                    .collection('messages')
                    .where('chatId', isEqualTo: chatId)
                    .orderBy('timestamp', descending: true)
                    .get();

                if (messagesSnapshot.docs.isNotEmpty) {
                  var lastMessage = messagesSnapshot.docs.first;
                  await _firestore.collection('chats').doc(chatId).update({
                    'lastMessage': lastMessage['text'],
                    'lastMessageTimestamp': lastMessage['timestamp'],
                  });
                } else {
                  await _firestore.collection('chats').doc(chatId).delete();
                }

                Navigator.pop(context);
              } catch (e) {
                print("❌ Error deleting message: $e");
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
