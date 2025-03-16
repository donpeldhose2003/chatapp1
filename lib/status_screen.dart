import 'dart:typed_data'; // Needed for Web image upload
import 'package:flutter/foundation.dart' show kIsWeb; // Detects if running on Web
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

// Import `dart:io` only for mobile (exclude Web)
import 'dart:io' show File;

class StatusScreen extends StatefulWidget {
  @override
  _StatusScreenState createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _uploadStatus() async {
    final user = _auth.currentUser;

    if (user == null) {
      print("❌ No user logged in");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please log in to upload a status.")),
      );
      return;
    }

    try {
      print("✅ User: ${user.uid}");
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

      if (pickedFile == null) {
        print("⚠️ No image selected.");
        return;
      }

      setState(() {
        _isUploading = true;
      });

      print("✅ Picked file: ${pickedFile.path}");

      String fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = _storage.ref('statuses/$fileName');

      UploadTask uploadTask;
      String downloadUrl = "";

      if (kIsWeb) {
  print("🌐 Uploading image for Web...");
  Uint8List imageData = await pickedFile.readAsBytes();
  
  uploadTask = storageRef.putData(
    imageData,
    SettableMetadata(contentType: 'image/jpeg'),
  );

  uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
    print("📤 Upload Progress: ${snapshot.bytesTransferred}/${snapshot.totalBytes}");
  }, onError: (e) {
    print("❌ Upload Error: $e");
  });
}
 else {
        print("📱 Uploading image for Mobile...");
        File file = File(pickedFile.path);
        uploadTask = storageRef.putFile(file);
      }

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print("📤 Upload Progress: $progress%");
      }, onError: (e) {
        print("❌ Upload Error: $e");
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Upload failed: $e")));
      });

      // Wait for upload to complete
      TaskSnapshot snapshot = await uploadTask;
      downloadUrl = await snapshot.ref.getDownloadURL();

      print("✅ Uploaded! Download URL: $downloadUrl");

      await _firestore.collection('statuses').add({
        'userId': user.uid,
        'username': user.displayName ?? "Unknown",
        'mediaUrl': downloadUrl,
        'type': 'image',
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Status uploaded!")));

    } catch (e) {
      print("❌ Error uploading: $e");
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Error uploading: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Statuses")),
      body: Column(
        children: [
          if (_isUploading) LinearProgressIndicator(),
          ElevatedButton(
            onPressed: _uploadStatus,
            child: Text("Upload Status"),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('statuses')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("No statuses available"));
                }

                var statuses = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: statuses.length,
                  itemBuilder: (context, index) {
                    var data = statuses[index].data() as Map<String, dynamic>;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(data['mediaUrl']),
                      ),
                      title: Text(data['username']),
                      subtitle: Text("Posted a new status"),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}