// lib/src/core/services/audio_player_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'logger_service.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final _logger = FeatureLogger('AudioPlayerService');
  late AudioPlayer _audioPlayer;
  
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String? _currentFilePath;
  
  StreamController<AudioPlayerState>? _stateController;
  StreamController<Duration>? _positionController;
  StreamController<Duration>? _durationController;

  // Stream subscriptions
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  String? get currentFilePath => _currentFilePath;
  
  Stream<AudioPlayerState>? get stateStream => _stateController?.stream;
  Stream<Duration>? get positionStream => _positionController?.stream;
  Stream<Duration>? get durationStream => _durationController?.stream;

  /// Initialize the audio player service
  Future<bool> initialize() async {
    try {
      _logger.i('Initializing audio player service...');
      
      _audioPlayer = AudioPlayer();
      _stateController = StreamController<AudioPlayerState>.broadcast();
      _positionController = StreamController<Duration>.broadcast();
      _durationController = StreamController<Duration>.broadcast();
      
      // Set up listeners
      _setupListeners();
      
      _isInitialized = true;
      _logger.i('Audio player service initialized successfully');
      
      return true;
    } catch (e) {
      _logger.e('Failed to initialize audio player service', error: e);
      return false;
    }
  }

  void _setupListeners() {
    // Player state listener
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      _isPaused = state == PlayerState.paused;
      
      _stateController?.add(AudioPlayerState(
        isPlaying: _isPlaying,
        isPaused: _isPaused,
        isStopped: state == PlayerState.stopped,
        isCompleted: state == PlayerState.completed,
      ));
      
      _logger.d('Player state changed: $state');
    });

    // Position listener
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      _currentPosition = position;
      _positionController?.add(position);
    });

    // Duration listener
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      _totalDuration = duration;
      _durationController?.add(duration);
    });
  }

  /// Play audio from file path
  Future<bool> playFromFile(String filePath) async {
    try {
      if (!_isInitialized) {
        _logger.e('Audio player service not initialized');
        return false;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        _logger.e('Audio file not found: $filePath');
        return false;
      }

      // Stop current playback if any
      await stop();

      _currentFilePath = filePath;
      _logger.i('Playing audio file: $filePath');

      // Play the file
      await _audioPlayer.play(DeviceFileSource(filePath));
      
      return true;
    } catch (e) {
      _logger.e('Failed to play audio file', error: e);
      return false;
    }
  }

  /// Pause playback
  Future<bool> pause() async {
    try {
      if (!_isInitialized || !_isPlaying) {
        return false;
      }

      await _audioPlayer.pause();
      _logger.i('Audio playback paused');
      return true;
    } catch (e) {
      _logger.e('Failed to pause audio', error: e);
      return false;
    }
  }

  /// Resume playback
  Future<bool> resume() async {
    try {
      if (!_isInitialized || !_isPaused) {
        return false;
      }

      await _audioPlayer.resume();
      _logger.i('Audio playback resumed');
      return true;
    } catch (e) {
      _logger.e('Failed to resume audio', error: e);
      return false;
    }
  }

  /// Stop playback
  Future<bool> stop() async {
    try {
      if (!_isInitialized) {
        return false;
      }

      await _audioPlayer.stop();
      _currentPosition = Duration.zero;
      _currentFilePath = null;
      _logger.i('Audio playback stopped');
      return true;
    } catch (e) {
      _logger.e('Failed to stop audio', error: e);
      return false;
    }
  }

  /// Seek to specific position
  Future<bool> seek(Duration position) async {
    try {
      if (!_isInitialized) {
        return false;
      }

      await _audioPlayer.seek(position);
      _logger.i('Seeked to position: ${position.inSeconds}s');
      return true;
    } catch (e) {
      _logger.e('Failed to seek audio', error: e);
      return false;
    }
  }

  /// Set playback speed
  Future<bool> setPlaybackRate(double rate) async {
    try {
      if (!_isInitialized) {
        return false;
      }

      // Clamp rate between 0.5 and 2.0
      final clampedRate = rate.clamp(0.5, 2.0);
      await _audioPlayer.setPlaybackRate(clampedRate);
      _logger.i('Playback rate set to: $clampedRate');
      return true;
    } catch (e) {
      _logger.e('Failed to set playback rate', error: e);
      return false;
    }
  }

  /// Set volume (0.0 to 1.0)
  Future<bool> setVolume(double volume) async {
    try {
      if (!_isInitialized) {
        return false;
      }

      final clampedVolume = volume.clamp(0.0, 1.0);
      await _audioPlayer.setVolume(clampedVolume);
      _logger.i('Volume set to: $clampedVolume');
      return true;
    } catch (e) {
      _logger.e('Failed to set volume', error: e);
      return false;
    }
  }

  /// Get formatted current position
  String get formattedPosition {
    return _formatDuration(_currentPosition);
  }

  /// Get formatted total duration
  String get formattedDuration {
    return _formatDuration(_totalDuration);
  }

  /// Get playback progress (0.0 to 1.0)
  double get progress {
    if (_totalDuration.inMilliseconds <= 0) return 0.0;
    return _currentPosition.inMilliseconds / _totalDuration.inMilliseconds;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// Dispose service
  Future<void> dispose() async {
    try {
      await stop();
      await _playerStateSubscription?.cancel();
      await _positionSubscription?.cancel();
      await _durationSubscription?.cancel();
      await _audioPlayer.dispose();
      await _stateController?.close();
      await _positionController?.close();
      await _durationController?.close();
      
      _isInitialized = false;
      _logger.i('Audio player service disposed');
    } catch (e) {
      _logger.e('Error disposing audio player service', error: e);
    }
  }
}

/// Audio player state model
class AudioPlayerState {
  final bool isPlaying;
  final bool isPaused;
  final bool isStopped;
  final bool isCompleted;

  AudioPlayerState({
    required this.isPlaying,
    required this.isPaused,
    required this.isStopped,
    required this.isCompleted,
  });

  @override
  String toString() {
    return 'AudioPlayerState(playing: $isPlaying, paused: $isPaused, stopped: $isStopped, completed: $isCompleted)';
  }
}