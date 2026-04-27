import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nickname_portal/views/auth/auth.dart';
import '../../constants/colors.dart';

class AccountTypeSelector extends StatefulWidget {
  static const routeName = '/account-type-selector';

  const AccountTypeSelector({super.key});

  @override
  State<AccountTypeSelector> createState() => _AccountTypeSelectorState();
}

class _AccountTypeSelectorState extends State<AccountTypeSelector> {
  var typeIndex = 0;
  var accountType = ['Customer Account', 'Seller Account'];

  Widget kContainer(int index) {
    final isSelected = typeIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        typeIndex = index;
      }),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFFFF), Color(0xFFF4F7FF)],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.10),
          border: Border.all(
            width: isSelected ? 2 : 1,
            color: isSelected ? accentColor : Colors.white.withOpacity(0.35),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/profile.png',
                color: isSelected ? primaryColor : Colors.white,
                width: 88,
              ),
              const SizedBox(height: 8),
              Text(
                accountType[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.black87 : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToSection() {
    if (typeIndex == 0) {
      // registering as a customer
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const Auth(),
        ),
      );
    } else {
      // registering as a seller
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const Auth(
            isSellerReg: true,
          ),
        ),
      );
    }
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
        decoration: const BoxDecoration(
          gradient: brandHeaderGradient,
        ),
        constraints: const BoxConstraints.expand(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Text(
                  "Choose account type",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Continue as customer or seller",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                LayoutBuilder(
                  builder: (context, c) {
                    final isTight = c.maxWidth < 360;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        SizedBox(
                          width: isTight ? c.maxWidth : (c.maxWidth - 14) / 2,
                          child: kContainer(0),
                        ),
                        SizedBox(
                          width: isTight ? c.maxWidth : (c.maxWidth - 14) / 2,
                          child: kContainer(1),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: _navigateToSection,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          "Continue",
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, color: primaryColor, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
