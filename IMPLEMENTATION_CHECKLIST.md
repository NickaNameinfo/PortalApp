# Mobile App Implementation Checklist

## Quick Reference Checklist

### ✅ Already Implemented
- [x] SecureHttpClient with Bearer token support
- [x] Password validation (`lib/helpers/password_validation.dart`)
- [x] File validation (`lib/helpers/file_validation.dart`)
- [x] Logger utility (`lib/helpers/logger.dart`)
- [x] Token storage in SharedPreferences

### ⚠️ Needs Verification/Update

#### 1. Token Format (CRITICAL)
- [ ] Verify if backend expects `Bearer $token` or just `token`
  - Dashboard `authHelper.mjs` line 151: `headers.set("Authorization", \`${token}\`)` (NO Bearer!)
  - But line 84: `headers['Authorization'] = \`Bearer ${token}\`` (WITH Bearer)
  - **ACTION**: Check which one is actually used in production
  - **CURRENT MOBILE**: Uses `Bearer $token` (line 22 in secure_http_client.dart)
  - **DECISION NEEDED**: Update mobile to match Dashboard format

#### 2. Error Handling
- [ ] Create `lib/helpers/error_handler.dart`
- [ ] Update login error message: `result?.error?.data?.message`
- [ ] Add 401 handling with auto-logout

#### 3. Environment Variables
- [ ] Add `flutter_dotenv` package
- [ ] Create `.env` file
- [ ] Create `.env.example` file
- [ ] Update `app_config.dart` to use environment variables
- [ ] Update `.gitignore` to exclude `.env`

#### 4. Service Files Audit
- [ ] Verify all services use `SecureHttpClient`
- [ ] Replace any direct `http.get/post` calls
- [ ] Add error handling using `ErrorHandler`

#### 5. Validation Usage
- [ ] Verify password validation used in all password forms
- [ ] Verify file validation used in all upload screens

---

## Step-by-Step Implementation Order

### Step 1: Fix Token Format (5 min)
**File**: `lib/helpers/secure_http_client.dart`
```dart
// Change line 22 from:
headers['Authorization'] = 'Bearer $token';
// To (if Dashboard uses plain token):
headers['Authorization'] = token;
```

### Step 2: Create Error Handler (15 min)
**File**: `lib/helpers/error_handler.dart` (NEW)
- Copy structure from Dashboard `errorHandler.mjs`
- Adapt for Dart/Flutter

### Step 3: Update Login Error Handling (5 min)
**File**: `lib/views/auth/auth.dart`
- Update error message extraction to match Dashboard

### Step 4: Add 401 Handling (20 min)
**File**: `lib/helpers/secure_http_client.dart`
- Add 401 detection
- Add callback or global navigator for logout

### Step 5: Environment Variables (30 min)
- Add `flutter_dotenv` to `pubspec.yaml`
- Create `.env` and `.env.example`
- Update `app_config.dart`
- Update `.gitignore`

### Step 6: Service Files Audit (1-2 hours)
- Check each service file
- Replace direct HTTP calls
- Add error handling

### Step 7: Validation Verification (30 min)
- Check all password forms
- Check all file upload screens

---

## Testing After Each Step

1. **Token Format**: Test login, verify API calls work
2. **Error Handler**: Test with invalid credentials
3. **401 Handling**: Test with expired token
4. **Environment**: Test app loads config correctly
5. **Services**: Test each service endpoint
6. **Validation**: Test password/file validation

---

## Critical Notes

1. **Token Format Discrepancy**: Dashboard code shows both formats. Need to verify which is correct by testing or checking backend middleware.

2. **401 Handling**: Mobile apps need BuildContext for navigation. Options:
   - Use global navigator key
   - Pass callback function
   - Use state management (Provider/Riverpod)

3. **Environment Variables**: Must load in `main.dart`:
   ```dart
   void main() async {
     await dotenv.load(fileName: ".env");
     runApp(MyApp());
   }
   ```
