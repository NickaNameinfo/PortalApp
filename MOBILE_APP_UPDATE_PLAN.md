# Mobile App Update Plan - Implementing Dashboard/Frontend Changes

## Overview
This document outlines the plan to implement all recent changes from Dashboard and Frontend into the Flutter mobile app.

---

## Phase 1: Authentication & Token Management Updates ⚠️ HIGH PRIORITY

### 1.1 Update Token Storage & Retrieval
**Current State:**
- Token stored in SharedPreferences as `'token'`
- Token extracted from `responseData['token']` in login

**Required Changes:**
- ✅ Already using `SecureHttpClient` with Bearer token (good!)
- ⚠️ Need to update token extraction to match backend response structure
- ⚠️ Need to handle `XSRF-token` if backend uses it (mobile doesn't use cookies, but should check)

**Files to Update:**
- `lib/views/auth/auth.dart` - Update token extraction logic
- `lib/helpers/secure_http_client.dart` - Verify token format (Bearer vs plain)
- `lib/utilities/auth_helper.dart` - Add token validation helpers

**Implementation:**
```dart
// In auth.dart - Update token extraction
final token = responseData['token'] ?? 
              responseData['data']?['token'] ?? 
              responseData['accessToken'];

// In secure_http_client.dart - Verify header format
// Current: headers['Authorization'] = 'Bearer $token';
// Backend might expect: headers['Authorization'] = token; (without Bearer)
// Check Dashboard authHelper.mjs to see format
```

### 1.2 Error Handling Improvements
**Current State:**
- Basic error handling in login

**Required Changes:**
- Update error message extraction to match Dashboard: `result?.error?.data?.message`
- Add centralized error handling utility

**Files to Create/Update:**
- `lib/helpers/error_handler.dart` (NEW) - Centralized error handling
- `lib/views/auth/auth.dart` - Update error message extraction

**Implementation:**
```dart
// lib/helpers/error_handler.dart
class ErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error is http.Response) {
      try {
        final errorData = json.decode(error.body);
        return errorData['error']?['data']?['message'] ?? 
               errorData['message'] ?? 
               'An error occurred';
      } catch (e) {
        return 'An error occurred';
      }
    }
    return error.toString();
  }
  
  static bool isAuthError(http.Response response) {
    return response.statusCode == 401;
  }
  
  static void handleUnauthorized(BuildContext context) {
    // Clear auth data and navigate to login
    AuthHelper.logout(context);
  }
}
```

### 1.3 Token Refresh & Persistence
**Current State:**
- Token stored in SharedPreferences
- No automatic token refresh

**Required Changes:**
- Add token expiration checking
- Add automatic token refresh if needed
- Improve token persistence across app restarts

**Files to Update:**
- `lib/helpers/secure_http_client.dart` - Add 401 handling
- `lib/utilities/auth_helper.dart` - Add token validation

---

## Phase 2: API Service Updates ⚠️ HIGH PRIORITY

### 2.1 Update SecureHttpClient
**Current State:**
- Uses `Bearer $token` format
- Basic error handling

**Required Changes:**
- ⚠️ **CRITICAL**: Check if backend expects `Bearer` or plain token
- Add automatic 401 handling with redirect to login
- Add public route detection (skip auth for login/register)
- Add better error logging

**Files to Update:**
- `lib/helpers/secure_http_client.dart`

**Implementation:**
```dart
// Check Dashboard authHelper.mjs line 149:
// headers.set("Authorization", `${token}`); // NO Bearer prefix!
// So mobile should also use: headers['Authorization'] = token;

// Add public routes list
static const List<String> publicRoutes = [
  '/api/auth/register',
  '/api/auth/rootLogin',
  '/api/customer/register',
  '/api/customer/login',
];

static bool isPublicRoute(String url) {
  return publicRoutes.any((route) => url.contains(route));
}

// Update _getHeaders to skip auth for public routes
static Future<Map<String, String>> _getHeaders({String? url}) async {
  final headers = <String, String>{
    'Content-Type': 'application/json',
  };
  
  // Skip auth for public routes
  if (url != null && isPublicRoute(url)) {
    return headers;
  }
  
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  
  if (token != null && token.isNotEmpty) {
    // Check Dashboard format - might need to remove 'Bearer '
    headers['Authorization'] = token; // Or 'Bearer $token' if backend expects it
  }
  
  return headers;
}

// Add 401 handling in all methods
static Future<http.Response> get(String url, {...}) async {
  try {
    final headers = await _getHeaders(url: url);
    final response = await http.get(Uri.parse(url), headers: headers).timeout(timeout);
    
    // Handle 401 Unauthorized
    if (response.statusCode == 401) {
      // Clear auth and show login
      // This needs BuildContext, so might need to use a global navigator
      debugPrint('401 Unauthorized - Token expired or invalid');
      // Handle via error handler
    }
    
    return response;
  } catch (e) {
    debugPrint('SecureHttpClient GET error: $e');
    rethrow;
  }
}
```

### 2.2 Update All Service Files
**Current State:**
- Services use `SecureHttpClient` (good!)
- Some might still use old `HttpClient`

**Required Changes:**
- Verify all services use `SecureHttpClient`
- Update any direct `http.get/post` calls
- Add error handling using new `ErrorHandler`

**Files to Check/Update:**
- `lib/helpers/billing_service.dart`
- `lib/helpers/category_service.dart`
- `lib/helpers/product_api_service.dart`
- `lib/helpers/subscription_service.dart`
- `lib/helpers/order_service.dart`
- `lib/helpers/address_service.dart`
- `lib/helpers/cart_api_helper.dart`
- `lib/helpers/checkout_api_helper.dart`

**Action Items:**
1. Search for `HttpClient.get` or `http.get` (direct calls)
2. Replace with `SecureHttpClient.get`
3. Add error handling using `ErrorHandler`

---

## Phase 3: Validation & Security Updates ✅ MEDIUM PRIORITY

### 3.1 Password Validation
**Current State:**
- ✅ Already implemented in `lib/helpers/password_validation.dart`
- ✅ Matches Dashboard/Frontend requirements

**Required Changes:**
- Verify it's used in all password input forms
- Add visual password strength indicator if not present

**Files to Check:**
- `lib/views/auth/auth.dart` - Login/Register forms
- `lib/views/auth/forgot_password.dart`
- `lib/views/main/customer/edit_profile.dart`
- `lib/views/main/seller/edit_profile.dart`

### 3.2 File Validation
**Current State:**
- ✅ Already implemented in `lib/helpers/file_validation.dart`
- ✅ Matches Dashboard/Frontend requirements

**Required Changes:**
- Verify it's used in all file upload screens
- Add user-friendly error messages

**Files to Check:**
- `lib/views/main/seller/dashboard_screens/upload_product.dart`
- `lib/views/main/seller/dashboard_screens/edit_product.dart`
- `lib/views/main/seller/dashboard_screens/store_setup.dart`
- `lib/views/main/customer/edit_profile.dart`
- `lib/views/main/seller/edit_profile.dart`

---

## Phase 4: Configuration & Environment Variables ⚠️ HIGH PRIORITY

### 4.1 Move Hardcoded Values to Environment
**Current State:**
- Razorpay key hardcoded in `app_config.dart`
- API base URL hardcoded

**Required Changes:**
- Create `.env` file support (use `flutter_dotenv` package)
- Move Razorpay key to environment variable
- Move API base URL to environment variable

**Files to Create/Update:**
- `.env` (NEW) - Environment variables
- `.env.example` (NEW) - Example file
- `lib/constants/app_config.dart` - Read from environment
- `pubspec.yaml` - Add `flutter_dotenv` dependency

**Implementation:**
```yaml
# pubspec.yaml
dependencies:
  flutter_dotenv: ^5.1.0

# .env
RAZORPAY_KEY=rzp_live_RgPc8rKEOZbHgf
API_BASE_URL=https://nicknameinfo.net/api

# app_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get razorpayKey => dotenv.env['RAZORPAY_KEY'] ?? '';
  static String get baseApi => dotenv.env['API_BASE_URL'] ?? 'https://nicknameinfo.net/api';
}
```

### 4.2 Update .gitignore
**Required Changes:**
- Add `.env` to `.gitignore`
- Keep `.env.example` in repo

---

## Phase 5: Logging & Debugging ✅ LOW PRIORITY

### 5.1 Production-Safe Logging
**Current State:**
- Uses `debugPrint` throughout

**Required Changes:**
- ✅ Already has `lib/helpers/logger.dart`
- Verify it's used everywhere instead of `debugPrint`
- Ensure production builds don't log sensitive data

**Files to Check:**
- All files using `debugPrint` - replace with `Logger.debug()` or `Logger.info()`

---

## Phase 6: UI/UX Improvements (Not from Dashboard/Frontend)

### 6.1 Right-Click Functionality
**Status:** ❌ NOT APPLICABLE
- Mobile apps use touch/long-press, not right-click
- Long-press context menus already exist in Flutter
- No changes needed

### 6.2 Subscription Details Updates
**Current State:**
- Subscription screen exists

**Required Changes:**
- Update to match Dashboard subscription logic
- Use current login details for subscription data

**Files to Update:**
- `lib/views/main/seller/dashboard_screens/subscription_screen.dart`
- `lib/helpers/subscription_service.dart`

---

## Implementation Priority

### 🔴 CRITICAL (Do First)
1. **Phase 1.1** - Update token extraction and format
2. **Phase 2.1** - Fix Authorization header format (Bearer vs plain)
3. **Phase 2.1** - Add 401 handling
4. **Phase 4.1** - Move Razorpay key to environment

### 🟡 HIGH (Do Next)
5. **Phase 1.2** - Error handling improvements
6. **Phase 2.2** - Update all service files
7. **Phase 4.2** - Update .gitignore

### 🟢 MEDIUM (Do After)
8. **Phase 3.1** - Verify password validation usage
9. **Phase 3.2** - Verify file validation usage
10. **Phase 6.2** - Subscription details updates

### ⚪ LOW (Nice to Have)
11. **Phase 5.1** - Production-safe logging verification

---

## Testing Checklist

After each phase, test:

### Authentication
- [ ] Login works with new token format
- [ ] Token persists across app restarts
- [ ] 401 errors redirect to login
- [ ] Logout clears all auth data

### API Calls
- [ ] All API calls include auth headers
- [ ] Public routes (login/register) don't require auth
- [ ] Error messages display correctly
- [ ] Network errors handled gracefully

### Validation
- [ ] Password validation works on all forms
- [ ] File validation works on all uploads
- [ ] Error messages are user-friendly

### Configuration
- [ ] Environment variables load correctly
- [ ] Razorpay key from environment works
- [ ] API base URL from environment works
- [ ] .env file not committed to git

---

## Files Summary

### Files to Create (NEW)
1. `lib/helpers/error_handler.dart` - Centralized error handling
2. `.env` - Environment variables (gitignored)
3. `.env.example` - Example environment file

### Files to Update (MODIFY)
1. `lib/views/auth/auth.dart` - Token extraction, error handling
2. `lib/helpers/secure_http_client.dart` - Auth header format, 401 handling
3. `lib/utilities/auth_helper.dart` - Token validation
4. `lib/constants/app_config.dart` - Environment variable support
5. All service files - Error handling, verify SecureHttpClient usage
6. `.gitignore` - Add .env

### Files to Verify (CHECK)
1. All password forms - Use PasswordValidation
2. All file upload screens - Use FileValidation
3. All API calls - Use SecureHttpClient
4. All logging - Use Logger instead of debugPrint

---

## Notes

1. **Token Format**: Critical to verify if backend expects `Bearer $token` or just `token`. Check Dashboard `authHelper.mjs` line 149.

2. **401 Handling**: Mobile apps need BuildContext for navigation, so 401 handling might need a global navigator key or callback.

3. **Environment Variables**: Use `flutter_dotenv` package. Load in `main.dart` before `runApp()`.

4. **Testing**: Test on both Android and iOS after each phase.

5. **Backward Compatibility**: Ensure changes don't break existing functionality.

---

## Estimated Time

- Phase 1: 2-3 hours
- Phase 2: 3-4 hours
- Phase 3: 1-2 hours
- Phase 4: 1-2 hours
- Phase 5: 1 hour
- Phase 6: 1-2 hours

**Total: 9-14 hours**

---

## Next Steps

1. Review this plan
2. Start with Phase 1.1 (Token format verification)
3. Test after each phase
4. Update this document with progress
