// lib/services/chat_share.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class ChatShare {
  /// Share a structured ABCDE worksheet to the doctor's chat for current user.
  /// `worksheetMap` should be produced from ABCDEWorksheet.toMap()
  static Future<void> sendAbcdeWorksheetToDoctor(
    Map<String, dynamic> worksheetMap,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    final chatId = user.uid;
    final firestore = FirebaseFirestore.instance;
    final messagesRef = firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages');

    final summary = StringBuffer()
      ..writeln('🧠 ABCDE Worksheet shared by user')
      ..writeln()
      ..writeln('A — Activating event:')
      ..writeln(worksheetMap['activatingEvent'] ?? '')
      ..writeln()
      ..writeln('B — Belief:')
      ..writeln(worksheetMap['belief'] ?? '')
      ..writeln()
      ..writeln('C — Consequences:')
      ..writeln('• Emotional: ${worksheetMap['consequencesEmotional'] ?? ''}')
      ..writeln(
        '• Psychological: ${worksheetMap['consequencesPsychological'] ?? ''}',
      )
      ..writeln('• Physical: ${worksheetMap['consequencesPhysical'] ?? ''}')
      ..writeln(
        '• Behavioural: ${worksheetMap['consequencesBehavioural'] ?? ''}',
      )
      ..writeln()
      ..writeln('D — Dispute:')
      ..writeln(worksheetMap['dispute'] ?? '')
      ..writeln()
      ..writeln('E — Effects:')
      ..writeln('• Emotional: ${worksheetMap['emotionalEffect'] ?? ''}')
      ..writeln('• Psychological: ${worksheetMap['psychologicalEffect'] ?? ''}')
      ..writeln('• Physical: ${worksheetMap['physicalEffect'] ?? ''}')
      ..writeln('• Behavioural: ${worksheetMap['behaviouralEffect'] ?? ''}')
      ..writeln()
      ..writeln('Note: ${worksheetMap['note'] ?? ''}');

    final docId = const Uuid().v4();
    final ts = DateTime.now().millisecondsSinceEpoch;

    await messagesRef.doc(docId).set({
      'sender': 'user',
      'text': summary.toString(),
      'timestamp': ts,
      'approved': true, // user messages are visible immediately to doctor
      'type': 'worksheet',
      'worksheetType': 'ABCDE',
      'worksheetRaw': worksheetMap, // optional: structured backup for doctor UI
      'createdAt': FieldValue.serverTimestamp(),
      'sharedBy': user.uid,
    });

    // update chat index for doctor's overview (merge)
    await firestore.collection('chatIndex').doc(chatId).set({
      'userId': chatId,
      'userName': user.displayName ?? user.email ?? '',
      'lastMessage': 'Shared an ABCDE worksheet',
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
