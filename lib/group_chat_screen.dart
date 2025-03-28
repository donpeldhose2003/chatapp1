import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'group_settings_screen.dart';


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
    _resetUnreadCounter();
  }
void _showDeleteOptions(String messageId, bool isMe) {
  if (!isMe) return; // Only allow sender to delete messages

  showModalBottomSheet(
    context: context,
    builder: (context) {
      return Wrap(
        children: [
          ListTile(
            leading: Icon(Icons.delete),
            title: Text("Delete for me"),
            onTap: () {
              Navigator.pop(context);
              _deleteMessageForMe(messageId);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_forever),
            title: Text("Delete for everyone"),
            onTap: () {
              Navigator.pop(context);
              _deleteMessageForEveryone(messageId);
            },
          ),
        ],
      );
    },
  );
}
Future<void> _deleteMessageForMe(String messageId) async {
  await _firestore
      .collection('groups')
      .doc(widget.groupId)
      .collection('messages')
      .doc(messageId)
      .update({'deletedFor.${_currentUser!.uid}': true});
}
Future<void> _deleteMessageForEveryone(String messageId) async {
  try {
    await _firestore
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .doc(messageId)
        .delete();
    print("Message deleted successfully");
  } catch (e) {
    print("Error deleting message: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to delete message: ${e.toString()}")),
    );
  }
}



  // Reset unread message counter when opening the chat
  Future<void> _resetUnreadCounter() async {
    if (_currentUser != null) {
      // Delete the unread counter document to reset it
      await _firestore
          .collection('unreadMessages')
          .doc(_currentUser!.uid)
          .collection('groups')
          .doc(widget.groupId)
          .delete();
    }
  }

  // ✅ Send message function with notification updates
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _currentUser == null) return;

    try {
      // Fetching user details
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();

      if (!userDoc.exists) {
        print("User document not found in Firestore.");
        return;
      }

      String senderName = userDoc['username'] ?? "Unknown";
      String messageText = _messageController.text.trim();
      Timestamp timestamp = Timestamp.now();

      // Send the message
      await _firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .add({
        'senderId': _currentUser!.uid,
        'senderName': senderName,
        'text': messageText,
        'timestamp': timestamp,
      });

      // Update the group's last message info
      await _firestore.collection('groups').doc(widget.groupId).update({
        'lastMessage': messageText,
        'lastMessageSender': senderName,
        'lastMessageTimestamp': timestamp,
      });

      // Get all group members
      final groupDoc = await _firestore.collection('groups').doc(widget.groupId).get();
      final groupData = groupDoc.data() as Map<String, dynamic>;
      final List<dynamic> members = groupData['members'] ?? [];

      // Update unread count for all members except the sender
      for (String memberId in members) {
        if (memberId != _currentUser!.uid) {
          final memberUnreadRef = _firestore
              .collection('unreadMessages')
              .doc(memberId)
              .collection('groups')
              .doc(widget.groupId);

          // Get current count
          var unreadDoc = await memberUnreadRef.get();
          int currentCount = 0;
          
          if (unreadDoc.exists) {
            currentCount = unreadDoc.data()?['count'] ?? 0;
          }
          
          // Increment and update
          await memberUnreadRef.set({
            'count': currentCount + 1,
            'lastMessage': messageText,
            'senderName': senderName,
            'timestamp': timestamp,
            'groupName': widget.groupName,
          });
        }
      }

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
      appBar: AppBar(
  title: Text(widget.groupName),
  actions: [
    
    IconButton(
      icon: Icon(Icons.settings), // Navigate to Group Settings
      onPressed: () {
        Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => GroupSettingsPage(
      groupId: widget.groupId,
      groupName: widget.groupName, 
      currentUserId: _currentUser!.uid, // ✅ Ensure this is included
    ),
  ),
);

      },
    ),
  ],
),

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
  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
    return Center(child: Text("No messages yet."));
  }

  var messages = snapshot.data!.docs.where((doc) {
    var data = doc.data() as Map<String, dynamic>;
    if (data.containsKey('deletedFor') &&
        (data['deletedFor'] as Map<String, dynamic>).containsKey(_currentUser!.uid)) {
      return false; // Hide message deleted for this user
    }
    return true;
  }).toList();

                
                // Force scroll to bottom on initial load
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });
                
                return ListView.builder(
  controller: _scrollController,
  itemCount: messages.length,
  itemBuilder: (context, index) {
    var message = messages[index].data() as Map<String, dynamic>;
    bool isMe = message['senderId'] == _currentUser!.uid;

    return GestureDetector(
      onLongPress: () => _showDeleteOptions(messages[index].id, isMe),
      child: Align(
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    ),
                    maxLines: null,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Show group members dialog
  /*void _showGroupMembers() async {
    try {
      // Get group members
      final groupDoc = await _firestore.collection('groups').doc(widget.groupId).get();
      final groupData = groupDoc.data() as Map<String, dynamic>;
      final List<dynamic> memberIds = groupData['members'] ?? [];

      // Load member details
      List<Map<String, dynamic>> members = [];
      for (String memberId in memberIds) {
        final userDoc = await _firestore.collection('users').doc(memberId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          members.add({
            'id': memberId,
            'username': userData['username'] ?? 'Unknown',
            'email': userData['email'] ?? 'No email'
          });
        }
      }

      // Show dialog with members
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Group Members'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: members.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(members[index]['username']),
                  subtitle: Text(members[index]['email']),
                  leading: CircleAvatar(
                    child: Text(members[index]['username'][0]),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load group members: ${e.toString()}")),
      );
    }
  }
*/
  // ✅ Format timestamp
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Sending...";
    DateTime dateTime = timestamp.toDate();
    return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }
}