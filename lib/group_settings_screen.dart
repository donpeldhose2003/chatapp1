import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GroupSettingsPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String currentUserId;

  const GroupSettingsPage({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _GroupSettingsPageState createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends State<GroupSettingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _members = [];
  List<String> _admins = [];
  bool _isAdmin = false;
  bool _isLoading = true;
  String _creatorId = ""; // Store the group creator ID

  @override
  void initState() {
    super.initState();
    _fetchGroupDetails();
  }

  Future<void> _fetchGroupDetails() async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(widget.groupId).get();
      if (!groupDoc.exists) {
        Navigator.pop(context); // If group is deleted, go back
        return;
      }

      final data = groupDoc.data() as Map<String, dynamic>;
      List<String> memberIds = List<String>.from(data['members'] ?? []);
      _creatorId = data['createdBy'] ?? ""; // ✅ Store group creator ID
      _admins = List<String>.from(data['admins'] ?? []);

      // Ensure creator is in admin list
      if (!_admins.contains(_creatorId)) {
        _admins.add(_creatorId);
      }

      final usersSnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: memberIds.isNotEmpty ? memberIds : ['dummy'])
          .get();

      List<Map<String, dynamic>> memberDetails = usersSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                'username': doc['username'] ?? 'Unknown',
                'isAdmin': _admins.contains(doc.id), // ✅ Check if admin
              })
          .toList();

      setState(() {
        _members = memberDetails;
        _isAdmin = _admins.contains(widget.currentUserId);
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching group details: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMember(String userId) async {
  if (!_isAdmin || userId == widget.currentUserId) return; // Prevent removing self

  final bool isTargetAdmin = _admins.contains(userId);
  final bool isCreator = widget.currentUserId == _creatorId;

  // Only allow:
  // - Creator to remove anyone (including admins)
  // - Admins to remove non-admins
  if (!isCreator && isTargetAdmin) {
    print("Only the group creator can remove admins.");
    return;
  }

  try {
    await _firestore.collection('groups').doc(widget.groupId).update({
      'members': FieldValue.arrayRemove([userId]),
      'admins': FieldValue.arrayRemove([userId]), // ✅ Remove admin privileges if they are admin
    });

    setState(() {
      _members.removeWhere((member) => member['id'] == userId);
      _admins.remove(userId); // ✅ Update local admin list
    });

    // Check if the group is empty and delete it
    final groupDoc = await _firestore.collection('groups').doc(widget.groupId).get();
    if (groupDoc.exists) {
      final data = groupDoc.data() as Map<String, dynamic>;
      List<dynamic> updatedMembers = data['members'] ?? [];

      if (updatedMembers.isEmpty) {
        await _firestore.collection('groups').doc(widget.groupId).delete();
        Navigator.pop(context); // Exit settings screen if group is deleted
      }
    }
  } catch (e) {
    print("Error removing member: $e");
  }
}

  Future<void> _exitGroup() async {
    try {
      await _firestore.collection('groups').doc(widget.groupId).update({
        'members': FieldValue.arrayRemove([widget.currentUserId]),
      });

      setState(() {
        _members.removeWhere((member) => member['id'] == widget.currentUserId);
      });

      // Check if group is empty and delete it
      final groupDoc = await _firestore.collection('groups').doc(widget.groupId).get();
      if (groupDoc.exists) {
        final data = groupDoc.data() as Map<String, dynamic>;
        List<dynamic> updatedMembers = data['members'] ?? [];

        if (updatedMembers.isEmpty) {
          await _firestore.collection('groups').doc(widget.groupId).delete();
        }
      }

      Navigator.pop(context); // Exit screen after leaving
    } catch (e) {
      print("Error exiting group: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.groupName} Settings")),
      body: Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Group Members", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _members.isEmpty
                      ? Center(child: Text("No members in the group."))
                      : ListView.builder(
                          itemCount: _members.length,
                          itemBuilder: (context, index) {
                            final member = _members[index];
                            final isMemberAdmin = member['isAdmin']; // ✅ Check if admin

                            return ListTile(
                              title: Text(member['username']),
                              subtitle: isMemberAdmin
                                  ? Text("Admin", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                                  : null,
                              trailing: _isAdmin && !isMemberAdmin // ✅ Show remove button only for non-admins
                                  ? IconButton(
                                      icon: Icon(Icons.remove_circle, color: Colors.red),
                                      onPressed: () => _showRemoveDialog(member['id'], member['username']),
                                    )
                                  : isMemberAdmin
                                      ? Icon(Icons.star, color: Colors.green) // ✅ Show admin star
                                      : null,
                            );
                          },
                        ),
            ),
            if (_isAdmin)
              ElevatedButton(
                onPressed: () {},
                child: Text("Add Member"),
              ),
            ElevatedButton(
              onPressed: _exitGroup,
              child: Text("Exit Group", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveDialog(String userId, String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Remove Member"),
        content: Text("Are you sure you want to remove $username from the group?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeMember(userId);
            },
            child: Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
