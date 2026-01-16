import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'logger_service.dart';

/// Service responsible for handling Speech-to-Text (STT) via OpenAI Whisper.
class SpeechService extends ChangeNotifier {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  bool _isRecording = false;
  bool _isProcessing = false;
  String _openAIKey = '';
  String _lastWords = '';
  String _lastError = '';
  
  Function(String)? _pendingResultCallback;

  static const String _keyOpenAI = 'openai_api_key';

  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  bool get isListening => _isRecording || _isProcessing;
  String get openAIKey => _openAIKey;
  String get lastError => _lastError;

  /// Initializes the service and loads the API key.
  Future<void> initialize() async {
    _openAIKey = await _secureStorage.read(key: _keyOpenAI) ?? '';
    notifyListeners();
  }

  /// Sets and persists the OpenAI API key.
  Future<void> setOpenAIKey(String key) async {
    _openAIKey = key;
    await _secureStorage.write(key: _keyOpenAI, value: key);
    notifyListeners();
  }

  /// Starts recording audio.
  Future<bool> startListening({required Function(String) onResult}) async {
    if (_openAIKey.isEmpty) {
      _lastError = 'OpenAI API Key not configured';
      notifyListeners();
      return false;
    }

    _pendingResultCallback = onResult;

    try {
      if (await _recorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = p.join(tempDir.path, 'speech_rec.m4a');
        
        // Delete old file if exists
        final file = File(path);
        if (await file.exists()) await file.delete();

        const config = RecordConfig();
        await _recorder.start(config, path: path);
        _isRecording = true;
        _lastError = '';
        notifyListeners();
        return true;
      } else {
        _lastError = 'Microphone permission denied';
        notifyListeners();
        return false;
      }
    } catch (e) {
      LoggerService.error('Error starting recording', error: e);
      _lastError = 'Failed to start recording';
      notifyListeners();
      return false;
    }
  }

  /// Stops recording and triggers transcription.
  Future<void> stopListening({Function(String)? onResult}) async {
    try {
      final path = await _recorder.stop();
      _isRecording = false;
      
      final callback = onResult ?? _pendingResultCallback;
      
      if (path != null && callback != null) {
        _isProcessing = true;
        notifyListeners();
        
        final text = await _transcribeAudio(path);
        if (text != null && text.isNotEmpty) {
          callback(text);
        }
      }
    } catch (e) {
      LoggerService.error('Error stopping recording', error: e);
      _lastError = 'Transcription failed';
    } finally {
      _isRecording = false;
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<String?> _transcribeAudio(String path) async {
    try {
      final url = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $_openAIKey'
        ..fields['model'] = 'whisper-1'
        ..fields['language'] = 'pt' // Optional: can be dynamic
        ..files.add(await http.MultipartFile.fromPath('file', path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        return data['text'] as String?;
      } else {
        final error = json.decode(responseBody);
        _lastError = error['error']?['message'] ?? 'API Error ${response.statusCode}';
        LoggerService.error('OpenAI Whisper Error: $responseBody');
        return null;
      }
    } catch (e) {
      LoggerService.error('Transcription error', error: e);
      _lastError = 'Connection error: $e';
      return null;
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}
