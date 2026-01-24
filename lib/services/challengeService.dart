import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengeService {
  static Future<int> getStreak({
    required String challengeId,
    required String uid,
  }) async {
    final messages = await FirebaseFirestore.instance
        .collection('challenges')
        .doc(challengeId)
        .collection('messages')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAtLocal', descending: true)
        .get();

    int count = 0;
    DateTime? lastDay;

    for (var doc in messages.docs) {
      final createdAt =
          (doc['createdAtLocal'] as Timestamp).toDate();
      final day =
          DateTime(createdAt.year, createdAt.month, createdAt.day);

      if (lastDay == null) {
        lastDay = day;
        count++;
      } else {
        final diff = lastDay.difference(day).inDays;
        if (diff == 1) {
          count++;
          lastDay = day;
        } else if (diff == 0) {
          continue;
        } else {
          break;
        }
      }
    }
    return count;
  }
}
