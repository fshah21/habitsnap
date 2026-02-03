import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'challengeDetailsScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chatScreen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'profileScreen.dart';
import 'services/challengeService.dart';
import 'utils/challengeUtils.dart';

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  int _currentIndex = 0;
  Map<String, String> _usernamesCache = {};

  Stream<Set<String>> activeChallengeIdsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
      .collection('userchallenges')
      .doc(uid)
      .collection('challenges')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .where((doc) => doc['status'] == 'active')
            .map((doc) => doc.id)
            .toSet(),
      );
  }

  Stream<List<Map<String, dynamic>>> discoverChallengesStream() {
    return FirebaseFirestore.instance
        .collection('challenges')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'title': doc['title'],
          'description': doc['description'],
          'rules': doc['rules'],
          'participants': doc['participants'],
          'duration': doc['duration'],
        };
      }).toList();
    });
  }

  Future<void> submitProof(Map<String, dynamic> challenge) async {
    final picker = ImagePicker();
    try {
        final pickedFile = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 70,
        );

        if (pickedFile != null) {
          final imageFile = File(pickedFile.path);
          print('Image selected: ${pickedFile.path}');

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                challenge: challenge,
                preloadedImage: imageFile,
              ),
            ),
          );
        } else {
          print('No image selected.');
        }
      } catch (e) {
        print('Error picking image: $e');
      }
  }

  Future<void> joinChallenge(String challengeId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('userId');

    final userChallengeRef = FirebaseFirestore.instance
        .collection('userchallenges')
        .doc(uid)
        .collection('challenges')
        .doc(challengeId);

    final challengeRef = FirebaseFirestore.instance
      .collection('challenges')
      .doc(challengeId);

    // 🔒 Optional: prevent double join
    final existing = await userChallengeRef.get();
    if (existing.exists) return;

    // ✅ Batch write = atomic
    final batch = FirebaseFirestore.instance.batch();

    batch.set(userChallengeRef, {
      'joinedAt': FieldValue.serverTimestamp(),
      'status': 'active',
    });

    batch.update(challengeRef, {
      'participants': FieldValue.increment(1),
    });

    await batch.commit();

    print('User joined challenge + participant incremented');
  }

  Stream<List<Map<String, dynamic>>> joinedChallengesStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Stream.empty();
    }

    final userChallengesRef = FirebaseFirestore.instance
        .collection('userchallenges')
        .doc(uid)
        .collection('challenges');

    return userChallengesRef.snapshots().asyncMap((snapshot) async {
    if (snapshot.docs.isEmpty) return [];

    /// 1️⃣ Build a map: challengeId -> userChallengeData
    final Map<String, Map<String, dynamic>> userChallengeMap = {
      for (var doc in snapshot.docs)
        doc.id: doc.data(), // contains joinedAt, status, etc.
    };

    /// 2️⃣ Filter only active challenges
    final activeChallengeIds = userChallengeMap.entries
        .where((entry) => entry.value['status'] == 'active')
        .map((entry) => entry.key)
        .toList();

    if (activeChallengeIds.isEmpty) return [];

    // Firestore whereIn safety (max 10 IDs)
    if (activeChallengeIds.length > 10) {
      activeChallengeIds.length = 10;
    }

     /// 3️⃣ Fetch challenge details
    final challengesSnapshot = await FirebaseFirestore.instance
        .collection('challenges')
        .where(FieldPath.documentId, whereIn: activeChallengeIds)
        .get();

    /// 4️⃣ Merge challenge + userChallenge data
    return challengesSnapshot.docs.map((doc) {
      final userData = userChallengeMap[doc.id];

      return {
        'id': doc.id,
        'title': doc['title'],
        'description': doc['description'],
        'rules': doc['rules'],
        'participants': doc['participants'],
        'duration': doc['duration'],

        // 👇 USER-SPECIFIC
        'joinedAt': userData?['joinedAt'],
        'status': userData?['status'], // should be 'active'
      };
    }).toList();
  });
}


  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDiscoverTab(),
      _buildJoinedTab(),
    ];

    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid;

    String username = 'U';
    Color avatarColor = Colors.grey;

    if (uid != null) {
      avatarColor = getColorForUser(uid);
      username = _usernamesCache[uid] ?? 'U';

      if (!_usernamesCache.containsKey(uid)) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get()
            .then((doc) {
          if (doc.exists) {
            setState(() {
              _usernamesCache[uid] =
                  doc['username'] ?? 'User';
            });
          }
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Snap'),
        backgroundColor: Colors.yellow[700],
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: avatarColor,
              child: Text(
                username[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Joined',
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    return StreamBuilder<Set<String>>(
      stream: activeChallengeIdsStream(),
      builder: (context, joinedSnapshot) {
        if (joinedSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final joinedIds = joinedSnapshot.data ?? {};

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: discoverChallengesStream(),
          builder: (context, challengesSnapshot) {
            if (challengesSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!challengesSnapshot.hasData ||
                challengesSnapshot.data!.isEmpty) {
              return const Center(child: Text('No challenges found'));
            }

            final discoverChallenges = challengesSnapshot.data!
                .where((c) => !joinedIds.contains(c['id']))
                .toList();

            if (discoverChallenges.isEmpty) {
              return const Center(
                child: Text('You have joined all available challenges 🎉'),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: discoverChallenges.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return _buildChallengeCard(discoverChallenges[index], true);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDayStreakRow(Map<String, dynamic> challenge) {
    print("Build day streak row");
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return FutureBuilder<int>(
      future: ChallengeService.getStreak(
        challengeId: challenge['id'],
        uid: uid ?? '',
      ),
      builder: (context, snapshot) {
        final streak = snapshot.data ?? 0;

        final dayNumber = calculateDayNumber(
          joinedAt: (challenge['joinedAt'] as Timestamp).toDate(),
          totalDays: challenge['duration'],
        );

        return Row(
          children: [
            _statChip(
              icon: Icons.calendar_today,
              label: 'Day $dayNumber',
            ),
            const SizedBox(width: 10),
            _statChip(
              icon: Icons.local_fire_department,
              label: '$streak streak',
              iconColor: Colors.orange,
            ),
          ],
        );
      },
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    Color iconColor = Colors.black,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // Widget _buildChallengeCard(Map<String, dynamic> challenge, bool isDiscover) {
  //   print("Challenge $challenge");
  //   return Card(
  //     elevation: 4,
  //     shape: RoundedRectangleBorder(
  //       borderRadius: BorderRadius.circular(16),
  //     ),
  //     child: Padding(
  //       padding: const EdgeInsets.all(16),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           // 🔹 Top row: Image + Info
  //           Row(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               CircleAvatar(
  //                 radius: 30,
  //                 backgroundImage: AssetImage(
  //                   'assets/${challenge['id']}.jpg',
  //                 ),
  //               ),
  //               const SizedBox(width: 16),
  //               Expanded(
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       challenge['title'],
  //                       style: const TextStyle(
  //                         fontSize: 18,
  //                         fontWeight: FontWeight.bold,
  //                       ),
  //                     ),
  //                     const SizedBox(height: 6),
  //                     Text(
  //                       '${challenge['participants']} participants',
  //                       style: const TextStyle(color: Colors.grey),
  //                     ),
  //                     const SizedBox(height: 4),
  //                     Text(
  //                       'Duration: ${challenge['duration']} days',
  //                       style: const TextStyle(color: Colors.grey),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           ),

  //           const SizedBox(height: 12),

  //           if (!isDiscover && challenge['joinedAt'] != null)
  //             _buildDayStreakRow(challenge),

  //           const SizedBox(height: 16),

  //           // 🔹 Bottom row: Buttons
  //           Row(
  //             children: [
  //               if (!isDiscover)
  //                 Expanded(
  //                   child: ElevatedButton(
  //                     onPressed: () async {
  //                       // Submit proof
  //                       submitProof(challenge);
  //                     },
  //                     style: ElevatedButton.styleFrom(
  //                       backgroundColor: Colors.green,
  //                     ),
  //                     child: const Text(
  //                       'Submit Proof',
  //                       style: TextStyle(color: Colors.white),
  //                     ),
  //                   ),
  //                 ),

  //               // Always show this
  //               if (!isDiscover) const SizedBox(width: 12),
  //               Expanded(
  //                 child: OutlinedButton(
  //                   onPressed: () {
  //                     if (isDiscover) {
  //                       // Go to Challenge Details
  //                       Navigator.push(
  //                         context,
  //                         MaterialPageRoute(
  //                           builder: (_) => ChallengeDetailsScreen(
  //                             challenge: challenge,
  //                           ),
  //                         ),
  //                       );
  //                     } else {
  //                       // Go to Chat
  //                       Navigator.push(
  //                         context,
  //                         MaterialPageRoute(
  //                           builder: (_) => ChatScreen(
  //                             challenge: challenge
  //                           ),
  //                         ),
  //                       );
  //                     }
  //                   },
  //                   child: Text(isDiscover ? 'View Details' : 'Open Chat'),
  //                 ),
  //               ),
  //             ],
  //           )
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildChallengeCard(
      Map<String, dynamic> challenge,
      bool isDiscover,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias, // IMPORTANT
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔥 FULL-WIDTH IMAGE
          SizedBox(
            height: 160,
            width: double.infinity,
            child: Image.asset(
              'assets/${challenge['id']}.jpg',
              fit: BoxFit.cover,
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TITLE
                Text(
                  challenge['title'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                // META INFO
                Text(
                  '${challenge['participants']} participants',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  'Duration: ${challenge['duration']} days',
                  style: const TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 12),

                if (!isDiscover && challenge['joinedAt'] != null)
                  _buildDayStreakRow(challenge),

                const SizedBox(height: 16),

                // 🔘 BUTTONS
                Row(
                  children: [
                    if (!isDiscover)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            submitProof(challenge);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text(
                            'Submit Proof',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),

                    if (!isDiscover) const SizedBox(width: 12),

                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => isDiscover
                                  ? ChallengeDetailsScreen(
                                      challenge: challenge,
                                    )
                                  : ChatScreen(
                                      challenge: challenge,
                                    ),
                            ),
                          );
                        },
                        child: Text(
                          isDiscover ? 'View Details' : 'Open Chat',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinedTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: joinedChallengesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('You have not joined any challenges yet'),
          );
        }

        final challenges = snapshot.data!;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: challenges.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return _buildChallengeCard(challenges[index], false);
          },
        );
      },
    );
  }

}
