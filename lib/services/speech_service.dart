import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'logger_service.dart';

/// Service responsible for handling Speech-to-Text (STT) functionality.
/// 
/// Manages the microphone lifecycle, handles permissions, and provides
/// real-time transcription results.
class SpeechService extends ChangeNotifier {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastWords = '';
  double _soundLevel = 0.0;
  String _lastError = '';

  /// Whether the speech engine is currently active and listening.
  bool get isListening => _isListening;

  /// The current transcription result.
  String get lastWords => _lastWords;

  /// The current sound level (for visual feedback).
  double get soundLevel => _soundLevel;

  /// The last error message, if any.
  String get lastError => _lastError;

  /// Initializes the speech recognition engine.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );
      if (_isInitialized) {
        LoggerService.info('SpeechService initialized successfully');
      } else {
        LoggerService.warning('SpeechService failed to initialize');
      }
    } catch (e) {
      LoggerService.error('Error initializing SpeechService', error: e);
      _isInitialized = false;
    }
    
    return _isInitialized;
  }

  /// Starts a new listening session.
  /// 
  /// The [onResult] callback is triggered as words are recognized.
  Future<void> startListening({required Function(String) onResult}) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    _lastWords = '';
    _lastError = '';
    
    try {
      await _speech.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          if (result.finalResult) {
            onResult(_lastWords);
          }
          notifyListeners();
        },
        onSoundLevelChange: (level) {
          _soundLevel = level;
          notifyListeners();
        },
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      );
      _isListening = true;
      notifyListeners();
    } catch (e) {
      LoggerService.error('Error starting SpeechService listening', error: e);
      _isListening = false;
      notifyListeners();
    }
  }

  /// Stops the current listening session and returns the final result.
  Future<void> stopListening() async {
    await _speech.stop();
    _isListening = false;
    _soundLevel = 0.0;
    notifyListeners();
  }

  /// Cancels the current listening session without returning results.
  Future<void> cancelListening() async {
    await _speech.cancel();
    _isListening = false;
    _soundLevel = 0.0;
    notifyListeners();
  }

  void _onSpeechStatus(String status) {
    LoggerService.info('Speech status: $status');
    if (status == 'done' || status == 'notListening') {
      _isListening = false;
      _soundLevel = 0.0;
      notifyListeners();
    } else if (status == 'listening') {
      _isListening = true;
      notifyListeners();
    }
  }

  void _onSpeechError(errorNotification) {
    _lastError = errorNotification.errorMsg;
    LoggerService.error('Speech error: $_lastError');
    _isListening = false;
    _soundLevel = 0.0;
    notifyListeners();
  }
}
