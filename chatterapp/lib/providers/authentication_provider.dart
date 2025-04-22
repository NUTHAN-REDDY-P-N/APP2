import 'dart:io';
import 'package:chatterapp/constants/firestoreConstants.dart';
import 'package:chatterapp/models/user_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Status {
  uninitialized,
  authenticated,
  authenticating,
  authenticateError,
  authenticateException,
  authenticateCanceled,
}

class AuthProvider extends ChangeNotifier {
  final GoogleSignIn googleSignIn;
  final FirebaseAuth firebaseAuth;
  final FirebaseFirestore firebaseFirestore;
  final FirebaseStorage firebaseStorage;
  final SharedPreferences prefs;

  AuthProvider({
    required this.firebaseAuth,
    required this.googleSignIn,
    required this.firebaseFirestore,
    required this.firebaseStorage,
    required this.prefs,
  });

  Status _status = Status.uninitialized;
  Status get status => _status;
  String? get userFirebaseId => prefs.getString(FirestoreConstants.id);

  Future<bool> isLoggedIn() async {
    bool isLoggedIn = await googleSignIn.isSignedIn();
    return isLoggedIn && (prefs.getString(FirestoreConstants.id)?.isNotEmpty ?? false);
  }

  Future<String?> _uploadProfilePicture(String url, String userId) async {
    try {
      // Download the image
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      // Save to local temp file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$userId.jpg');
      await file.writeAsBytes(response.bodyBytes);

      // Upload to Firebase Storage
      final ref = firebaseStorage.ref().child('profile_pictures/$userId.jpg');
      await ref.putFile(file);

      // Get the download URL
      return await ref.getDownloadURL();
    } catch (e) {
      print("Error uploading profile picture: $e");
      return null;
    }
  }

  Future<bool> handleSignIn() async {
    _status = Status.authenticating;
    notifyListeners();
    final googleUser = await googleSignIn.signIn();

    if (googleUser == null) {
      _status = Status.authenticateCanceled;
      notifyListeners();
      return false;
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final firebaseUser = (await firebaseAuth.signInWithCredential(credential)).user;
    if (firebaseUser == null) {
      _status = Status.authenticateError;
      notifyListeners();
      return false;
    }

    final result = await firebaseFirestore
        .collection(FirestoreConstants.pathUserCollection)
        .where(FirestoreConstants.id, isEqualTo: firebaseUser.uid)
        .get();
    final documents = result.docs;

    String? profileUrl = firebaseUser.photoURL;
    if (profileUrl != null) {
      // Upload to Firebase Storage
      profileUrl = await _uploadProfilePicture(profileUrl, firebaseUser.uid);
    }

    if (documents.isEmpty) {
      // New user - save data to Firestore
      await firebaseFirestore.collection(FirestoreConstants.pathUserCollection).doc(firebaseUser.uid).set({
        FirestoreConstants.nickname: firebaseUser.displayName,
        FirestoreConstants.photoUrl: profileUrl ?? "",
        FirestoreConstants.id: firebaseUser.uid,
        FirestoreConstants.createdAt: DateTime.now().millisecondsSinceEpoch.toString(),
        FirestoreConstants.chattingWith: null,
      });
    } else {
      // Existing user - update profile picture in Firestore
      await firebaseFirestore.collection(FirestoreConstants.pathUserCollection).doc(firebaseUser.uid).update({
        FirestoreConstants.photoUrl: profileUrl ?? documents.first[FirestoreConstants.photoUrl],
      });
    }

    // Save to SharedPreferences
    await prefs.setString(FirestoreConstants.id, firebaseUser.uid);
    await prefs.setString(FirestoreConstants.nickname, firebaseUser.displayName ?? "");
    await prefs.setString(FirestoreConstants.photoUrl, profileUrl ?? "");

    _status = Status.authenticated;
    notifyListeners();
    return true;
  }

  void handleException() {
    _status = Status.authenticateException;
    notifyListeners();
  }

  Future<void> handleSignOut() async {
    _status = Status.uninitialized;
    await firebaseAuth.signOut();
    await googleSignIn.disconnect();
    await googleSignIn.signOut();
  }
}
