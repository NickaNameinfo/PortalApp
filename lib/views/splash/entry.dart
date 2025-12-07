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
    // Remove fixed delay - check immediately for faster app startup
    bool ifr = await IsFirstRun.isFirstRun();
    
    if (!ifr) {
      // Navigate immediately if not first run
      _navigateToAuthOrHome();
    } else {
      // Only show splash on first run
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          SplashScreen.routeName,
          (route) => false,
        );
      }
    }
  }

  void _navigateToAuthOrHome() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final userRole = prefs.getString('userRole');

    if (!mounted) return;

    // Get root navigator to ensure we're clearing the entire stack
    final navigator = Navigator.of(context, rootNavigator: true);

    if (userId != null && userId.isNotEmpty && userId != '0') {
      // User is logged in - navigate based on role
      if (userRole == "3") {
        // Seller - navigate to seller screen
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const SellerBottomNav(),
            settings: const RouteSettings(name: '/seller-home'),
          ),
          (Route<dynamic> route) => false,
        );
      } else {
        // Customer - navigate to customer screen
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const CustomerBottomNav(),
            settings: const RouteSettings(name: '/customer-home'),
          ),
          (Route<dynamic> route) => false,
        );
      }
    } else {
      // Allow guest access - navigate to customer home without login
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const CustomerBottomNav(),
          settings: const RouteSettings(name: '/customer-home'),
        ),
        (Route<dynamic> route) => false,
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
