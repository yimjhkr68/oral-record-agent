// 파일 목적: InterviewSession Repository 구현

import 'package:oral_record_agent/src/data/models/interview_session.dart';
import 'package:hive_flutter/hive_flutter.dart';

abstract class InterviewSessionRepository {
  Future<String> createSession(InterviewSession session);
  Future<InterviewSession?> getSession(String id);
  Future<List<InterviewSession>> getAllSessions();
  Future<void> updateSession(String id, InterviewSession session);
  Future<void> deleteSession(String id);
  Future<List<InterviewSession>> getSessionsByNarrator(String narratorId);
}

class HiveInterviewSessionRepository implements InterviewSessionRepository {
  final Box<InterviewSession> _sessionBox;

  HiveInterviewSessionRepository(this._sessionBox);

  @override
  Future<String> createSession(InterviewSession session) async {
    try {
      await _sessionBox.put(session.id, session);
      return session.id;
    } catch (e) {
      throw Exception('Failed to create session: $e');
    }
  }

  @override
  Future<InterviewSession?> getSession(String id) async {
    try {
      return _sessionBox.get(id);
    } catch (e) {
      throw Exception('Failed to get session: $e');
    }
  }

  @override
  Future<List<InterviewSession>> getAllSessions() async {
    try {
      return _sessionBox.values.toList();
    } catch (e) {
      throw Exception('Failed to get all sessions: $e');
    }
  }

  @override
  Future<void> updateSession(String id, InterviewSession session) async {
    try {
      await _sessionBox.put(id, session);
    } catch (e) {
      throw Exception('Failed to update session: $e');
    }
  }

  @override
  Future<void> deleteSession(String id) async {
    try {
      await _sessionBox.delete(id);
    } catch (e) {
      throw Exception('Failed to delete session: $e');
    }
  }

  @override
  Future<List<InterviewSession>> getSessionsByNarrator(
      String narratorId) async {
    try {
      return _sessionBox.values
          .where((s) => s.narratorId == narratorId)
          .toList();
    } catch (e) {
      throw Exception('Failed to get sessions by narrator: $e');
    }
  }
}
