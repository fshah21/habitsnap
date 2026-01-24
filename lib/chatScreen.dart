import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'utils/challengeUtils.dart';
import 'services/challengeService.dart';
import 'challengeDetailsScreen.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> challenge;
  final File? preloadedImage;

  const ChatScreen({
    super.key,
    required this.challenge,
    this.preloadedImage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  Map<String, String> _usernamesCache = {};
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final userEmail = FirebaseAuth.instance.currentUser!.email;
  File? _selectedImage;
  bool _isUploading = false;
  int currentDay = 1;
  int streak = 1;
  DateTime? joinedAt;
  final ScrollController _scrollController = ScrollController();
  late final Stream<QuerySnapshot> _proofsStream;
  bool _showOnlyMine = false;

  @override
  void initState() {
    super.initState();
    _proofsStream = FirebaseFirestore.instance
      .collection('challenges')
      .doc(widget.challenge['id'])
      .collection('messages')
      .where('imageUrl', isNull: false)
      .orderBy('createdAtLocal', descending: true)
      .snapshots();
    loadJoinedAt();
    if (widget.preloadedImage != null) {
      _selectedImage = widget.preloadedImage;
    }
  }

  Future<void> leaveChallenge(String challengeId) async {
    print("Leave challenge");
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final userChallengeRef = FirebaseFirestore.instance
        .collection('userchallenges')
        .doc(uid)
        .collection('challenges')
        .doc(challengeId);

    final doc = await userChallengeRef.get();
    if (!doc.exists) return;

    await userChallengeRef.update({
      'status': 'inactive',
      'leftAt': FieldValue.serverTimestamp(),
    });

    print('User $uid left challenge $challengeId');

    // Optional: decrement participant count in challenge document
    final challengeRef = FirebaseFirestore.instance
        .collection('challenges')
        .doc(challengeId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(challengeRef);
      if (!snap.exists) return;

      final participants = snap['participants'] ?? 0;
      transaction.update(challengeRef, {
        'participants': participants > 0 ? participants - 1 : 0,
      });
    });

    print('Participant count updated');
  }

  Future<File> compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,        // 👈 key control (60–75 ideal)
      minWidth: 1080,     // 👈 limits resolution
    );

    return File(compressed!.path);
  }

  String getInitialsFromEmail(String email) {
    if (email.isEmpty) return '?';
    final atIndex = email.indexOf('@');
    if (atIndex <= 0) return email[0].toUpperCase();
    return email[0].toUpperCase();
  }

  Future<void> _showLeaveDialog(BuildContext context, String challengeId) async {
    // Show confirmation dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white, // white background
        contentPadding: const EdgeInsets.all(45),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '⚠️ Leave Challenge?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Are you sure you want to leave this challenge?\nYou will lose your current streak and progress.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 42),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // close dialog without leaving
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop(); // close dialog
                      await leaveChallenge(challengeId); // handle leaving
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('You left the challenge'),
                        ),
                      );

                      // Optionally navigate back to Discover or My Challenges
                      Navigator.of(context).pop(); 
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Leave',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> loadJoinedAt() async {
    final date = await getJoinedAt();
    if (date == null) return;
    final dayNumber = calculateDayNumber(
      joinedAt: date,
      totalDays: 30,
    );
    final userStreak = await ChallengeService.getStreak(challengeId: widget.challenge['id'], uid: uid);
      setState(() {
        joinedAt = date;
        currentDay = dayNumber;
        streak = userStreak;
      });
  }

  String formatChatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);

    final difference = today.difference(messageDay).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      // Wednesday, Monday, etc.
      return DateFormat('EEEE').format(messageDay);
    } else {
      // Jan 1, 2026
      return DateFormat('MMM d, yyyy').format(messageDay);
    }
  }
  
  Future<DateTime?> getJoinedAt() async {
    final challengeDoc = await FirebaseFirestore.instance
        .collection('userchallenges') // top-level collection
        .doc(uid)                     // user's document
        .collection('challenges')     // subcollection
        .doc(widget.challenge['id'])      // challenge document
        .get();

    if (!challengeDoc.exists) return null;

    final data = challengeDoc.data()!;
    print('Challenge data: $data');

    return (data['joinedAt'] as Timestamp).toDate();
  }

  Future<void> sendMessage({String? text}) async {
    print("In send message");
    if ((text == null || text.isEmpty) && _selectedImage == null) return;

    String? imageUrl;

    if (_selectedImage != null) {
      setState(() => _isUploading = true);
      try {
        print('📤 Starting image upload...');

        final compressedImage = await compressImage(_selectedImage!);

        print(
          '📉 Original: ${await _selectedImage!.length()} bytes | '
          'Compressed: ${await compressedImage.length()} bytes'
        );

        final ref = FirebaseStorage.instance
            .ref()
            .child('challenge_proofs')
            .child(widget.challenge['id'])
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

        print('📤 Uploading compressed image...');
        final uploadTask = await ref.putFile(compressedImage);

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
      } finally {
        setState(() => _isUploading = false);
      }
    }

    print("here");

    await FirebaseFirestore.instance
        .collection('challenges')
        .doc(widget.challenge['id'])
        .collection('messages')
        .add({
        'userId': uid,
        'userEmail': userEmail,
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
    loadJoinedAt();
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
      margin: const EdgeInsets.symmetric(horizontal: 12),
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
            '🔥 $streak',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateSeparator(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedImage != null && !_isUploading)
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
                      maxHeight: 200,
                    ),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.contain,
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

        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Row(
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
              _isUploading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () {
                        sendMessage(text: _controller.text);
                      },
                    ),
            ],
          ),
        ),
      ],
    );  
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        /// 🔹 CHAT LIST
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('challenges')
                .doc(widget.challenge['id'])
                .collection('messages')
                .orderBy('createdAtLocal')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data!.docs;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final data =
                      messages[index].data() as Map<String, dynamic>;

                  final currentTime =
                      (data['createdAtLocal'] as Timestamp).toDate();

                  final isMe = data['userId'] == uid;
                  final avatarColor =
                      getColorForUser(data['userId']);
                  final userId = data['userId'];

                  String username =
                      _usernamesCache[userId] ?? 'User';

                  if (!_usernamesCache.containsKey(userId)) {
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .get()
                        .then((doc) {
                      if (doc.exists) {
                        setState(() {
                          _usernamesCache[userId] =
                              doc['username'] ?? 'User';
                        });
                      }
                    });
                  }

                  return Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: avatarColor,
                            child: Text(
                              username[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Container(
                        margin: EdgeInsets.only(
                          left: isMe ? 0 : 22,
                          right: isMe ? 22 : 0,
                        ),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.green[200]
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            if (data['imageUrl'] != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 6),
                                child: SizedBox(
                                  height: 160,
                                  width: 100,
                                  child: CachedNetworkImage(
                                    imageUrl: data['imageUrl'],
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[300],
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.broken_image),
                                    ),
                                  ),
                                ),
                              ),
                            if (data['text'] != null &&
                                data['text']
                                    .toString()
                                    .isNotEmpty)
                              Text(data['text']),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),
                    ],
                  );
                },
              );
            },
          ),
        ),

        /// 🔹 INPUT BAR (fixed at bottom)
        _buildChatInput(),
      ],
    );
  }

  Widget _buildProofTab() {
  print("In proof tab");
  return Column(
    children: [
      // 🔹 Toggle to show only my snaps
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('My Snaps'),
            Switch(
              value: _showOnlyMine,
              onChanged: (val) {
                setState(() {
                  _showOnlyMine = val;
                });
              },
            ),
          ],
        ),
      ),

      // 🔹 Grid of snaps
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: _showOnlyMine
              ? FirebaseFirestore.instance
                  .collection('challenges')
                  .doc(widget.challenge['id'])
                  .collection('messages')
                  .where('imageUrl', isNull: false)
                  .where('userId', isEqualTo: uid)
                  .orderBy('createdAtLocal', descending: true)
                  .snapshots()
              : _proofsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Check for errors
            if (snapshot.hasError) {
              print('Error in StreamBuilder: ${snapshot.error}');
              return Center(
                child: Text(
                  'Something went wrong 😢\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  _showOnlyMine
                      ? 'You have not uploaded any snaps yet 📸'
                      : 'No snaps yet 📸\nBe the first to upload!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              );
            }

            final proofs = snapshot.data!.docs;

            return GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: proofs.length,
              itemBuilder: (context, index) {
                final data = proofs[index].data() as Map<String, dynamic>;
                final imageUrl = data['imageUrl'] as String?;
                if (imageUrl == null || imageUrl.isEmpty) {
                  return const SizedBox.shrink();
                }

                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.challenge['title']),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'details') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChallengeDetailsScreen(
                      challenge: widget.challenge,
                    ),
                  ),
                );
              } else if (value == 'leave') {
                _showLeaveDialog(context, widget.challenge['id']); // confirmation dialog
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'details',
                child: Text('Challenge Details'),
              ),
              const PopupMenuItem(
                value: 'leave',
                child: Text(
                  'Leave Challenge',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
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
            streak: streak,
          ),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Chat'),
                      Tab(text: 'Snaps'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildChatTab(),
                        _buildProofTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
        ],
      ),
    );
  }
}