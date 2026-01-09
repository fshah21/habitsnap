import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'challengeDetailsScreen.dart';

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  int _currentIndex = 0;

  /// 🔥 Firestore stream
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

  /// 🔍 DISCOVER TAB
  Widget _buildDiscoverTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: discoverChallengesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No challenges found'));
        }

        final challenges = snapshot.data!;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: challenges.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final challenge = challenges[index];

            return _buildChallengeCard(challenge);
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
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // Join logic next
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text(
                          'Join',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChallengeDetailsScreen(
                                challenge: challenge,
                              ),
                            ),
                          );
                        },
                        child: const Text('View'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 👥 JOINED TAB (temporary reuse)
  Widget _buildJoinedTab() {
    return _buildDiscoverTab();
  }
}
