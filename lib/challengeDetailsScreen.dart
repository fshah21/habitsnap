import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chatScreen.dart';

class ChallengeDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> challenge;

  const ChallengeDetailsScreen({super.key, required this.challenge});

  Future<void> joinChallenge(String challengeId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;

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

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final challengeId = challenge['id'];
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
          if (uid != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('userchallenges')
                    .doc(uid)
                    .collection('challenges')
                    .doc(challengeId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(); // or loader if you want
                  }

                  final doc = snapshot.data!;
                  final isActive =
                      doc.exists && doc['status'] == 'active';

                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (isActive) {
                          await leaveChallenge(challengeId);
                          if (!context.mounted) return;
                          Navigator.pop(context); // go back after leaving
                        } else {
                          await _handleJoin(context, challenge);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isActive ? Colors.red : Colors.green,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        isActive ? 'Leave Challenge' : 'Join Challenge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
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
