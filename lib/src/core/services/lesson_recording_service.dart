// lib/src/core/services/lesson_recording_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'logger_service.dart';

class LessonRecordingService {
  static final LessonRecordingService _instance = LessonRecordingService._internal();
  factory LessonRecordingService() => _instance;
  LessonRecordingService._internal();

  final _logger = FeatureLogger('LessonRecording');
  
  static const String _lessonsKey = 'recorded_lessons';
  static const String _audioFolderName = 'recorded_lessons';
  
  List<RecordedLesson> _lessons = [];
  StreamController<List<RecordedLesson>>? _lessonsController;
  
  bool _isInitialized = false;

  // Getters
  bool get isInitialized => _isInitialized;
  List<RecordedLesson> get lessons => List.unmodifiable(_lessons);
  Stream<List<RecordedLesson>> get lessonsStream => _lessonsController?.stream ?? const Stream.empty();

  /// Initialize the service
  Future<bool> initialize() async {
    try {
      _logger.i('Initializing lesson recording service...');
      
      _lessonsController = StreamController<List<RecordedLesson>>.broadcast();
      
      // Load existing lessons
      await _loadLessons();
      
      _isInitialized = true;
      _logger.i('Lesson recording service initialized with ${_lessons.length} lessons');
      
      return true;
    } catch (e) {
      _logger.e('Failed to initialize lesson recording service', error: e);
      return false;
    }
  }

  /// Load lessons from local storage
  Future<void> _loadLessons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lessonsJson = prefs.getStringList(_lessonsKey) ?? [];
      
      _lessons = lessonsJson
          .map((json) => RecordedLesson.fromJson(jsonDecode(json)))
          .toList();
      
      // Sort by date (newest first)
      _lessons.sort((a, b) => b.dateRecorded.compareTo(a.dateRecorded));
      
      // Only add to stream if controller exists and is not closed
      if (_lessonsController != null && !_lessonsController!.isClosed) {
        _lessonsController!.add(_lessons);
      }
      
