// 파일 목적: Interviewer Repository 구현

import 'package:oral_record_agent/src/data/models/interviewer.dart';
import 'package:hive_flutter/hive_flutter.dart';

abstract class InterviewerRepository {
  Future<String> createInterviewer(Interviewer interviewer);
  Future<Interviewer?> getInterviewer(String id);
  Future<List<Interviewer>> getAllInterviewers();
  Future<void> updateInterviewer(String id, Interviewer interviewer);
  Future<void> deleteInterviewer(String id);
}

class HiveInterviewerRepository implements InterviewerRepository {
  final Box<Interviewer> _interviewerBox;

  HiveInterviewerRepository(this._interviewerBox);

  @override
  Future<String> createInterviewer(Interviewer interviewer) async {
    try {
      await _interviewerBox.put(interviewer.id, interviewer);
      return interviewer.id;
    } catch (e) {
      throw Exception('Failed to create interviewer: $e');
    }
  }

  @override
  Future<Interviewer?> getInterviewer(String id) async {
    try {
      return _interviewerBox.get(id);
    } catch (e) {
      throw Exception('Failed to get interviewer: $e');
    }
  }

  @override
  Future<List<Interviewer>> getAllInterviewers() async {
    try {
      return _interviewerBox.values.toList();
    } catch (e) {
      throw Exception('Failed to get all interviewers: $e');
    }
  }

  @override
  Future<void> updateInterviewer(String id, Interviewer interviewer) async {
    try {
      await _interviewerBox.put(id, interviewer);
    } catch (e) {
      throw Exception('Failed to update interviewer: $e');
    }
  }

  @override
  Future<void> deleteInterviewer(String id) async {
    try {
      await _interviewerBox.delete(id);
    } catch (e) {
      throw Exception('Failed to delete interviewer: $e');
    }
  }
}
