import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'personal_chat_screen.dart';
import 'status_screen.dart';
import 'group_chat_screen.dart';
import 'profile_screen.dart'; 
import 'package:http/http.dart' as http;
import 'dart:convert';


class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  User? _user;
  String _searchQuery = "";
  List<DocumentSnapshot> _combinedList = [];
  bool _isLoading = true;
  
  // Track unread message counts
  Map<String, int> _unreadCounts = {};

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _loadData();
    _setupUnreadMessagesListener();
  }
Future<void> sendPushNotification(String token, String sender, String message) async {
  try {
    const String serverKey = 'YOUR_SERVER_KEY_HERE'; // Get from Firebase Console

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


  // ✅ Load data (users and groups) in the background
  Future<void> _loadData() async {
    try {
      // Fetch users
      var userSnapshot = await _firestore.collection('users').get();

      // Fetch groups where the current user is a member
      var groupSnapshot = await _firestore
          .collection('groups')
          .where('members', arrayContains: _auth.currentUser!.uid)
          .get();

      // Combine the results
      if (mounted) {
        setState(() {
          _combinedList = [...userSnapshot.docs, ...groupSnapshot.docs];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load data: ${e.toString()}")),
      );
    }
  }

  // ✅ Set up listeners for unread messages
  void _setupUnreadMessagesListener() {
    final userId = _auth.currentUser!.uid;
    
    // Listen for personal chat unread messages
    _firestore
        .collection('unreadMessages')
        .doc(userId)
        .collection('personal')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          for (var doc in snapshot.docs) {
            _unreadCounts[doc.id] = doc['count'] ?? 0;
          }
        });
      }
    });

    // Listen for group chat unread messages
    _firestore
        .collection('unreadMessages')
        .doc(userId)
        .collection('groups')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          for (var doc in snapshot.docs) {
            _unreadCounts[doc.id] = doc['count'] ?? 0;
          }
        });
      }
    });
  }

  void _logout() async {
    await AuthService().logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  void _createGroup(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateGroupScreen(),
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Group created successfully!")),
      );
      _loadData(); // Reload data after creating a group
    }
  }
@override
Widget build(BuildContext context) {
  return DefaultTabController(
    length: 3, // Chat, Status, Call Tabs
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          'Chat App',
          style: TextStyle(color: Colors.white), // White text
        ),
        backgroundColor: Colors.deepPurple, // Background color remains
        bottom: TabBar(
          labelColor: Colors.white, // Active tab text color
          unselectedLabelColor: Colors.white70, // Slightly faded for inactive tabs
          indicatorColor: Colors.white, // Underline color
          tabs: [
            Tab(text: "Chat"),
            Tab(text: "Status"),
            Tab(text: "Call"),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person, color: Colors.white), // Profile icon
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white), // Logout icon
            onPressed: _logout,
          ),
        ],
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(Icons.chat, color: Colors.white), // White icon
        ),
      ),
      body: TabBarView(
        children: [
          _buildChatTab(), // Chat Tab
          StatusScreen(), // Status Tab
          Center(child: Text("Call feature coming soon!")), // Call Tab
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createGroup(context),
        child: Icon(Icons.group_add),
      ),
    ),
  );
}

  // ✅ Chat Tab (Combined Users and Groups List)
  Widget _buildChatTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              labelText: 'Search friends or groups...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _buildCombinedList(),
        ),
      ],
    );
  }

  // ✅ Build Combined List (Users and Groups) with notification badges
  Widget _buildCombinedList() {
    var filteredList = _combinedList.where((item) {
      var data = item.data() as Map<String, dynamic>;
      var name = data['username'] ?? data['groupName'] ?? '';
      return name.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filteredList.isEmpty) {
      return Center(child: Text("No users or groups found"));
    }

    return ListView.builder(
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        var item = filteredList[index];
        var data = item.data() as Map<String, dynamic>;
        int unreadCount = _unreadCounts[item.id] ?? 0;

        if (data.containsKey('groupName')) {
          // Display group with notification badge
          return ListTile(
            leading: CircleAvatar(backgroundImage: NetworkImage('https://i.ibb.co/FkH3PSYz/profile.jpg'),
              child: Icon(Icons.group),
            ),
            title: Text(data['groupName']),
            trailing: unreadCount > 0
                ? Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  )
                : null,
            onTap: () async {
              // Reset unread count when entering the chat
              if (unreadCount > 0) {
                await _firestore
                    .collection('unreadMessages')
                    .doc(_auth.currentUser!.uid)
                    .collection('groups')
                    .doc(item.id)
                    .delete();
              }
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupChatScreen(
                    groupId: item.id,
                    groupName: data['groupName'],
                  ),
                ),
              );
            },
          );
        } else {
          // Display user with notification badge
          bool isMe = data['email'] == _user?.email;
          if (isMe) {
            return Container(); // Don't show the current user
          }
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(
                  data['profilePic'] ?? 'https://via.placeholder.com/150'),
            ),
            title: Text(data['username'] ?? "Unknown"),
            subtitle: Text(data['status'] ?? "No status set"),
            trailing: unreadCount > 0
                ? Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  )
                : null,
            onTap: () async {
              // Reset unread count when entering the chat
              if (unreadCount > 0) {
                await _firestore
                    .collection('unreadMessages')
                    .doc(_auth.currentUser!.uid)
                    .collection('personal')
                    .doc(item.id)
                    .delete();
              }
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PersonalChatScreen(
                    userEmail: data['email'],
                    userId: item.id,
                  ),
                ),
              );
            },
          );
        }
      },
    );
  }
}

class CreateGroupScreen extends StatefulWidget {
  @override
  _CreateGroupScreenState createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _groupNameController = TextEditingController();
  List<String> _selectedUsers = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Create Group"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: 'Group Name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                var users = snapshot.data!.docs
                    .where((user) => user.id != _auth.currentUser!.uid)
                    .toList();
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    var user = users[index];
                    return CheckboxListTile(
                      title: Text(user['username']),
                      value: _selectedUsers.contains(user.id),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value!) {
                            _selectedUsers.add(user.id);
                          } else {
                            _selectedUsers.remove(user.id);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: () async {
  if (_groupNameController.text.isNotEmpty && _selectedUsers.isNotEmpty) {
    // Add the current user to the members list
    _selectedUsers.add(_auth.currentUser!.uid);

    // Get current user's email
    String? userEmail = _auth.currentUser?.email;

    // Create the group
    await _firestore.collection('groups').add({
      'groupName': _groupNameController.text,
      'createdBy': userEmail,  // Store the email instead of UID
      'members': _selectedUsers,
    });

    // Navigate back with a success result
    Navigator.pop(context, true);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Please enter a group name and select at least one member.")),
    );
  }
},

            child: Text("Create Group"),
          ),
        ],
      ),
    );
  }
}