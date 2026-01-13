import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'challengeDetailsScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chatScreen.dart';

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  int _currentIndex = 0;

  Stream<Set<String>> joinedChallengeIdsStream() {
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
          (snapshot) => snapshot.docs.map((doc) => doc.id).toSet(),
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

  Future<void> joinChallenge(String challengeId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('userId');

    final userChallengeRef = FirebaseFirestore.instance
        .collection('userchallenges')
        .doc(uid)
        .collection('challenges')
        .doc(challengeId);

    await userChallengeRef.set({
      'joinedAt': FieldValue.serverTimestamp(),
      'status': 'active',
    });

    print('User joined challenge');
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

      final challengeIds = snapshot.docs.map((d) => d.id).toList();

      // Firestore whereIn limit safety
      if (challengeIds.length > 10) {
        challengeIds.length = 10;
      }

      final challengesSnapshot = await FirebaseFirestore.instance
          .collection('challenges')
          .where(FieldPath.documentId, whereIn: challengeIds)
          .get();

      return challengesSnapshot.docs.map((doc) {
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


  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDiscoverTab(),
      _buildJoinedTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('HabitBuddy'),
        backgroundColor: Colors.yellow[700],
        actions: [
          IconButton(
            icon: const CircleAvatar(
              radius: 20,
              backgroundImage: AssetImage('assets/user.jpg'),
            ),
            onPressed: () {
              // Profile screen later
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
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
      stream: joinedChallengeIdsStream(),
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
                return _buildChallengeCard(discoverChallenges[index]);
              },
            );
          },
        );
      },
    );
  }

  /// 🧩 CHALLENGE CARD (clean separation)
  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundImage: AssetImage('assets/user.jpg'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    challenge['title'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
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
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // Navigate to proof upload
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text(
                          'Submit Proof',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                challengeId: challenge['id'],
                                challengeTitle: challenge['title'],
                              ),
                            ),
                          );
                        },
                        child: const Text('Open Chat'),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
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
            return _buildChallengeCard(challenges[index]);
          },
        );
      },
    );
  }

}
