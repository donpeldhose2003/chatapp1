import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'monitor_chats_tab.dart';
import 'control_groups_tab.dart';
import 'analytics_screen.dart';

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Function to delete a user
  Future<void> _deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting user: $e')),
      );
    }
  }

  // Function to log out admin
  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Three tabs: Users, Chats, Groups
      child: Scaffold(
        appBar: AppBar(
          title: Text('Admin Dashboard'),
          backgroundColor: Colors.redAccent,
          actions: [
            // Admin profile icon with menu
            PopupMenuButton<String>(
              icon: CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.admin_panel_settings, color: Colors.white),
              ),
              onSelected: (value) {
                if (value == 'analytics') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AnalyticsScreen()));
                } else if (value == 'logout') {
                  _logout();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'analytics', child: Text('Analytics & Reporting')),
                PopupMenuItem(value: 'logout', child: Text('Logout')),
              ],
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: "Users"),
              Tab(icon: Icon(Icons.chat), text: "Chats"),
              Tab(icon: Icon(Icons.group), text: "Groups"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUserManagementTab(), // Users
            MonitorChatsTab(), // Chats
            ControlGroupsTab(), // Groups
          ],
        ),
      ),
    );
  }

  // User Management Tab (View and Delete Users)
  Widget _buildUserManagementTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No registered users found.'));
        }

        var users = snapshot.data!.docs;

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            var user = users[index];
            String userId = user.id;
            String username = user['username'] ?? 'Unknown';
            String email = user['email'] ?? 'No Email';
            String status = user['status'] ?? 'No Status';

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Text(username[0].toUpperCase(),
                      style: TextStyle(color: Colors.white)),
                ),
                title: Text(username, style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Email: $email"),
                    Text("Status: $status"),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteUser(userId),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
