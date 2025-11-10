import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:is_first_run/is_first_run.dart';
import 'package:nickname_portal/views/splash/splash.dart';
import '../../components/loading.dart';
import '../../constants/colors.dart';
import 'package:nickname_portal/views/auth/account_type_selector.dart';
import 'package:nickname_portal/views/main/customer/customer_bottom_nav.dart';
import 'package:nickname_portal/views/main/seller/seller_bottom_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EntryScreen extends StatefulWidget {
  static const routeName = '/entry-screen';

  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  Future<void> _startRun() async {
    bool ifr = await IsFirstRun.isFirstRun();
    var duration = const Duration(seconds: 5);
    if (!ifr) {
      Timer(duration, _navigateToAuthOrHome);
    } else {
      Timer(duration, _navigateToSplash);
    }
  }

  void _navigateToSplash() {
    // Routing to Splash
    Navigator.of(context).pushNamedAndRemoveUntil(
      SplashScreen.routeName,
      (route) => false,
    );
  }

  void _navigateToAuthOrHome() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final userRole = prefs.getString('userRole');

    if (!mounted) return;

    if (userId != null) {
      // User is logged in
      if (userRole == "3") {
        Navigator.of(context).pushNamedAndRemoveUntil(
          SellerBottomNav.routeName,
          (route) => false,
        );
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(
          CustomerBottomNav.routeName,
          (route) => false,
        );
      }
    } else {
      // User is not logged in
      Navigator.of(context).pushReplacementNamed(
        AccountTypeSelector.routeName,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _startRun();
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
      body: Container(
        constraints: const BoxConstraints.expand(),
        color: primaryColor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo1.png'),
            const SizedBox(height: 10),
            const Loading(
              color: Colors.white,
              kSize: 40,
            ),
          ],
        ),
      ),
    );
  }
}
