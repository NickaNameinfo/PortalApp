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
    return Scaffold(
      bottomNavigationBar: ConvexAppBar(
        backgroundColor: primaryColor,
        activeColor: Colors.white,
        initialActiveIndex: currentPageIndex,
        style: TabStyle.reactCircle,
        items: [
          const TabItem(icon: Icons.store),
          const TabItem(icon: Icons.local_shipping),
          const TabItem(icon: Icons.map),
          TabItem(
            icon: Consumer<CartData>(
              builder: (context, data, child) => badges_lib.Badge(
                badgeContent: Text(
                  cartData.cartItemCount.toString(),
                  style: const TextStyle(color: primaryColor),
                ),
                showBadge: cartData.cartItems.isNotEmpty,
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: currentPageIndex == 3 ? 40 : 25,
                  color: currentPageIndex == 3 ? primaryColor : Colors.white70,
                ),
              ),
            ),
          ),
          const TabItem(icon: Icons.receipt_long),
          const TabItem(icon: Icons.person_outline),
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
    );
  }
}