      _logger.i('Loaded ${_lessons.length} lessons from storage');
    } catch (e) {
      _logger.e('Error loading lessons', error: e);
      _lessons = [];
    }
  }

  /// Save lessons to local storage
  Future<void> _saveLessons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lessonsJson = _lessons
          .map((lesson) => jsonEncode(lesson.toJson()))
          .toList();
      
      await prefs.setStringList(_lessonsKey, lessonsJson);
      
      // Only add to stream if controller exists and is not closed
      if (_lessonsController != null && !_lessonsController!.isClosed) {
        _lessonsController!.add(_lessons);
      }
      
      _logger.i('Saved ${_lessons.length} lessons to storage');
    } catch (e) {
      _logger.e('Error saving lessons', error: e);
    }
  }

  /// Get the audio directory path
  Future<String> _getAudioDirectoryPath() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${documentsDir.path}/$_audioFolderName');
      
      _logger.d('Documents directory: ${documentsDir.path}');
      _logger.d('Audio directory: ${audioDir.path}');
      
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
        _logger.i('Created audio directory: ${audioDir.path}');
      }
      
      // Test write permissions by creating a test file
      await _testWritePermissions(audioDir.path);
      
      return audioDir.path;
    } catch (e) {
      _logger.e('Error getting audio directory path', error: e);
      throw Exception('Cannot access audio storage directory: $e');
    }
  }

  /// Test if we can write to the audio directory
  Future<void> _testWritePermissions(String directoryPath) async {
    try {
      final testFile = File('$directoryPath/.test_write_permissions');
      await testFile.writeAsString('test');
      await testFile.delete();
      _logger.d('Write permissions confirmed for: $directoryPath');
    } catch (e) {
      _logger.e('No write permissions for directory: $directoryPath', error: e);
      throw Exception('No write permissions for audio storage directory');
    }
  }

  /// Start a new recording session
  Future<String> startRecording(String title, String category) async {
    try {
      if (!_isInitialized) {
        throw Exception('Service not initialized');
      }

      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final audioDir = await _getAudioDirectoryPath();
      final audioFilePath = '$audioDir/lesson_$id.wav';
      
      _logger.i('Started recording lesson: $title (ID: $id)');
      
      return audioFilePath;
    } catch (e) {
      _logger.e('Error starting recording', error: e);
      rethrow;
    }
  }

  /// Save a completed recording
  Future<RecordedLesson> saveRecording({
    required String title,
    required String category,
    required Duration duration,
    required String audioFilePath,
    String? transcript,
    String? summary,
  }) async {
    try {
      if (!_isInitialized) {
        throw Exception('Service not initialized');
      }

      final lesson = RecordedLesson(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        category: category,
        dateRecorded: DateTime.now(),
        duration: duration,
        audioFilePath: audioFilePath,
        transcript: transcript,
        summary: summary,
      );

      _lessons.insert(0, lesson); // Add to beginning (newest first)
      await _saveLessons();
      
      _logger.i('Saved lesson: ${lesson.title} (${lesson.duration.inMinutes}m ${lesson.duration.inSeconds % 60}s)');
      
      return lesson;
    } catch (e) {
      _logger.e('Error saving recording', error: e);
      rethrow;
    }
  }

  /// Delete a lesson
  Future<bool> deleteLesson(String lessonId) async {
    try {
      if (!_isInitialized) {
        throw Exception('Service not initialized');
      }

      final lessonIndex = _lessons.indexWhere((lesson) => lesson.id == lessonId);
      if (lessonIndex == -1) {
        _logger.w('Lesson not found: $lessonId');
        return false;
      }

      final lesson = _lessons[lessonIndex];
      
      // Delete audio file if it exists
      if (lesson.audioFilePath != null) {
        final audioFile = File(lesson.audioFilePath!);
        if (await audioFile.exists()) {
          await audioFile.delete();
          _logger.i('Deleted audio file: ${lesson.audioFilePath}');
        }
      }
      
      _lessons.removeAt(lessonIndex);
      await _saveLessons();
      
      _logger.i('Deleted lesson: ${lesson.title}');
      return true;
    } catch (e) {
      _logger.e('Error deleting lesson', error: e);
      return false;
    }
  }

  /// Get lessons by category
  List<RecordedLesson> getLessonsByCategory(String category) {
    if (category == 'All') {
      return lessons;
    }
    return _lessons.where((lesson) => lesson.category == category).toList();
  }

  /// Search lessons by title
  List<RecordedLesson> searchLessons(String query) {
    if (query.isEmpty) return lessons;
    
    final lowercaseQuery = query.toLowerCase();
    return _lessons.where((lesson) => 
        lesson.title.toLowerCase().contains(lowercaseQuery) ||
        lesson.category.toLowerCase().contains(lowercaseQuery) ||
        (lesson.transcript?.toLowerCase().contains(lowercaseQuery) ?? false)
    ).toList();
  }

  /// Get lesson by ID
  RecordedLesson? getLessonById(String id) {
    try {
      return _lessons.firstWhere((lesson) => lesson.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Update lesson details
  Future<bool> updateLesson(RecordedLesson updatedLesson) async {
    try {
      if (!_isInitialized) {
        throw Exception('Service not initialized');
      }

      final index = _lessons.indexWhere((lesson) => lesson.id == updatedLesson.id);
      if (index == -1) {
        _logger.w('Lesson not found for update: ${updatedLesson.id}');
        return false;
      }

      _lessons[index] = updatedLesson;
      await _saveLessons();
      
      _logger.i('Updated lesson: ${updatedLesson.title}');
      return true;
    } catch (e) {
      _logger.e('Error updating lesson', error: e);
      return false;
    }
  }

  /// Get total recording time
  Duration get totalRecordingTime {
    return _lessons.fold(Duration.zero, (total, lesson) => total + lesson.duration);
  }

  /// Get lessons count by category
  Map<String, int> get lessonCountByCategory {
    final counts = <String, int>{};
    for (final lesson in _lessons) {
      counts[lesson.category] = (counts[lesson.category] ?? 0) + 1;
    }
    return counts;
  }

  /// Dispose service
  Future<void> dispose() async {
    try {
      await _lessonsController?.close();
      _isInitialized = false;
      _logger.i('Lesson recording service disposed');
    } catch (e) {
      _logger.e('Error disposing lesson recording service', error: e);
    }
  }
}

/// Recorded lesson model
class RecordedLesson {
  final String id;
  final String title;
  final String category;
  final DateTime dateRecorded;
  final Duration duration;
  final String? audioFilePath;
  final String? transcript;
  final String? summary;

  RecordedLesson({
    required this.id,
    required this.title,
    required this.category,
    required this.dateRecorded,
    required this.duration,
    this.audioFilePath,
    this.transcript,
    this.summary,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'dateRecorded': dateRecorded.toIso8601String(),
      'duration': duration.inMilliseconds,
      'audioFilePath': audioFilePath,
      'transcript': transcript,
      'summary': summary,
    };
  }

  static RecordedLesson fromJson(Map<String, dynamic> json) {
    return RecordedLesson(
      id: json['id'],
      title: json['title'],
      category: json['category'],
      dateRecorded: DateTime.parse(json['dateRecorded']),
      duration: Duration(milliseconds: json['duration']),
      audioFilePath: json['audioFilePath'],
      transcript: json['transcript'],
      summary: json['summary'],
    );
  }

  RecordedLesson copyWith({
    String? title,
    String? category,
    DateTime? dateRecorded,
    Duration? duration,
    String? audioFilePath,
    String? transcript,
    String? summary,
  }) {
    return RecordedLesson(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      dateRecorded: dateRecorded ?? this.dateRecorded,
      duration: duration ?? this.duration,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      transcript: transcript ?? this.transcript,
      summary: summary ?? this.summary,
    );
  }
}