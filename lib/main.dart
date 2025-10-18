import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:multivendor_shop/providers/cart.dart';
import 'package:multivendor_shop/providers/order.dart';
import 'package:multivendor_shop/views/splash/entry.dart';
import 'package:provider/provider.dart';
import 'constants/colors.dart';
import 'routes/routes.dart';
import 'firebase_options.dart';
// Import your provider file
import 'package:multivendor_shop/providers/category_filter_data.dart'; 
// Import your Home Screen (Though not directly used in runApp, it's good practice)
import 'package:multivendor_shop/views/main/customer/home.dart'; 

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
      home: const EntryScreen(),
      routes: routes,
    );
  }
}