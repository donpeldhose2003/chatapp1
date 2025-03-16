import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({Key? key, required this.groupId, required this.groupName}) : super(key: key);

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
  }

  // ✅ Send message function
  Future<void> _sendMessage() async {
  if (_messageController.text.trim().isEmpty || _currentUser == null) return;

  try {
    print("Fetching user details...");
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();

    if (!userDoc.exists) {
      print("User document not found in Firestore.");
      return;
    }

    String senderName = userDoc['username'] ?? "Unknown";

    print("Sending message...");
    await _firestore
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .add({
      'senderId': _currentUser!.uid,
      'senderName': senderName,
      'text': _messageController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    print("Message sent successfully!");
    _messageController.clear();
    _scrollToBottom();
  } catch (e) {
    print("Error sending message: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to send message: ${e.toString()}")),
    );
  }
}

  // ✅ Scroll to bottom after sending message
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: Column(
        children: [
          // ✅ Display messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('groups')
                  .doc(widget.groupId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("No messages yet."));
                }

                var messages = snapshot.data!.docs;
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index].data() as Map<String, dynamic>;
                    bool isMe = message['senderId'] == _currentUser!.uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[300] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['senderName'] ?? "Unknown",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(message['text'] ?? ""),
                            Text(
                              _formatTimestamp(message['timestamp']),
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ✅ Message Input Field
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Enter your message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Format timestamp
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Sending...";
    DateTime dateTime = timestamp.toDate();
    return "${dateTime.hour}:${dateTime.minute}";
  }
}
