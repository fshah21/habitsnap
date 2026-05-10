import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'homeScreen.dart';
import 'services/challengeService.dart';
import 'utils/challengeUtils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  Color avatarColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        setState(() {
          _userData = doc.data();
          avatarColor = getColorForUser(uid);
        });
      } else {
        setState(() {
          _userData = {};
        });
      }
    } catch (e) {
      print("PROFILE ERROR: $e");

      if (!mounted) return;

      setState(() {
        _userData = {};
      });
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    await (await SharedPreferences.getInstance()).clear();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final uid = user.uid;

      // Delete Firestore user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete();

    // =========================
    // DELETE USER CHALLENGES
    // userChallenges/{uid}/challenges/*
    // =========================

    final userChallengesRef = FirebaseFirestore.instance
        .collection('userChallenges')
        .doc(uid)
        .collection('challenges');

    final userChallengesSnapshot = await userChallengesRef.get();

    for (final doc in userChallengesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete parent userChallenges doc
    await FirebaseFirestore.instance
        .collection('userChallenges')
        .doc(uid)
        .delete();

    // =========================
    // DELETE USER MESSAGES
    // challenges/{challengeId}/messages/*
    // where userId == uid
    // =========================

    final challengesSnapshot = await FirebaseFirestore.instance
        .collection('challenges')
        .get();

    for (final challengeDoc in challengesSnapshot.docs) {
      final messagesSnapshot = await challengeDoc.reference
          .collection('messages')
          .where('userId', isEqualTo: uid)
          .get();

      for (final messageDoc in messagesSnapshot.docs) {
        await messageDoc.reference.delete();
      }
    }
      // Delete Firebase Auth account
      await user.delete();

      // Clear local storage
      await (await SharedPreferences.getInstance()).clear();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deleted successfully'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'Failed to delete account';

      if (e.code == 'requires-recent-login') {
        message =
            'Please log in again before deleting your account.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = _userData?['username'] ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: _userData == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: avatarColor,
                    child: Text(
                      username[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    username,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _signOut(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _deleteAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                      ),
                      child: const Text(
                        'Delete Account',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}