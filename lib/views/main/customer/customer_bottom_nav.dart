import 'package:badges/badges.dart' as badges_lib;
import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter/services.dart';
import 'package:multivendor_shop/constants/colors.dart';
import 'package:provider/provider.dart';
import '../../../providers/cart.dart';
import 'cart.dart';
import 'favorites.dart';
import 'order.dart';
import 'home.dart';
import 'profile.dart';
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
  final _pages = const [
    HomeScreen(),
    ProductScreen(),
    StoreScreen(),
    CartScreen(),
    CustomerOrderScreen(),
    ProfileScreen(),
  ];

  void selectPage(var index) {
    setState(() {
      currentPageIndex = index;
    });
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
          const TabItem(
            icon: Icons.store,
          ),
          const TabItem(
            icon: Icons.local_shipping,
          ),
          const TabItem(
            icon: Icons.map,
          ),
          TabItem(
            icon: Consumer<CartData>(
              builder: (context, data, child) => badges_lib.Badge(
                badgeContent: Text(
                        cartData.cartItemCount.toString(),
                        style: const TextStyle(
                          color: primaryColor,
                        ),
                      )
                   ,
               showBadge: cartData.cartItems.isNotEmpty ? true:false,
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: currentPageIndex == 3 ? 40 : 25,
                  color: currentPageIndex == 3 ? primaryColor : Colors.white70,
                ),
              ),
            ),
          ),

          const TabItem(
            icon: Icons.receipt_long,
          ),
          const TabItem(
            icon: Icons.person_outline,
          )
        ],
        onTap: selectPage,
      ),
      backgroundColor: Colors.grey.shade200,
      body: _pages[currentPageIndex],
    );
  }
}
