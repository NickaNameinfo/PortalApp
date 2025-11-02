import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:nickname_portal/providers/cart.dart';
import 'package:nickname_portal/providers/order.dart';
import 'package:nickname_portal/views/splash/entry.dart';
import 'package:provider/provider.dart';
import 'constants/colors.dart';
import 'routes/routes.dart';
import 'firebase_options.dart';
// Import your provider file
import 'package:nickname_portal/providers/category_filter_data.dart';
import 'package:marquee/marquee.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        // FIX: Add CategoryFilterData here so HomeScreen widgets can access it
        ChangeNotifierProvider(
          create: (context) => CategoryFilterData(),
        ),
        ChangeNotifierProvider(
          create: (context) => CartData(),
        ),
        ChangeNotifierProvider(
          create: (context) => OrderData(),
        ),
      ],
      child: const MultiVendor(),
    ),
  );
}

class MultiVendor extends StatefulWidget {
  const MultiVendor({super.key});

  @override
  State<MultiVendor> createState() => _MultiVendorState();
}

class _MultiVendorState extends State<MultiVendor> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MultiVendor App',
      theme: ThemeData(
        fontFamily: 'Roboto',
        primaryColor: primaryColor,
      ),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Column(
          children: [
            // --- END MARQUEE BANNER ---
            Expanded(child: child!),
            // --- MARQUEE BANNER ---
            Container(
              color: Colors.red,
              // Use vertical padding for better spacing around text
              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), 
              child: SizedBox(
                // Slightly increase height to ensure text is not clipped
                height: 55.0, 
                child: Marquee(
                  // Using the corrected content for clarity
                  text: '📢 We are currently collaborating with stores and will enable ordering soon.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0, // Ensure font size fits the height
                    // FIX: Set decoration to none to remove the underline/border.
                    decoration: TextDecoration.none, 
                  ),
                  scrollAxis: Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.center, // Center the text vertically
                  blankSpace: 40.0, // Slightly increased blank space
                  velocity: 40.0, // Slightly slower velocity can improve readability
                  pauseAfterRound: const Duration(seconds: 2), // Pause slightly longer
                  startPadding: 10.0,
                  accelerationDuration: const Duration(milliseconds: 500),
                  accelerationCurve: Curves.easeIn,
                  decelerationDuration: const Duration(milliseconds: 500),
                  decelerationCurve: Curves.easeOut,
                ),
              ),
            ),
          ],
        );
      },
      home: const EntryScreen(),
      routes: routes,
    );
  }
}
