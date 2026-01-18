import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'logger_service.dart';

/// Supported STT engines.
enum STTEngine { whisper, gemini }

/// Service responsible for handling Speech-to-Text (STT) via OpenAI Whisper.
class SpeechService extends ChangeNotifier {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  bool _isRecording = false;
  bool _isProcessing = false;
  STTEngine _engine = STTEngine.whisper;
  String _openAIKey = '';
  String _geminiKey = '';
  String _lastWords = '';
  String _lastError = '';
  
  Function(String)? _pendingResultCallback;

  static const String _keyOpenAI = 'openai_api_key';
  static const String _keyGemini = 'gemini_api_key';
  static const String _keyEngine = 'stt_engine';

  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  bool get isListening => _isRecording || _isProcessing;
  STTEngine get engine => _engine;
  String get openAIKey => _openAIKey;
  String get geminiKey => _geminiKey;
  String get lastError => _lastError;

  /// Initializes the service and loads the API key.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _openAIKey = await _secureStorage.read(key: _keyOpenAI) ?? '';
    _geminiKey = await _secureStorage.read(key: _keyGemini) ?? '';
    
    final engineName = prefs.getString(_keyEngine);
    _engine = STTEngine.values.firstWhere(
      (e) => e.name == engineName,
      orElse: () => STTEngine.whisper,
    );
    
    notifyListeners();
  }

  /// Sets and persists the OpenAI API key.
  Future<void> setOpenAIKey(String key) async {
    _openAIKey = key;
    await _secureStorage.write(key: _keyOpenAI, value: key);
    notifyListeners();
  }

  /// Sets and persists the Gemini API key.
  Future<void> setGeminiKey(String key) async {
    _geminiKey = key;
    await _secureStorage.write(key: _keyGemini, value: key);
    notifyListeners();
  }

  /// Sets the preferred STT engine.
  Future<void> setEngine(STTEngine engine) async {
    _engine = engine;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEngine, engine.name);
    notifyListeners();
  }

  /// Starts recording audio.
  Future<bool> startListening({required Function(String) onResult}) async {
    final key = _engine == STTEngine.whisper ? _openAIKey : _geminiKey;
    if (key.isEmpty) {
      _lastError = '${_engine == STTEngine.whisper ? 'OpenAI' : 'Gemini'} API Key is missing. Please set it in settings.';
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

        const config = RecordConfig(encoder: AudioEncoder.aacLc);
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
  Future<String> stopListening() async {
    if (!_isRecording) return '';

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      _isProcessing = true;
      notifyListeners();

      if (path == null) throw Exception('Recording failed: No path returned');

      String transcription;
      if (_engine == STTEngine.whisper) {
        final result = await _transcribeWithWhisper(path);
        transcription = result ?? '';
      } else {
        transcription = await _transcribeWithGemini(path);
      }

      _lastWords = transcription;
      _isProcessing = false;
      
      if (_pendingResultCallback != null && transcription.isNotEmpty) {
        _pendingResultCallback!(transcription);
      }
      
      notifyListeners();
      return transcription;
    } catch (e) {
      _isProcessing = false;
      _lastError = 'Transcription failed: $e';
      LoggerService.error('Transcription error', error: e);
      notifyListeners();
      return '';
    }
  }

  Future<String?> _transcribeWithWhisper(String path) async {
    try {
      final url = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $_openAIKey'
        ..fields['model'] = 'whisper-1'
        ..fields['language'] = 'pt'
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

  Future<String> _transcribeWithGemini(String audioPath) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _geminiKey,
      );

      final file = File(audioPath);
      final bytes = await file.readAsBytes();

      final content = [
        Content.multi([
          TextPart('Transcreva este áudio exatamente como falado, sem comentários adicionais.'),
          DataPart('audio/mp4', bytes),
        ])
      ];

      final response = await model.generateContent(content);
      return response.text ?? '';
    } catch (e) {
      LoggerService.error('Gemini Transcription Error', error: e);
      rethrow;
    }
  }


  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}
