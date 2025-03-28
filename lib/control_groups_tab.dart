import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ControlGroupsTab extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _deleteGroup(BuildContext context, String groupId) async {
    try {
      await _firestore.collection('groups').doc(groupId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Group deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting group: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('groups').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No groups found.'));
        }

        var groups = snapshot.data!.docs;

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            var group = groups[index];
            Map<String, dynamic> groupData = group.data() as Map<String, dynamic>;

            String groupName = groupData.containsKey('groupName') ? groupData['groupName'] : 'Unnamed Group';
            String createdBy = groupData.containsKey('createdBy') ? groupData['createdBy'] : 'Unknown Creator';
            String lastMessage = groupData.containsKey('lastMessage') ? groupData['lastMessage'] : 'No messages yet';
            String lastMessageSender = groupData.containsKey('lastMessageSender') ? groupData['lastMessageSender'] : 'Unknown';
            Timestamp? lastMessageTimestamp = groupData.containsKey('lastMessageTimestamp') ? groupData['lastMessageTimestamp'] : null;
            String formattedTime = lastMessageTimestamp != null
                ? "${lastMessageTimestamp.toDate()}"
                : "No messages yet";

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                title: Text(groupName, style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Created by: $createdBy"),
                    Text("Last Message: $lastMessage"),
                    Text("Sent by: $lastMessageSender"),
                    Text("Time: $formattedTime"),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteGroup(context, group.id),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
