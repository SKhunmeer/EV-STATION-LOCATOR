// ignore_for_file: prefer_initializing_formals
import 'package:cloud_firestore/cloud_firestore.dart';

/// User-owned persistence. Aggregate station data is provider-owned and is
/// never writable by clients through this repository.
class FirestoreRepository {
  FirestoreRepository({FirebaseFirestore? firestore}) : _firestore = firestore;
  final FirebaseFirestore? _firestore;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _user(
    String uid,
    String collection,
  ) => firestore.collection('users').doc(uid).collection(collection);

  Future<void> saveVehicle(String uid, Map<String, dynamic> vehicle) => _user(
    uid,
    'vehicles',
  ).doc('primary').set({...vehicle, 'updatedAt': FieldValue.serverTimestamp()});
  Stream<QuerySnapshot<Map<String, dynamic>>> vehicles(String uid) =>
      _user(uid, 'vehicles').snapshots();
  Future<void> setFavourite(
    String uid,
    String stationId,
    Map<String, dynamic> station,
  ) => _user(
    uid,
    'favourites',
  ).doc(stationId).set({...station, 'savedAt': FieldValue.serverTimestamp()});
  Future<void> removeFavourite(String uid, String stationId) =>
      _user(uid, 'favourites').doc(stationId).delete();
  Future<void> addChoice(String uid, Map<String, dynamic> context) => _user(
    uid,
    'choices',
  ).add({...context, 'createdAt': FieldValue.serverTimestamp()});
  Future<List<Map<String, dynamic>>> recentChoices(String uid) async =>
      (await _user(
            uid,
            'choices',
          ).orderBy('createdAt', descending: true).limit(20).get()).docs
          .map((doc) => doc.data())
          .toList();
  Future<List<Map<String, dynamic>>> favourites(String uid) async =>
      (await _user(
        uid,
        'favourites',
      ).get()).docs.map((doc) => doc.data()).toList();
  Future<Map<String, dynamic>?> primaryVehicle(String uid) async {
    final snapshot = await _user(uid, 'vehicles').doc('primary').get();
    return snapshot.exists ? snapshot.data() : null;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> reviews(String stationId) =>
      firestore
          .collection('stations')
          .doc(stationId)
          .collection('reviews')
          .snapshots();
  Future<void> addReview(
    String uid,
    String stationId,
    int rating,
    String text,
  ) => firestore
      .collection('stations')
      .doc(stationId)
      .collection('reviews')
      .doc(uid)
      .set({
        'rating': rating,
        'text': text,
        'updatedAt': FieldValue.serverTimestamp(),
      });
}
