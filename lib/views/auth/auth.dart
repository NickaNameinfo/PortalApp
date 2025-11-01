import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:multivendor_shop/views/auth/forgot_password.dart';
import 'package:http/http.dart' as http;
import '../../components/loading.dart';
import '../../constants/colors.dart';
import '../../helpers/image_picker.dart';
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
  final _auth = FirebaseAuth.instance;
  final firebase = FirebaseFirestore.instance;

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
  void isLoadingFnc() {
    setState(() {
      isLoading = true;
    });
    // Timer(const Duration(seconds: 5), () {
      if (widget.isSellerReg) {
        // seller account
        Navigator.of(context).pushNamed(SellerBottomNav.routeName);
      } else {
        // customer account
        Navigator.of(context).pushNamed(CustomerBottomNav.routeName);
      }
    // });
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
        // Custom Login API
        final url = Uri.parse('https://nicknameinfo.net/api/auth/rootLogin');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'email': _emailController.text.trim(),
            'password': _passwordController.text.trim(),
          }),
        );

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          final userId = responseData['data']['id'];
          final storeId = responseData['data']['storeId'];
          final userRole = responseData['data']['role'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userId', userId.toString());
          await prefs.setString('storeId', storeId.toString());
          await prefs.setString('userRole', userRole);
          showSnackBar('Login successful!');
          isLoadingFnc();
          if (userRole == "3") {
            // Redirect to seller screen
            Navigator.of(context).pushReplacementNamed(SellerBottomNav.routeName); // Assuming a route named '/seller-screen'
          }
        } else {
          final errorResponse = json.decode(response.body);
          if (errorResponse.containsKey('errors') &&
              errorResponse['errors'] is List &&
              (errorResponse['errors'] as List).contains('Invalid Credentials')) {
            showSnackBar('Invalid email or password. Please try again.');
          } else {
            showSnackBar('Login failed: ${response.body}');
          }
        }
      } else {
        print(_phoneController);
        // Custom Registration API
        final url = Uri.parse('https://nicknameinfo.net/api/auth/register');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'role': widget.isSellerReg ? "2" : "1",
            'firstName': _fullnameController.text.trim(),
            'email': _emailController.text.trim(),
            'phoneNo': _phoneController.text.trim(),
            'password': _passwordController.text.trim(),
            'verify': 1,
          }),
        );

        if (response.statusCode == 200) {
          showSnackBar('Registration successful!');
          isLoadingFnc();
        } else {
          showSnackBar('Registration failed: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AN ERROR OCCURRED! $e');
      }
      showSnackBar('An unexpected error occurred. Check your internet connection.');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // authenticate using Google
  Future<UserCredential> _googleAuth() async {
    // Trigger the authentication flow
    final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();

    // Obtain the auth details from the request
    final GoogleSignInAuthentication? googleAuth = googleUser?.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth?.idToken,
    );

    try {
      // send username, email, and phone number to firestore
      var logCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      if (widget.isSellerReg) {
        await FirebaseFirestore.instance
            .collection('sellers')
            .doc(logCredential.user!.uid)
            .set(
          {
            'fullname': googleUser!.displayName,
            'email': googleUser.email,
            'image': googleUser.photoUrl,
            'auth-type': 'google',
            'phone': _phoneController.text.trim(),
            'address': '',
          },
        ).then((value) {
          isLoadingFnc();
        });
      } else {
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(logCredential.user!.uid)
            .set(
          {
            'fullname': googleUser!.displayName,
            'email': googleUser.email,
            'image': googleUser.photoUrl,
            'auth-type': 'google',
            'phone': _phoneController.text.trim(),
            'address': '',
          },
        ).then((value) {
          isLoadingFnc();
        });
      }
    } on FirebaseAuthException catch (e) {
      var error = 'An error occurred. Check credentials!';
      if (e.message != null) {
        error = e.message!;
      }
      showSnackBar(error); // showSnackBar will show error if any
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    // sign in with credential
    return FirebaseAuth.instance.signInWithCredential(credential);
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
                                ? 'Customer Signin'
                                : 'Customer Signup',
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
                                          value:
                                              false, // You'll need to manage this state
                                          onChanged: (value) {
                                            // Handle remember me logic
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