import 'dart:io';

import 'package:chatterapp/constants/firestoreConstants.dart';
import 'package:chatterapp/main.dart' hide FirebaseStorage;
import 'package:chatterapp/models/message_chat.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatProvider {
  final SharedPreferences prefs;
  final FirebaseStorage firebaseStorage;
  final FirebaseFirestore firebaseFirestore;

  ChatProvider(
      {required this.firebaseFirestore,
      required this.firebaseStorage,
      required this.prefs});

  UploadTask uploadFile(File image, String fileName) {
    Reference reference = firebaseStorage.ref().child(fileName);
    UploadTask uploadTask = reference.putFile(image);
    return uploadTask;
  }

  Future<void> updateDataFirestore(String collectionPath, String docPath,
      Map<String, dynamic> dataNeedUpdate) {
    return firebaseFirestore
        .collection(collectionPath)
        .doc(docPath)
        .update(dataNeedUpdate);
  }

  Stream<QuerySnapshot> getChatStream(String groupChatId, int limit) {
    return firebaseFirestore
        .collection(FirestoreConstants.pathMessageCollection)
        .doc(groupChatId)
        .collection(groupChatId)
        .orderBy(FirestoreConstants.timestamp, descending: true)
        .limit(limit)
        .snapshots();
  }

  void messageMetaData(
      String groupChatId, String currentUserId, String peerId) {
    final FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;

    final userRef = firebaseFirestore.collection('chats');

    // Append groupChatId to both users' chat list
    userRef.doc(currentUserId).set({
      "chatIds": FieldValue.arrayUnion([peerId]) // Add without duplicates
    }, SetOptions(merge: true));

    userRef.doc(peerId).set({
      "chatIds": FieldValue.arrayUnion([currentUserId])
    }, SetOptions(merge: true));
  }

  void sendMessage(String content, int type, String currentUserId,
      String peerId, String groupChatId) {
    final documentReference = firebaseFirestore
        .collection(FirestoreConstants.pathMessageCollection)
        .doc(groupChatId)
        .collection(groupChatId)
        .doc(DateTime.now().millisecondsSinceEpoch.toString());

    final messageChat = MessageChat(
      idFrom: currentUserId,
      idTo: peerId,
      timestamp: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      type: type,
    );

    FirebaseFirestore.instance.runTransaction((transaction) async {
      transaction.set(
        documentReference,
        messageChat.toJson(),
      );
    });
  }
}
