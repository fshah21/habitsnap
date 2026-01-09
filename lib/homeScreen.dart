import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'goalScreen.dart';

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

            print('Signed in as ${userCredential.user?.displayName}');

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow,
      body: Column(
        children: [
          Expanded(
            flex: 7,
            child: Center(child: Container()),
          ),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    fixedSize: const Size(400, 50),
                  ),
                  onPressed: () async {
                    final userCredential = await signInWithGoogle();
                    if (userCredential != null) {
                      // Successfully signed in
                      print('Signed in as ${userCredential.user?.displayName}');
                      // Navigate to next screen, e.g., OnboardingScreen
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
