import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _scrollController = ScrollController();
  }

  // Send Message
  void _sendMessage() async {
  if (_messageController.text.trim().isEmpty || _user == null) return;

  try {
    String messageText = _messageController.text.trim();
    String senderEmail = _user!.email!;
    String receiverEmail = widget.userEmail;
    Timestamp timestamp = Timestamp.now();

    // Add message to 'messages' collection
    await _firestore.collection('messages').add({
      'text': messageText,
      'sender': senderEmail,
      'receiver': receiverEmail,
      'timestamp': timestamp,
    });

    // Update 'chats' collection with last message details
    await _firestore.collection('chats').doc('${senderEmail}_$receiverEmail').set({
      'participants': [senderEmail, receiverEmail],
      'lastMessage': messageText,
      'lastMessageTimestamp': timestamp,
      'lastMessageSender': senderEmail,
    }, SetOptions(merge: true));

    _messageController.clear();
    _scrollToBottom(); // Ensure the latest message is visible
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error sending message: $e")),
    );
  }
}


  // Scroll to Bottom
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

  // Delete Message Function
  void _deleteMessage(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message deleted successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting message: $e")),
      );
    }
  }

  // Show Delete Confirmation Dialog
  void _showDeleteDialog(String messageId) {
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
            onPressed: () {
              _deleteMessage(messageId);
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Authentication Required')),
        body: const Center(child: Text('Please log in to access chat')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userEmail),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Call feature coming soon')),
              );
            },
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('messages')
                  .where('sender', whereIn: [_user?.email, widget.userEmail])
                  .where('receiver', whereIn: [_user?.email, widget.userEmail])
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error loading messages: ${snapshot.error}"));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No messages yet"));
                }

                var messages = snapshot.data!.docs;
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Newest messages appear at the bottom
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageItem(messages[index]);
                  },
                );
              },
            ),
          ),

          // Message Input Area
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Message Input
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                  ),
                ),

                // Send Button
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

  // Message Item Builder with Delete on Long Press
  Widget _buildMessageItem(DocumentSnapshot message) {
    Map<String, dynamic>? data = message.data() as Map<String, dynamic>?;
    if (data == null) return const SizedBox.shrink();

    bool isMe = data['sender'] == _user?.email;

    return GestureDetector(
      onLongPress: () {
        if (isMe) {
          _showDeleteDialog(message.id);
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['sender'] ?? "Unknown",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
              ),
              const SizedBox(height: 5),
              Text(data['text'] ?? "", style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
