import 'package:chatterapp/constants/colorConstants.dart';
import 'package:chatterapp/pages/homeScreen.dart';
import 'package:chatterapp/pages/login_page.dart';
import 'package:chatterapp/providers/authentication_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    Future.delayed(Duration(seconds: 1), () {
      _checkSignedIn();
    });
    super.initState();
  }

  void _checkSignedIn() async {
    final authProvider = context.read<AuthProvider>();
    bool isLoggedIn = await authProvider.isLoggedIn();

    if (isLoggedIn) {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (
            context,
          ) =>
                  HomeScreen()));
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              child: Image.asset(
                'D:\\Desktop\\APP2\\chatterapp\\lib\\assets\\logo.jpg',
                fit: BoxFit.cover,
              ),
              height: 80,
              width: 80,
            ),
            SizedBox(
              height: 40,
            ),
            Container(
              height: 40,
              width: 40,
              child: CircularProgressIndicator(
                color: ColorConstants.themeColor,
              ),
            )
          ],
        ),
      ),
    );
  }
}
