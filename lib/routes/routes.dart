import 'package:flutter/material.dart';
import 'package:nickname_portal/views/auth/auth.dart';
import 'package:nickname_portal/views/auth/forgot_password.dart';
import 'package:nickname_portal/views/main/customer/edit_profile.dart';
import 'package:nickname_portal/views/main/seller/dashboard_screens/account_balance.dart';
import 'package:nickname_portal/views/main/seller/dashboard_screens/manage_products.dart';
import 'package:nickname_portal/views/main/seller/dashboard_screens/orders.dart';
import 'package:nickname_portal/views/main/seller/dashboard_screens/statistics.dart';
import 'package:nickname_portal/views/main/seller/dashboard_screens/store_setup.dart';
import 'package:nickname_portal/views/main/seller/seller_bottom_nav.dart';
import '../views/auth/account_type_selector.dart';
import '../views/main/customer/customer_bottom_nav.dart';
import '../views/main/customer/order.dart';
import 'package:nickname_portal/views/main/customer/map_view_page.dart';
import 'package:nickname_portal/views/main/seller/dashboard_screens/edit_product.dart';
import 'package:nickname_portal/views/main/seller/dashboard_screens/upload_product.dart';
import 'package:nickname_portal/views/main/seller/dashboard_screens/subscription_screen.dart';
import '../views/splash/entry.dart';
import '../views/splash/splash.dart';

var routes = {
  Auth.routeName: (context) => const Auth(),
  ForgotPassword.routeName: (context) => const ForgotPassword(),
  AccountTypeSelector.routeName: (context) => const AccountTypeSelector(),
  SplashScreen.routeName: (context) => const SplashScreen(),
  EntryScreen.routeName: (context) => const EntryScreen(),
  CustomerBottomNav.routeName: (context) => const CustomerBottomNav(),
  SellerBottomNav.routeName: (context) => const SellerBottomNav(),
  ManageProductsScreen.routeName: (context) => const ManageProductsScreen(),
  UploadProduct.routeName: (context) => const UploadProduct(),
  OrdersScreen.routeName: (context) => const OrdersScreen(),
  StoreSetupScreen.routeName: (context) => const StoreSetupScreen(),
  StatisticsScreen.routeName: (context) => const StatisticsScreen(),
  AccountBalanceScreen.routeName: (context) => const AccountBalanceScreen(),
  MapViewPage.routeName: (context) => const MapViewPage(),
  '/subscription-screen': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>;
    return SubscriptionScreen(customerId: args['customerId']!, subscriptionType: args['subscriptionType']!);
  },
  '/seller-screen': (context) => const SellerBottomNav(),
};
