import 'package:chatterapp/constants/firestoreConstants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:async/async.dart';

class HomeProvider {
  final FirebaseFirestore firebaseFirestore;
  HomeProvider({required this.firebaseFirestore});

  Future<void> updateDataFirestore(
      String collectionPath, String path, Map<String, String> dataNeedUpdate) {
    return firebaseFirestore
        .collection(collectionPath)
        .doc(path)
        .update(dataNeedUpdate);
  }

  Stream<QuerySnapshot> getStreamFirestore(String currentUserId,
      String pathCollection, int limit, String? textSearch) {
    return firebaseFirestore.collection('users').snapshots();
  }
}
