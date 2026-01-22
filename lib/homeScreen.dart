import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'goalScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

   @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleSignInAccount? _user;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();
  }

  Future<void> _initializeGoogleSignIn() async {
    // Initialize and listen to authentication events
    await GoogleSignIn.instance.initialize();
    
    GoogleSignIn.instance.authenticationEvents.listen(
      (event) {
        setState(() {
          _user = switch (event) {
            GoogleSignInAuthenticationEventSignIn() => event.user,
            GoogleSignInAuthenticationEventSignOut() => null,
          };
        });
      },
    );
  }

  Future<UserCredential?> signInWithGoogle() async {
    setState(() => _loading = true);
    try {
        // Check if platform supports authenticate
        if (GoogleSignIn.instance.supportsAuthenticate()) {
            final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate(scopeHint: ['email']);
            if (googleUser == null) {
                // User canceled
                setState(() => _loading = false);
                return null;
            }

            final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

            final credential = GoogleAuthProvider.credential(
                idToken: googleAuth.idToken ?? '',
            );

            // Sign in to Firebase
            UserCredential userCredential =
                await FirebaseAuth.instance.signInWithCredential(credential);

            final userId = userCredential.user!.uid;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('userId', userId);

            print('Signed in as ${userCredential.user?.displayName}');

            // Check if user exists in Firestore
            final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
            final docSnapshot = await userDoc.get();

            if (!docSnapshot.exists) {
              // Generate random username
              final randomUsername = _generateRandomUsername();

              await userDoc.set({
                'username': randomUsername,
                'displayName': userCredential.user?.displayName ?? '',
                'email': userCredential.user?.email ?? '',
                'photoUrl': userCredential.user?.photoURL ?? '',
                'createdAt': FieldValue.serverTimestamp(),
              });

              print('New user created with username: $randomUsername');
            }

            // Navigate to GoalScreen
            if (!mounted) return null;
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const GoalScreen()),
            );
        } else {
        // Handle web platform differently
        print('This platform requires platform-specific sign-in UI');
        }
    } catch (e) {
        print('Sign-in error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // Random username generator
  String _generateRandomUsername() {
    const adjectives = ['Happy', 'Swift', 'Clever', 'Brave', 'Quiet', 'Lucky'];
    const nouns = ['Tiger', 'Falcon', 'Lion', 'Fox', 'Bear', 'Wolf'];
    final rand = Random();
    final adjective = adjectives[rand.nextInt(adjectives.length)];
    final noun = nouns[rand.nextInt(nouns.length)];
    final number = rand.nextInt(999);
    return '$adjective$noun$number';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFC00),
      body: Column(
        children: [
          Expanded(
            flex: 7,
            child: Center(
              child: Image.asset(
                'assets/habitsnap.png',
                width: 300,
                height: 300,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    fixedSize: const Size(300, 50),
                  ),
                  onPressed: () async {
                    final userCredential = await signInWithGoogle();
                    if (userCredential != null) {
                      print('Signed in as ${userCredential.user?.displayName}');
                    }
                  },
                  child: const Text(
                    'CONTINUE WITH GOOGLE',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
