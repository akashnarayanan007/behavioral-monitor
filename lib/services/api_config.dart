import 'secrets.dart';

class ApiConfig {
  // --- Gemini Config ---
  static const String _geminiEnvKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _geminiFileKey = Secrets.geminiApiKey;
  static final String geminiApiKey = _geminiEnvKey.isNotEmpty ? _geminiEnvKey : _geminiFileKey;

  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent';
  static const String geminiModel = 'gemini-3.5-flash-lite';
}
