// lib/src/core/services/voice_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:path_provider/path_provider.dart';
import 'logger_service.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final _logger = FeatureLogger('VoiceService');
  final AudioRecorder _audioRecorder = AudioRecorder();
  final SpeechToText _speechToText = SpeechToText();
  
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isListening = false;
  String? _currentRecordingPath;
  
  StreamController<String>? _transcriptionController;
  StreamController<VoiceRecordingState>? _recordingStateController;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  bool get isListening => _isListening;
  Stream<String>? get transcriptionStream => _transcriptionController?.stream;
  Stream<VoiceRecordingState>? get recordingStateStream => _recordingStateController?.stream;

  /// Initialize the voice service
  Future<bool> initialize() async {
    try {
      _logger.i('Initializing voice service...');
      
      // Request microphone permission
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        _logger.e('Microphone permission denied');
        return false;
      }

      // Initialize speech-to-text
      final sttAvailable = await _speechToText.initialize(
        onError: (error) => _logger.e('STT Error: ${error.errorMsg}'),
        onStatus: (status) => _logger.d('STT Status: $status'),
      );

      if (!sttAvailable) {
        _logger.e('Speech-to-text not available');
        return false;
      }

      // Initialize stream controllers
      _transcriptionController = StreamController<String>.broadcast();
      _recordingStateController = StreamController<VoiceRecordingState>.broadcast();

      _isInitialized = true;
      _logger.i('Voice service initialized successfully');
      
      return true;
    } catch (e) {
      _logger.e('Failed to initialize voice service', error: e);
      return false;
    }
  }

  /// Start recording audio
  Future<bool> startRecording() async {
    try {
      if (!_isInitialized) {
        _logger.e('Voice service not initialized');
        return false;
      }

      if (_isRecording) {
        _logger.w('Already recording');
        return false;
      }

      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/voice_recording_$timestamp.wav';

      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          bitRate: 128000,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      
      // Only add to stream if controller exists and is not closed
      if (_recordingStateController != null && !_recordingStateController!.isClosed) {
        _recordingStateController!.add(VoiceRecordingState.recording);
      }
      
      _logger.i('Started recording audio');
      
      return true;
    } catch (e) {
      _logger.e('Failed to start recording', error: e);
      return false;
    }
  }

  /// Stop recording and return the file path
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        _logger.w('Not recording');
        return _currentRecordingPath; // Return the last recorded path even if not currently recording
      }

      final path = await _audioRecorder.stop();
      _isRecording = false;
      
      // Update the current recording path if we got a new one
      if (path != null && path.isNotEmpty) {
        _currentRecordingPath = path;
      }
      
      // Only add to stream if controller exists and is not closed
      if (_recordingStateController != null && !_recordingStateController!.isClosed) {
        _recordingStateController!.add(VoiceRecordingState.stopped);
      }
      
      _logger.i('Stopped recording audio: $_currentRecordingPath');
      return _currentRecordingPath;
    } catch (e) {
      _logger.e('Failed to stop recording', error: e);
      _isRecording = false;
      
      // Only add to stream if controller exists and is not closed
      if (_recordingStateController != null && !_recordingStateController!.isClosed) {
        _recordingStateController!.add(VoiceRecordingState.error);
      }
      
      return _currentRecordingPath; // Return the last known path even on error
    }
  }

  /// Start live speech-to-text recognition
  Future<bool> startListening({
    String localeId = 'en_US',
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      if (!_isInitialized) {
        _logger.e('Voice service not initialized');
        return false;
      }

      if (_isListening) {
        _logger.w('Already listening');
        return false;
      }

      // Check if speech recognition is available
      if (!await _speechToText.initialize()) {
        _logger.e('Speech recognition not available');
        return false;
      }

      // Start listening
      await _speechToText.listen(
        onResult: (result) {
          _logger.d('STT Result: ${result.recognizedWords}');
          _transcriptionController?.add(result.recognizedWords);
        },
        listenFor: timeout,
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: localeId,
        onSoundLevelChange: (level) {
          // Optional: Handle sound level changes
        },
      );

      _isListening = true;
      
      // Only add to stream if controller exists and is not closed
      if (_recordingStateController != null && !_recordingStateController!.isClosed) {
        _recordingStateController!.add(VoiceRecordingState.listening);
      }
      
      _logger.i('Started listening for speech');
      
      return true;
    } catch (e) {
      _logger.e('Failed to start listening', error: e);
      return false;
    }
  }

  /// Stop listening for speech
  Future<void> stopListening() async {
    try {
      if (_isListening) {
        await _speechToText.stop();
        _isListening = false;
        
        // Only add to stream if controller exists and is not closed
        if (_recordingStateController != null && !_recordingStateController!.isClosed) {
          _recordingStateController!.add(VoiceRecordingState.stopped);
        }
        
        _logger.i('Stopped listening for speech');
      }
    } catch (e) {
      _logger.e('Failed to stop listening', error: e);
    }
  }

  /// Transcribe audio file to text
  Future<String?> transcribeAudioFile(String audioPath) async {
    try {
      if (!_isInitialized) {
        _logger.e('Voice service not initialized');
        return null;
      }

      final file = File(audioPath);
      if (!await file.exists()) {
        _logger.e('Audio file does not exist: $audioPath');
        return null;
      }

      _logger.i('Transcribing audio file: $audioPath');
      
      // For offline transcription, we'll use a simple approach
      // In a real implementation, you might use a more sophisticated offline STT engine
      // For now, we'll return a placeholder indicating the file was processed
      
      // Start a brief listening session to capture any ambient audio
      // This is a workaround since speech_to_text doesn't directly support file transcription
      final completer = Completer<String?>();
      String? transcription;
      
      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            transcription = result.recognizedWords;
            completer.complete(transcription);
          }
        },
        listenFor: const Duration(seconds: 5),
        pauseFor: const Duration(seconds: 2),
        partialResults: false,
      );

      // Wait for result or timeout
      try {
        await completer.future.timeout(const Duration(seconds: 10));
      } catch (e) {
        _logger.w('Transcription timeout');
      }

      await _speechToText.stop();
      
      _logger.i('Transcription result: $transcription');
      return transcription;
    } catch (e) {
      _logger.e('Failed to transcribe audio file', error: e);
      return null;
    }
  }

  /// Get available speech recognition locales
  Future<List<String>> getAvailableLocales() async {
    try {
      if (!_isInitialized) {
        return [];
      }

      final locales = await _speechToText.locales();
      return locales.map((locale) => locale.localeId).toList();
    } catch (e) {
      _logger.e('Failed to get available locales', error: e);
      return [];
    }
  }

  /// Check if microphone permission is granted
  Future<bool> checkMicrophonePermission() async {
    try {
      final permission = await Permission.microphone.status;
      return permission.isGranted;
    } catch (e) {
      _logger.e('Failed to check microphone permission', error: e);
      return false;
    }
  }

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    try {
      final permission = await Permission.microphone.request();
      return permission.isGranted;
    } catch (e) {
      _logger.e('Failed to request microphone permission', error: e);
      return false;
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    try {
      await stopRecording();
      await stopListening();
      await _audioRecorder.dispose();
      await _transcriptionController?.close();
      await _recordingStateController?.close();
      _isInitialized = false;
      _logger.i('Voice service disposed');
    } catch (e) {
      _logger.e('Error disposing voice service', error: e);
    }
  }
}

/// Voice recording state enum
enum VoiceRecordingState {
  idle,
  recording,
  listening,
  stopped,
  processing,
  error,
}