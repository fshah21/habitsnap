import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'goalScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

   @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleSignInAccount? _user;
  bool _loading = false;
  static const String privacyPolicyUrl = 'https://rectangular-ursinia-c6f.notion.site/2fde4ad88f4d80b5bdfae839aad997be';
  static const String termsOfUseUrl = 'https://rectangular-ursinia-c6f.notion.site/Terms-of-Use-for-HabitSnap-2fde4ad88f4d8027a43eed349c14bdc3';

  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();
  }

  // Generates a cryptographically secure random nonce
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  // Returns the SHA256 hash of the input string
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  Future<UserCredential?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      print('Apple ID Token: ${appleCredential.identityToken}');

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      final user = userCredential.user!;
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      final snapshot = await userDoc.get();

      if (!snapshot.exists) {
        await userDoc.set({
          'username': _generateRandomUsername(),
          'displayName':
              '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                  .trim(),
          'email': user.email ?? '',
          'photoUrl': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await getFcmToken();
      await getUserLocation();

      if (!mounted) return null;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GoalScreen()),
      );

      return userCredential;
    } catch (e) {
      print('🍎 Apple sign-in error: $e');
      return null;
    }
  }

  Future<String?> getFcmToken() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    String? fcmToken = await messaging.getToken();
    print("🔥 FCM TOKEN: $fcmToken");

    if (Platform.isIOS) {
      String? apnsToken = await messaging.getAPNSToken();
      print('APNS token: $apnsToken');

      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        return null;
      }

      FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'fcmToken': fcmToken});

      return fcmToken;
    }

    // final fcmToken = await messaging.getToken();
    // print("FCM Device Token: $fcmToken");

    return null;
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

            await getFcmToken();
            await getUserLocation();

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

  Future<Position?> getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services are disabled.");
      return null;
    }

    // Check for permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Location permissions are denied.");
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print("Location permissions are permanently denied.");
      return null;
    }

    // Get current position
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    print("User location: ${position.latitude}, ${position.longitude}");

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return null;
    }

    FirebaseFirestore.instance.collection('users').doc(uid).update({
      'location': {
        'latitude': position.latitude,
        'longitude': position.longitude,
      }
    });

    return position;
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final userCredential = await signInWithGoogle();
                    if (userCredential != null) {
                      print('Signed in as ${userCredential.user?.displayName}');
                    }
                  },
                  child: const Text(
                    'Sign in with Google',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),

                if (Platform.isIOS)
                  SizedBox(
                    width: 300,
                    height: 50,
                    child: SignInWithAppleButton(
                      onPressed: () async {
                        await signInWithApple();
                      },
                      style: SignInWithAppleButtonStyle.black,
                    ),
                  ),

                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => _openUrl(privacyPolicyUrl),
                          child: const Text(
                            'Privacy Policy',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const Text('  •  ', style: TextStyle(fontSize: 13)),
                        GestureDetector(
                          onTap: () => _openUrl(termsOfUseUrl),
                          child: const Text(
                            'Terms of Use',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
