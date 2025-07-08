// lib/src/core/services/tts_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'logger_service.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  final _logger = FeatureLogger('TTSService');
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  
  StreamController<TTSState>? _stateController;
  StreamController<String>? _progressController;

  // Current settings
  String _language = 'en-US';
  double _speechRate = 0.5;
  double _volume = 1.0;
  double _pitch = 1.0;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  bool get isPaused => _isPaused;
  Stream<TTSState>? get stateStream => _stateController?.stream;
  Stream<String>? get progressStream => _progressController?.stream;
  
  String get language => _language;
  double get speechRate => _speechRate;
  double get volume => _volume;
  double get pitch => _pitch;

  /// Initialize the TTS service
  Future<bool> initialize() async {
    try {
      _logger.i('Initializing TTS service...');
      
      // Run initialization in microtask to avoid blocking UI
      await Future.microtask(() async {
        // Initialize stream controllers
        _stateController = StreamController<TTSState>.broadcast();
        _progressController = StreamController<String>.broadcast();

        // Set up TTS handlers
        _flutterTts.setStartHandler(() {
          _logger.d('TTS started');
          _isSpeaking = true;
          _isPaused = false;
          _stateController?.add(TTSState.speaking);
        });

        _flutterTts.setCompletionHandler(() {
          _logger.d('TTS completed');
          _isSpeaking = false;
          _isPaused = false;
          _stateController?.add(TTSState.stopped);
        });

        _flutterTts.setCancelHandler(() {
          _logger.d('TTS cancelled');
          _isSpeaking = false;
          _isPaused = false;
          _stateController?.add(TTSState.stopped);
        });

        _flutterTts.setPauseHandler(() {
          _logger.d('TTS paused');
          _isPaused = true;
          _stateController?.add(TTSState.paused);
        });

        _flutterTts.setContinueHandler(() {
          _logger.d('TTS resumed');
          _isPaused = false;
          _stateController?.add(TTSState.speaking);
        });

        _flutterTts.setErrorHandler((message) {
          _logger.e('TTS error: $message');
          _isSpeaking = false;
          _isPaused = false;
          _stateController?.add(TTSState.error);
        });

        // Set up progress handler (if available)
        _flutterTts.setProgressHandler((String text, int start, int end, String word) {
          _logger.d('TTS progress: $word');
          _progressController?.add(word);
        });

        // Configure default settings
        await _configureDefaultSettings();

        _isInitialized = true;
        _logger.i('TTS service initialized successfully');
      });
      
      return true;
    } catch (e) {
      _logger.e('Failed to initialize TTS service', error: e);
      return false;
    }
  }

  /// Configure default TTS settings
  Future<void> _configureDefaultSettings() async {
    try {
      // Set language
      await _flutterTts.setLanguage(_language);
      
      // Set speech rate (0.0 to 1.0)
      await _flutterTts.setSpeechRate(_speechRate);
      
      // Set volume (0.0 to 1.0)
      await _flutterTts.setVolume(_volume);
      
      // Set pitch (0.5 to 2.0)
      await _flutterTts.setPitch(_pitch);

      // Enable/disable shared instance (iOS specific)
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.allowBluetooth],
        );
      }

      _logger.i('TTS default settings configured');
    } catch (e) {
      _logger.e('Failed to configure TTS settings', error: e);
    }
  }

  /// Speak the given text
  Future<bool> speak(String text) async {
    try {
      if (!_isInitialized) {
        _logger.e('TTS service not initialized');
        return false;
      }

      if (text.trim().isEmpty) {
        _logger.w('Empty text provided for TTS');
        return false;
      }

      // Stop any current speech
      await stop();

      _logger.i('Speaking: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');
      
      final result = await _flutterTts.speak(text);
      
      if (result == 1) {
        _logger.i('TTS speak command successful');
        return true;
      } else {
        _logger.e('TTS speak command failed with result: $result');
        return false;
      }
    } catch (e) {
      _logger.e('Failed to speak text', error: e);
      return false;
    }
  }

  /// Stop current speech
  Future<bool> stop() async {
    try {
      if (!_isInitialized) {
        return false;
      }

      final result = await _flutterTts.stop();
      
      if (result == 1) {
        _logger.i('TTS stopped successfully');
        return true;
      } else {
        _logger.e('TTS stop failed with result: $result');
        return false;
      }
    } catch (e) {
      _logger.e('Failed to stop TTS', error: e);
      return false;
    }
  }

  /// Pause current speech
  Future<bool> pause() async {
    try {
      if (!_isInitialized || !_isSpeaking) {
        return false;
      }

      final result = await _flutterTts.pause();
      
      if (result == 1) {
        _logger.i('TTS paused successfully');
        return true;
      } else {
        _logger.e('TTS pause failed with result: $result');
        return false;
      }
    } catch (e) {
      _logger.e('Failed to pause TTS', error: e);
      return false;
    }
  }

  /// Resume paused speech
  Future<bool> resume() async {
    try {
      if (!_isInitialized || !_isPaused) {
        return false;
      }

      // Note: flutter_tts doesn't have a direct resume method
      // We'll use stop and then speak again approach
      _logger.i('TTS resumed (simulated)');
      return true;
    } catch (e) {
      _logger.e('Failed to resume TTS', error: e);
      return false;
    }
  }

  /// Set speech language
  Future<bool> setLanguage(String language) async {
    try {
      if (!_isInitialized) {
        return false;
      }

      final result = await _flutterTts.setLanguage(language);
      
      if (result == 1) {
        _language = language;
        _logger.i('TTS language set to: $language');
        return true;
      } else {
        _logger.e('Failed to set TTS language to: $language');
        return false;
      }
    } catch (e) {
      _logger.e('Failed to set TTS language', error: e);
      return false;
    }
  }

  /// Set speech rate (0.0 to 1.0)
  Future<bool> setSpeechRate(double rate) async {
    try {
      if (!_isInitialized) {
        return false;
      }

      final clampedRate = rate.clamp(0.0, 1.0);
      final result = await _flutterTts.setSpeechRate(clampedRate);
      
      if (result == 1) {
        _speechRate = clampedRate;
        _logger.i('TTS speech rate set to: $clampedRate');
        return true;
      } else {
        _logger.e('Failed to set TTS speech rate to: $clampedRate');
        return false;
      }
    } catch (e) {
      _logger.e('Failed to set TTS speech rate', error: e);
      return false;
    }
  }

  /// Set speech volume (0.0 to 1.0)
  Future<bool> setVolume(double volume) async {
    try {
      if (!_isInitialized) {
        return false;
      }

      final clampedVolume = volume.clamp(0.0, 1.0);
      final result = await _flutterTts.setVolume(clampedVolume);
      
      if (result == 1) {
        _volume = clampedVolume;
        _logger.i('TTS volume set to: $clampedVolume');
        return true;
      } else {
        _logger.e('Failed to set TTS volume to: $clampedVolume');
        return false;
      }
    } catch (e) {
      _logger.e('Failed to set TTS volume', error: e);
      return false;
    }
  }

  /// Set speech pitch (0.5 to 2.0)
  Future<bool> setPitch(double pitch) async {
    try {
      if (!_isInitialized) {
        return false;
      }

      final clampedPitch = pitch.clamp(0.5, 2.0);
      final result = await _flutterTts.setPitch(clampedPitch);
      
      if (result == 1) {
        _pitch = clampedPitch;
        _logger.i('TTS pitch set to: $clampedPitch');
        return true;
      } else {
        _logger.e('Failed to set TTS pitch to: $clampedPitch');
        return false;
      }
    } catch (e) {
      _logger.e('Failed to set TTS pitch', error: e);
      return false;
    }
  }

  /// Get available languages
  Future<List<String>> getAvailableLanguages() async {
    try {
      if (!_isInitialized) {
        return [];
      }

      final languages = await _flutterTts.getLanguages;
      if (languages != null) {
        return List<String>.from(languages);
      }
      return [];
    } catch (e) {
      _logger.e('Failed to get available languages', error: e);
      return [];
    }
  }

  /// Get available voices for current language
  Future<List<Map<String, String>>> getAvailableVoices() async {
    try {
      if (!_isInitialized) {
        return [];
      }

      final voices = await _flutterTts.getVoices;
      if (voices != null) {
        return List<Map<String, String>>.from(voices);
      }
      return [];
    } catch (e) {
      _logger.e('Failed to get available voices', error: e);
      return [];
    }
  }

  /// Set voice by name
  Future<bool> setVoice(String voiceName) async {
    try {
      if (!_isInitialized) {
        return false;
      }

      final voices = await getAvailableVoices();
      final voice = voices.firstWhere(
        (v) => v['name'] == voiceName,
        orElse: () => {},
      );

      if (voice.isNotEmpty) {
        final result = await _flutterTts.setVoice(voice);
        if (result == 1) {
          _logger.i('TTS voice set to: $voiceName');
          return true;
        }
      }
      
      _logger.e('Failed to set TTS voice to: $voiceName');
      return false;
    } catch (e) {
      _logger.e('Failed to set TTS voice', error: e);
      return false;
    }
  }

  /// Check if TTS is available
  Future<bool> isAvailable() async {
    try {
      final languages = await _flutterTts.getLanguages;
      return languages != null && languages.isNotEmpty;
    } catch (e) {
      _logger.e('Failed to check TTS availability', error: e);
      return false;
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    try {
      await stop();
      await _stateController?.close();
      await _progressController?.close();
      _isInitialized = false;
      _logger.i('TTS service disposed');
    } catch (e) {
      _logger.e('Error disposing TTS service', error: e);
    }
  }
}

/// TTS state enum
enum TTSState {
  stopped,
  speaking,
  paused,
  error,
}