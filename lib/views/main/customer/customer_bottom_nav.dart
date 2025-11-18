import 'package:badges/badges.dart' as badges_lib;
import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter/services.dart';
import 'package:nickname_portal/constants/colors.dart';
import 'package:provider/provider.dart';
import '../../../providers/cart.dart';
import 'cart.dart';
import 'favorites.dart';
import 'package:nickname_portal/views/main/customer/order.dart';
import 'package:nickname_portal/views/main/customer/edit_profile.dart';
import 'home.dart';
import 'profile.dart';
import 'map_view_page.dart';
// import 'category.dart';
import '../store/store.dart';
import 'product_screen.dart';

class CustomerBottomNav extends StatefulWidget {
  static const routeName = '/customer-home';

  const CustomerBottomNav({super.key});

  @override
  State<CustomerBottomNav> createState() => _CustomerBottomNavState();
}

class _CustomerBottomNavState extends State<CustomerBottomNav> {
  var currentPageIndex = 0;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final Map<String, WidgetBuilder> _pages = {
    '/': (context) => const HomeScreen(),
    '/products': (context) => const ProductScreen(),
    '/map-view': (context) => const MapViewPage(),
    '/cart': (context) => const CartScreen(),
    '/orders': (context) => const CustomerOrderScreen(),
    '/profile': (context) => const ProfileScreen(),
    EditProfile.routeName: (context) => const EditProfile(),
  };

  void selectPage(int index) {
    setState(() {
      currentPageIndex = index;
    });
    // Navigate to the corresponding route name
    switch (index) {
      case 0:
        _navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
        break;
      case 1:
        _navigatorKey.currentState?.pushNamedAndRemoveUntil('/products', (route) => false);
        break;
      case 2:
        _navigatorKey.currentState?.pushNamedAndRemoveUntil('/map-view', (route) => false);
        break;
      case 3:
        _navigatorKey.currentState?.pushNamedAndRemoveUntil('/cart', (route) => false);
        break;
      case 4:
        _navigatorKey.currentState?.pushNamedAndRemoveUntil('/orders', (route) => false);
        break;
      case 5:
        _navigatorKey.currentState?.pushNamedAndRemoveUntil('/profile', (route) => false);
        break;
    }
  }
  
  // Handle back button/gesture
  Future<bool> _onWillPop() async {
    // First, check if the nested Navigator can pop (has routes in stack)
    if (_navigatorKey.currentState?.canPop() ?? false) {
      _navigatorKey.currentState?.pop();
      return false; // Prevent default back behavior
    }
    
    // If on a different tab (not home), navigate to home tab
    if (currentPageIndex != 0) {
      selectPage(0); // Navigate to home tab
      return false; // Prevent default back behavior
    }
    
    // If on home tab and no nested routes, show exit confirmation
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Do you want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    var cartData = Provider.of<CartData>(context, listen: false);
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
      onWillPop: _onWillPop,
      child: Scaffold(
        bottomNavigationBar: ConvexAppBar(
          backgroundColor: primaryColor,
          color: Colors.white70,
          activeColor: Colors.white,
          initialActiveIndex: currentPageIndex,
          style: TabStyle.reactCircle,
          items: [
            TabItem(
              icon: Icon(
                Icons.store,
                size: currentPageIndex == 0 ? 22 : 18,
                color: currentPageIndex == 0 ? primaryColor : Colors.white70,
              ),
            ),
            TabItem(
              icon: Icon(
                Icons.local_shipping,
                size: currentPageIndex == 1 ? 22 : 18,
                color: currentPageIndex == 1 ? primaryColor : Colors.white70,
              ),
            ),
            TabItem(
              icon: Icon(
                Icons.dashboard_outlined,
                size: currentPageIndex == 2 ? 22 : 18,
                color: currentPageIndex == 2 ? primaryColor : Colors.white70,
              ),
            ),
            TabItem(
              icon: Icon(
                Icons.shopping_bag_outlined,
                size: currentPageIndex == 3 ? 22 : 18,
                color: currentPageIndex == 3 ? primaryColor : Colors.white70,
              ),
            ),
            // TabItem(
            //   icon: Consumer<CartData>(
            //     builder: (context, data, child) => badges_lib.Badge(
            //       badgeContent: Text(
            //         cartData.cartItemCount.toString(),
            //         style: const TextStyle(color: primaryColor),
            //       ),
            //       showBadge: cartData.cartItems.isNotEmpty,
            //       child: Icon(
            //         Icons.shopping_bag_outlined,
            //         size: currentPageIndex == 3 ? 22 : 18,
            //         color: currentPageIndex == 3 ? primaryColor : Colors.white70,
            //       ),
            //     ),
            //   ),
            // ),
            TabItem(
              icon: Icon(
                Icons.receipt_long,
                size: currentPageIndex == 4 ? 22 : 18,
                color: currentPageIndex == 4 ? primaryColor : Colors.white70,
              ),
            ),
            TabItem(
              icon: Icon(
                Icons.person_outline,
                size: currentPageIndex == 5 ? 22 : 18,
                color: currentPageIndex == 5 ? primaryColor : Colors.white70,
              ),
            ),
          ],
          onTap: selectPage,
        ),
        backgroundColor: Colors.grey.shade200,
        body: Navigator(
          key: _navigatorKey,
          initialRoute: '/',
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              builder: _pages[settings.name!]!,
            );
          },
        ),
      ),
    );
  }
}
