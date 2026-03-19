import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  TextEditingController _usernameController = TextEditingController();
  TextEditingController _statusController = TextEditingController();
  TextEditingController _mobileController = TextEditingController();
  String _profilePic = ""; // Just for aesthetics, not fetching from storage.
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _loadUserData();
  }

  // ✅ Load User Data Safely (Prevents Crashes on Missing Fields)
  Future<void> _loadUserData() async {
    if (_user == null) return;
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(_user!.uid).get();
      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

        setState(() {
          _usernameController.text = data['username'] ?? "";
          _statusController.text = data['status'] ?? "Hey there! I'm using Chat App";
          _mobileController.text = data.containsKey('mobile') ? data['mobile'] : "";
          _profilePic = data['profilePic'] ?? ""; // No actual upload, just a placeholder.
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading profile: ${e.toString()}")),
      );
    }
  }

  // ✅ Update User Profile (No Image Upload)
  Future<void> _updateProfile() async {
    if (_user == null) return;
    try {
      await _firestore.collection('users').doc(_user!.uid).update({
        'username': _usernameController.text.trim(),
        'status': _statusController.text.trim(),
        'mobile': _mobileController.text.trim(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Profile updated successfully!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update profile: ${e.toString()}")));
    }
  }

  // ✅ Logout Function
  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Profile")),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfilePicture(), // Profile Picture Section
                  SizedBox(height: 16),
                  _buildTextField("Username", _usernameController),
                  _buildTextField("Status", _statusController),
                  _buildTextField("Mobile Number", _mobileController),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _updateProfile,
                    child: Text("Save Changes"),
                  ),
                  SizedBox(height: 20),
                  Divider(),
                  _buildSettingsSection("Account", Icons.person),
                  _buildSettingsSection("Themes", Icons.color_lens),
                  _buildSettingsSection("Storage & Data", Icons.storage),
                  _buildSettingsSection("Languages", Icons.language),
                  _buildSettingsSection("Help", Icons.help),
                  Divider(),
                  Center(
                    child: TextButton(
                      onPressed: _logout,
                      child: Text("Logout", style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ✅ UI: Profile Picture (Aesthetic Only)
  Widget _buildProfilePicture() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.deepPurple,
            child: _profilePic.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      _profilePic,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // If the network image fails to load, fall back to initial
                        return Center(child: Text(_avatarInitial(), style: TextStyle(fontSize: 36, color: Colors.white)));
                      },
                    ),
                  )
                : Text(_avatarInitial(), style: TextStyle(fontSize: 36, color: Colors.white)),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              radius: 15,
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.edit, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ UI: Text Input Fields
  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  // Determine avatar initial from username, displayName or email
  String _avatarInitial() {
    final name = _usernameController.text.trim();
    if (name.isNotEmpty) return name[0].toUpperCase();
    if (_user != null && _user!.displayName != null && _user!.displayName!.isNotEmpty) {
      return _user!.displayName![0].toUpperCase();
    }
    if (_user != null && _user!.email != null && _user!.email!.isNotEmpty) {
      return _user!.email![0].toUpperCase();
    }
    return '?';
  }

  // ✅ UI: Settings List Items
  Widget _buildSettingsSection(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {},
    );
  }
}
