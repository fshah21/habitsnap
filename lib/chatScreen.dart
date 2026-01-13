import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ChatScreen extends StatefulWidget {
  final String challengeId;
  final String challengeTitle;

  const ChatScreen({
    super.key,
    required this.challengeId,
    required this.challengeTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final uid = FirebaseAuth.instance.currentUser!.uid;
  File? _selectedImage;
  int currentDay = 1;
  DateTime? joinedAt;

  @override
  void initState() {
    super.initState();
    loadJoinedAt();
  }

  Future<void> loadJoinedAt() async {
    final date = await getJoinedAt();
    final dayNumber = calculateDayNumber(
      joinedAt: joinedAt!,
      totalDays: 30,
    );
    setState(() {
      joinedAt = date;
      currentDay = dayNumber;
    });
  }

  int calculateDayNumber({
      required DateTime joinedAt,
      required int totalDays,
    }) {
      final now = DateTime.now();

      final start = DateTime(
        joinedAt.year,
        joinedAt.month,
        joinedAt.day,
      );

      final today = DateTime(
        now.year,
        now.month,
        now.day,
      );

      final day = today.difference(start).inDays + 1;

      return day.clamp(1, totalDays);
    }


  Future<DateTime?> getJoinedAt() async {
    final docId = '${uid}_${widget.challengeId}';

    final doc = await FirebaseFirestore.instance
        .collection('userChallenges')
        .doc(docId)
        .get();

    if (!doc.exists) return null;

    final data = doc.data()!;
    return (data['joinedAt'] as Timestamp).toDate();
  }

  Future<void> sendMessage({String? text}) async {
    print("In send message");
    if ((text == null || text.isEmpty) && _selectedImage == null) return;

    String? imageUrl;

    if (_selectedImage != null) {
      try {
        print('📤 Starting image upload...');

        final ref = FirebaseStorage.instance
            .ref()
            .child('challenge_proofs')
            .child(widget.challengeId)
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

        print('📁 Storage path: ${ref.fullPath}');

        final uploadTask = await ref.putFile(_selectedImage!);

        print('✅ Upload completed');
        print('📊 Bytes transferred: ${uploadTask.bytesTransferred}');
        print('📊 Total bytes: ${uploadTask.totalBytes}');

        imageUrl = await ref.getDownloadURL();
        print('🔗 Image URL: $imageUrl');
      } on FirebaseException catch (e) {
        print('❌ Firebase upload error');
        print('Code: ${e.code}');
        print('Message: ${e.message}');
      } catch (e, stackTrace) {
        print('❌ Unknown error during image upload');
        print(e);
        print(stackTrace);
      }
    }

    print("here");

    await FirebaseFirestore.instance
        .collection('challenges')
        .doc(widget.challengeId)
        .collection('messages')
        .add({
        'userId': uid,
        'text': text,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'createdAtLocal': Timestamp.now(),
    });

    print("done");

    _controller.clear();
    setState(() {
        _selectedImage = null;
    });
 }


  Future<void> pickImage() async {
    final picker = ImagePicker();
    try {
        final pickedFile = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 70,
        );

        if (pickedFile != null) {
          setState(() {
            _selectedImage = File(pickedFile.path);
          });
          print('Image selected: ${pickedFile.path}');
        } else {
          print('No image selected.');
        }
      } catch (e) {
        print('Error picking image: $e');
      }
  }

  Widget _challengeProgressBox({
    required int day,
    required int totalDays,
    required int streak,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Day $day / $totalDays',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '🔥 $streak-day streak',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.challengeTitle),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          _challengeProgressBox(
            day: currentDay,
            totalDays: 30,
            streak: 1,
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('challenges')
                  .doc(widget.challengeId)
                  .collection('messages')
                  .orderBy('createdAtLocal')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data =
                        messages[index].data() as Map<String, dynamic>;
                    final isMe = data['userId'] == uid;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.green[200]
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (data['imageUrl'] != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 6),
                                child: Image.network(
                                  data['imageUrl'],
                                  height: 150,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;

                                    return Container(
                                      height: 150,
                                      width: 150,
                                      alignment: Alignment.center,
                                      child: const CircularProgressIndicator(strokeWidth: 2),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 150,
                                      width: 150,
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.image_not_supported),
                                    );
                                  },
                                ),
                              ),
                            if (data['text'] != null)
                              Text(data['text']),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Input + Image Preview
          Column(
            children: [
              if (_selectedImage != null)
              Padding(
                padding: const EdgeInsets.only(
                  left: 200,
                  top: 6,
                  right: 10,
                  bottom: 6,
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 120,
                          maxHeight: 200, // good for portrait photos
                        ),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.contain, // PRESERVES RATIO
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: pickImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Send a message or proof...',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      sendMessage(text: _controller.text);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}