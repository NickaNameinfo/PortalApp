import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nickname_portal/views/auth/forgot_password.dart';
import 'package:http/http.dart' as http;
import '../../components/loading.dart';
import '../../constants/colors.dart';
import '../../helpers/image_picker.dart';
import '../../helpers/secure_http_client.dart';
import '../../helpers/error_handler.dart';
import '../main/customer/customer_bottom_nav.dart';
import '../main/seller/seller_bottom_nav.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// for fields
enum Field {
  fullname,
  email,
  password,
  phone,
}

class Auth extends StatefulWidget {
  static const routeName = '/customer-auth';

  const Auth({
    super.key,
    this.isSellerReg = false,
  });
  final bool isSellerReg;

  @override
  State<Auth> createState() => _AuthState();
}

class _AuthState extends State<Auth> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _fullnameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  var obscure = true; // password obscure value
  var isLogin = true;
  File? profileImage;
  var isLoading = false;
  bool _rememberMe = false;

  // toggle password obscure
  void _togglePasswordObscure() {
    setState(() {
      obscure = !obscure;
    });
  }

  // snackbar for error message
  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        action: SnackBarAction(
          onPressed: () => Navigator.of(context).pop(),
          label: 'Dismiss',
          textColor: Colors.white,
        ),
      ),
    );
  }

  // custom textfield for all form fields
  Widget kTextField(
    TextEditingController controller,
    String hint,
    String label,
    Field field,
    bool obscureText,
  ) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: field == Field.email
          ? TextInputType.emailAddress
          : field == Field.phone
              ? TextInputType.phone
              : TextInputType.text,
      textInputAction:
          field == Field.password ? TextInputAction.done : TextInputAction.next,
      autofocus: field == Field.email ? true : false,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: primaryColor),
        suffixIcon: field == Field.password
            ? (controller.text.isNotEmpty)
                ? IconButton(
                    onPressed: () => _togglePasswordObscure(),
                    icon: Icon(
                      obscure ? Icons.visibility : Icons.visibility_off,
                      color: primaryColor,
                    ),
                  )
                : const SizedBox.shrink()
            : const SizedBox.shrink(),
        hintText: hint,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            width: 2,
            color: primaryColor,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            width: 1,
            color: Colors.grey,
          ),
        ),
      ),
      validator: (value) {
        switch (field) {
          case Field.email:
            if (value == null || value.isEmpty || !value.contains('@')) {
              return 'Email is not valid!';
            }
            break;

          case Field.fullname:
            if (value == null || value.isEmpty || value.length < 3) {
              return 'Fullname is not valid';
            }
            break;

          case Field.password:
            if (value == null || value.isEmpty || value.length < 8) {
              return 'Password needs to be valid';
            }
            break;
          case Field.phone:
            if (value == null || value.isEmpty || value.length < 10) {
              return 'Phone number is not valid';
            }
            break;
        }
        return null;
      },
    );
  }

  // for selecting photo
  void _selectPhoto(File image) {
    setState(() {
      profileImage = image;
    });
  }

  // loading fnc
  void isLoadingFnc() async {
    setState(() {
      isLoading = true;
    });
    if(isLogin){
      final prefs = await SharedPreferences.getInstance();
          final userRole = prefs.getString('userRole');

          if (userRole == "3") {
            // seller account
            Navigator.of(context).pushNamedAndRemoveUntil(
              SellerBottomNav.routeName,
              (route) => false,
            );
          } else {
            // customer account
            Navigator.of(context).pushNamedAndRemoveUntil(
              CustomerBottomNav.routeName,
              (route) => false,
            );
          }
    }else {
      _switchLog();
    }
    
  }

  // handle sign in and  sign up
  Future<Null> _handleAuth() async {
    var valid = _formKey.currentState!.validate();
    FocusScope.of(context).unfocus();
    _formKey.currentState!.save();
    if (!valid) {
      return null;
    }

    setState(() {
      isLoading = true;
    });

    try {
      if (isLogin) {
        // Custom Login API with timeout
        // Note: Login endpoint doesn't require auth token (used to get token)
        final response = await SecureHttpClient.post(
          'https://nicknameinfo.net/api/auth/rootLogin',
          body: {
            'email': _emailController.text.trim(),
            'password': _passwordController.text.trim(),
          },
          timeout: const Duration(seconds: 15),
        );

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          
          // Extract token from multiple possible locations (matching Dashboard Login.tsx)
          // Dashboard checks: user?.data?.token || user?.data?.accessToken || user?.token || user?.accessToken || user?.user?.token
          final token = responseData['data']?['token'] ?? 
                       responseData['data']?['accessToken'] ??
                       responseData['token'] ?? 
                       responseData['accessToken'] ??
                       responseData['user']?['token'];
          
          if (token == null || token.toString().isEmpty) {
            showSnackBar('Login failed: No token received');
            setState(() {
              isLoading = false;
            });
            return;
          }
          
          final userId = responseData['data']['id'];
          final storeId = responseData['data']['storeId'];
          // Handle role as either string or number - convert to string for comparison
          final userRole = (responseData['data']['role'] ?? responseData['role']).toString();
          final phone = responseData['data']['phone'];
          final email = responseData['data']['email'];
          final firstName = responseData['data']['firstName'];
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userId', userId.toString());
          await prefs.setString('storeId', storeId?.toString() ?? '');
          await prefs.setString('userRole', userRole);
          await prefs.setString('phone', phone ?? '');
          await prefs.setString('email', email ?? '');
          await prefs.setString('firstName', firstName ?? '');
          
          // Save token (matching Dashboard - sets both XSRF-token and token cookies)
          // Mobile app uses SharedPreferences, so we save as 'token'
          await prefs.setString('token', token.toString());

          showSnackBar('Login successful!');
          isLoadingFnc();
          
          // Small delay to ensure state is updated and snackbar is shown
          await Future.delayed(const Duration(milliseconds: 300));
          
          if (!mounted) {
            return;
          }
          
          // Get root navigator to ensure we're clearing the entire stack
          final navigator = Navigator.of(context, rootNavigator: true);
          
          // Use MaterialPageRoute directly and clear entire navigation stack
          if (userRole == "3") {
            // Redirect to seller screen - clear all previous routes
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const SellerBottomNav(),
                settings: const RouteSettings(name: '/seller-home'),
              ),
              (Route<dynamic> route) => false, // Remove all previous routes
            );
          } else {
            // For customers
            // Always clear stack and navigate to customer home (don't pop if from dialog)
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const CustomerBottomNav(),
                settings: const RouteSettings(name: '/customer-home'),
              ),
              (Route<dynamic> route) => false, // Remove all previous routes
            );
          }
        } else {
          // Use ErrorHandler for consistent error message extraction
          // Matches Dashboard format: result?.error?.data?.message
          final errorMessage = ErrorHandler.getErrorMessage(response);
          final formattedMessage = ErrorHandler.formatErrorMessage(errorMessage);
          
          // Check if it's an auth error (401)
          if (ErrorHandler.isAuthError(response)) {
            await ErrorHandler.handleUnauthorized(context);
            return;
          }
          
          showSnackBar(formattedMessage);
          setState(() {
            isLoading = false;
          });
        }
      } else {
        if (widget.isSellerReg) {
            try {
              // Store creation - may need auth if user is already logged in
              final storeResponse = await SecureHttpClient.post(
                'https://nicknameinfo.net/api/store/create',
                body: {
                  'storename': _fullnameController.text.trim(),
                  'email': _emailController.text.trim(),
                  'phone': _phoneController.text.trim(),
                  'status': 0,
                  'ownername': _fullnameController.text.trim(),
                  'password': _passwordController.text.trim(),
                  'areaId': 3,
                },
                timeout: const Duration(seconds: 15),
              );

              if (storeResponse.statusCode == 200) {
                // Parse the store response to get the store ID
                final storeData = json.decode(storeResponse.body);
                final storeId = storeData['data']['id'];
                
                // Custom Registration API with timeout
                // Registration endpoint doesn't require auth token
                final response = await SecureHttpClient.post(
                  'https://nicknameinfo.net/api/auth/register',
                  body: {
                    'role': "3",
                    'firstName': _fullnameController.text.trim(),
                    'email': _emailController.text.trim(),
                    'phoneNo': _phoneController.text.trim(),
                    'password': _passwordController.text.trim(),
                    'verify': 1,
                    'storeId': storeId.toString(),
                  },
                  timeout: const Duration(seconds: 15),
                );
                if (response.statusCode == 200) {
                  showSnackBar('Registration successful!');
                  isLoadingFnc();
                } else {
                  showSnackBar('Registration failed: ${response.body}');
                }
              } else {
                showSnackBar('Store creation failed: ${storeResponse.body}');
              }
            } on TimeoutException catch (e) {
              showSnackBar('Store creation timed out. Please try again.');
            } catch (storeError) {
              showSnackBar('Store creation error: $storeError');
            }
        } else {
          // Custom Registration API with timeout
            // Registration endpoint doesn't require auth token
            final response = await SecureHttpClient.post(
              'https://nicknameinfo.net/api/auth/register',
              body: {
                'role': "1",
                'firstName': _fullnameController.text.trim(),
                'email': _emailController.text.trim(),
                'phoneNo': _phoneController.text.trim(),
                'password': _passwordController.text.trim(),
                'verify': 1,
              },
              timeout: const Duration(seconds: 15),
            );
            if (response.statusCode == 200) {
              showSnackBar('Registration successful!');
              isLoadingFnc();
            } else {
              showSnackBar('Registration failed: ${response.body}');
            }
        }
      }
    } on TimeoutException catch (e) {
      showSnackBar(e.message ?? 'Request timed out. Please try again.');
    } on SocketException catch (e) {
      showSnackBar('No internet connection. Please check your network.');
    } catch (error) {
      showSnackBar(error.toString());
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // navigate to forgot password screen
  void _forgotPassword() {
    Navigator.of(context).pushNamed(ForgotPassword.routeName);
  }

  void _switchLog() {
    setState(() {
      isLogin = !isLogin;
      _passwordController.text = "";
    });
  }

  @override
  void initState() {
    _passwordController.addListener(() {
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: litePrimary,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.grey,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                        Center(
                            child: CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 60,
                              child: Image.asset('assets/images/login.png'),
                            ),
                          ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        widget.isSellerReg
                            ? isLogin
                                ? 'Seller Signin'
                                : 'Seller Signup'
                            : isLogin
                                ? 'Signin'
                                : 'Signup',
                        style: const TextStyle(
                          color: primaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    isLoading
                        ? const Center(
                            child: Loading(
                              color: primaryColor,
                              kSize: 70,
                            ),
                          )
                        : Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                kTextField(
                                  _emailController,
                                  'doe@gmail.com',
                                  'Email Address',
                                  Field.email,
                                  false,
                                ),
                                const SizedBox(height: 10),
                                !isLogin
                                    ? kTextField(
                                        _fullnameController,
                                        'John Doe',
                                        'Fullname',
                                        Field.fullname,
                                        false,
                                      )
                                    : const SizedBox.shrink(),
                                SizedBox(height: isLogin ? 0 : 10),
                                !isLogin
                                    ? kTextField(
                                        _phoneController,
                                        '0712345678',
                                        'Phone Number',
                                        Field.phone,
                                        false,
                                      )
                                    : const SizedBox.shrink(),
                                SizedBox(height: isLogin ? 0 : 10),
                                kTextField(
                                  _passwordController,
                                  '********',
                                  'Password',
                                  Field.password,
                                  obscure,
                                ),
                                const SizedBox(height: 10), // Added for spacing
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: _rememberMe,
                                          onChanged: (value) {
                                            setState(() {
                                              _rememberMe = value!;
                                            });
                                          },
                                        ),
                                        const Text('Remember Me'),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () => _forgotPassword(),
                                      child: const Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20), // Adjusted spacing
                                Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: const EdgeInsets.all(15),
                                    ),
                                    icon: const Icon(
                                      // Changed to const Icon
                                      Icons
                                          .arrow_forward, // Changed icon to arrow_forward
                                      color: Colors.white,
                                    ),
                                    onPressed: () => _handleAuth(),
                                    label: const Text(
                                      // Changed to const Text
                                      'LOGIN', // Changed text to LOGIN
                                      style: TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                // const SizedBox(height: 10),
                                // ElevatedButton(
                                //   style: ElevatedButton.styleFrom(
                                //     backgroundColor: Colors.white,
                                //     shape: RoundedRectangleBorder(
                                //       borderRadius: BorderRadius.circular(20),
                                //     ),
                                //     padding: const EdgeInsets.all(15),
                                //   ),
                                //   onPressed: () => _googleAuth(),
                                //   child: Row(
                                //     mainAxisAlignment: MainAxisAlignment.center,
                                //     children: [
                                //       Image.asset(
                                //         'assets/images/google.png',
                                //         width: 20,
                                //       ),
                                //       const SizedBox(width: 20),
                                //       Text(
                                //         isLogin
                                //             ? 'Signin with google'
                                //             : 'Signup with google',
                                //         style: const TextStyle(
                                //             color: Colors.grey,
                                //             fontWeight: FontWeight.w600),
                                //       ),
                                //     ],
                                //   ),
                                // ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment
                                      .center, // Centered the row
                                  children: [
                                    const Text(
                                      // Added const
                                      'Not A Member ?', // Changed text
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _switchLog(),
                                      child: Text(
                                        // Changed to const Text
                                        isLogin ? 'Register Now' : 'Login Now', // Changed text
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          )
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}