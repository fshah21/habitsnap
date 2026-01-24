import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chatScreen.dart';

class ChallengeDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> challenge;

  const ChallengeDetailsScreen({super.key, required this.challenge});

  Future<void> joinChallenge(String challengeId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Not logged in → handle gracefully
      print('User not logged in');
      return;
    }

    final uid = user.uid;

    final userChallengeRef = FirebaseFirestore.instance
        .collection('userchallenges')
        .doc(uid)
        .collection('challenges')
        .doc(challengeId);

    await userChallengeRef.set({
      'uid': uid,
      'joinedAt': FieldValue.serverTimestamp(),
      'status': 'active',
    });

    print('User joined challenge');
  }

  Future<void> _handleJoin(BuildContext context, Map<String, dynamic> challenge) async {
    print("Handle join");
    final challengeId = challenge['id'];

    await joinChallenge(challengeId);
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white, // white background
        contentPadding: const EdgeInsets.all(45), // optional padding
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🎉 You’re in!',
              textAlign: TextAlign.center, // center the text
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'You’ve joined the challenge.\nStay consistent and have fun!',
              textAlign: TextAlign.center, // center the body
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 42),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // close dialog
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Go to Challenge',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          challenge: challenge
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(challenge['title']),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Description
            Text(
              challenge['description'] ?? '',
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 16),

            /// Info row
            Row(
              children: [
                _infoChip('${challenge['duration']} days'),
                const SizedBox(width: 8),
                _infoChip('${challenge['participants']} participants'),
              ],
            ),

            const SizedBox(height: 24),

            /// Rules
            const Text(
              'Rules',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            ...(challenge['rules'] as List<dynamic>? ?? [])
                .map(
                  (rule) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(rule)),
                      ],
                    ),
                  ),
                ),

            const Spacer(),

            /// Join button
            Padding(
              padding: const EdgeInsets.only(bottom: 24), // adjust as needed
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _handleJoin(context, challenge),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Join Challenge',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text),
    );
  }
}
