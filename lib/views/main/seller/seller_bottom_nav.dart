import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter/services.dart';
import 'package:nickname_portal/constants/colors.dart';
import 'package:nickname_portal/components/gradient_background.dart';
import 'dashboard.dart';
import 'home.dart';
import 'profile.dart';
import 'category.dart';
import '../store/store.dart';

class SellerBottomNav extends StatefulWidget {
  static const routeName = '/seller-home';

  const SellerBottomNav({super.key});

  @override
  State<SellerBottomNav> createState() => _SellerBottomNavState();
}

class _SellerBottomNavState extends State<SellerBottomNav> {
  var currentPageIndex = 0;
  final _pages =  [
    DashboardScreen(),
    const CategoryScreen(),
    // const StoreScreen(),
    const ProfileScreen(),
  ];
  static const _titles = ["Dashboard", "Categories", "Profile"];

  void selectPage(var index) {
    setState(() {
      currentPageIndex = index;
    });
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
    return WillPopScope(
      onWillPop: () async {
        if (currentPageIndex != 0) {
          setState(() {
            currentPageIndex = 0; // Navigate to DashboardScreen
          });
          return false; // Prevent popping the route
        }
        return true; // Allow popping the route (e.g., to login screen)
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          toolbarHeight: 48,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: brandHeaderGradient,
            ),
          ),
          title: Text(
            _titles[currentPageIndex],
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: ConvexAppBar(
                backgroundColor: primaryColor,
                gradient: brandFooterGradient,
                shadowColor: Colors.transparent,
                elevation: 0,
                height: 50,
                top: -2,
                color: Colors.white70,
                activeColor: accentColor,
                initialActiveIndex: currentPageIndex,
                style: TabStyle.react,
                items: const [
                  TabItem(
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icon(Icons.dashboard_outlined, size: 20, color: Colors.white),
                  ),
                  TabItem(
                    icon: Icons.category_outlined,
                    activeIcon: Icon(Icons.category_outlined, size: 20, color: Colors.white),
                  ),
                  TabItem(
                    icon: Icons.person_outline,
                    activeIcon: Icon(Icons.person_outline, size: 20, color: Colors.white),
                  ),
                ],
                onTap: selectPage,
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: gradientBackgroundDecoration,
          child: _pages[currentPageIndex],
        ),
      ),
    );
  }
}
