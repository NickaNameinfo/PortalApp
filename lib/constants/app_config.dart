import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application configuration constants
/// Uses environment variables from .env file for sensitive values
/// Based on Dashboard/Frontend environment variable setup
class AppConfig {
  // Helper to safely get env variable (handles case where dotenv is not loaded)
  static String? _getEnv(String key) {
    try {
      return dotenv.env[key];
    } catch (e) {
      // dotenv not initialized yet, return null to use fallback
      return null;
    }
  }
  
  // API Configuration
  // Load from .env file, fallback to default if not set
  // static String get baseApi => _getEnv('API_BASE_URL') ?? 'https://nicknameinfo.net/api';
  static String get baseApi => _getEnv('API_BASE_URL') ?? 'http://localhost:8000/api';

  // WebSocket (Socket.IO) URL for real-time (e.g. new-order). Use http(s) for Socket.IO client; default port 3001.
  static String get webSocketUrl {
    final base = _getEnv('WS_URL');
    if (base != null && base.isNotEmpty) return base;
    final api = baseApi;
    final uri = Uri.parse(api);
    final host = uri.host;
    final scheme = uri.scheme == 'https' ? 'https' : 'http';
    final wsPort = _getEnv('WS_PORT') ?? '3001';
    return '$scheme://$host:$wsPort';
  }

  // Razorpay Configuration
  // Load from .env file, fallback to default if not set
  // IMPORTANT: Create .env file with your Razorpay key
  static String get razorpayKey => _getEnv('RAZORPAY_KEY') ?? 'rzp_live_RgPc8rKEOZbHgf';
  
  // Environment
  static String get environment => _getEnv('ENVIRONMENT') ?? 'development';
  
  // File Upload Configuration
  static const int maxFileSizeBytes = 500 * 1024; // 500KB
  static const List<String> allowedImageTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
  ];
  static const List<String> allowedImageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  ];
  
  // Password Configuration
  static const int minPasswordLength = 8;
  static const bool requireUppercase = true;
  static const bool requireLowercase = true;
  static const bool requireNumbers = true;
  static const bool requireSpecialChars = false;
}
