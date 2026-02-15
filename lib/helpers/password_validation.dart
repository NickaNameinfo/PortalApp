import 'package:nickname_portal/constants/app_config.dart';

/// Password validation utilities
class PasswordValidation {
  /// Validate password strength
  /// Returns list of error messages, empty if valid
  static List<String> validatePassword(String password) {
    final errors = <String>[];

    if (password.isEmpty) {
      return ['Password is required'];
    }

    // Check minimum length
    if (password.length < AppConfig.minPasswordLength) {
      errors.add(
        'Password must be at least ${AppConfig.minPasswordLength} characters long',
      );
    }

    // Check for uppercase letter
    if (AppConfig.requireUppercase && !password.contains(RegExp(r'[A-Z]'))) {
      errors.add('Password must contain at least one uppercase letter');
    }

    // Check for lowercase letter
    if (AppConfig.requireLowercase && !password.contains(RegExp(r'[a-z]'))) {
      errors.add('Password must contain at least one lowercase letter');
    }

    // Check for numbers
    if (AppConfig.requireNumbers && !password.contains(RegExp(r'[0-9]'))) {
      errors.add('Password must contain at least one number');
    }

    // Check for special characters
    if (AppConfig.requireSpecialChars &&
        !password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      errors.add('Password must contain at least one special character');
    }

    return errors;
  }

  /// Get password strength score (0-4)
  /// 0 = Very Weak, 4 = Very Strong
  static int getPasswordStrength(String password) {
    if (password.isEmpty) return 0;

    int score = 0;

    // Length check
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;

    // Character variety
    if (password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[A-Z]'))) {
      score++;
    }
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;

    return score > 4 ? 4 : score;
  }

  /// Get password strength label
  static String getPasswordStrengthLabel(String password) {
    final strength = getPasswordStrength(password);
    const labels = ['Very Weak', 'Weak', 'Fair', 'Good', 'Very Strong'];
    return labels[strength > 4 ? 4 : strength];
  }

  /// Check if password is valid
  static bool isValid(String password) {
    return validatePassword(password).isEmpty;
  }
}
