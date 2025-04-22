import 'package:chatterapp/Widgets/loading.dart';
import 'package:chatterapp/constants/colorConstants.dart';
import 'package:chatterapp/pages/homeScreen.dart';
import 'package:chatterapp/providers/authentication_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    switch (authProvider.status) {
      case Status.authenticateCanceled:
        Fluttertoast.showToast(msg: 'Sign in canceled');
        break;
      case Status.authenticateError:
        Fluttertoast.showToast(msg: 'Sign in Error');
        break;
      case Status.authenticated:
        Fluttertoast.showToast(msg: 'Sign in success');
        break;
      default:
        break;
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColorConstants.themeColor,
        title: Padding(
          padding: const EdgeInsets.fromLTRB(8.0, 0, 0, 0),
          child: Text('Login page',
              style: TextStyle(
                  color: ColorConstants.primaryColor,
                  fontWeight: FontWeight.w600)),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 80,
                width: 80,
                child: Image.asset(
                  'D:\\Desktop\\APP2\\chatterapp\\assets\\logo.jpg',
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(
                height: 40,
              ),
              Center(
                child: TextButton(
                  onPressed: () {
                    authProvider.handleSignIn().then((isSuccess) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HomeScreen(),
                        ),
                      );
                    }).catchError((error, StackTrace) {
                      Fluttertoast.showToast(msg: error.toString());
                      authProvider.handleException();
                    });
                  },
                  child: Text('Sign in with google',
                      style: TextStyle(
                        color: ColorConstants.primaryColor,
                      )),
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.resolveWith<Color>(
                      (Set<MaterialState> states) {
                        if (states.contains(MaterialState.pressed))
                          return ColorConstants.greyColor2;
                        return ColorConstants.themeColor;
                      },
                    ),
                    splashFactory: NoSplash.splashFactory,
                    padding: MaterialStateProperty.all<EdgeInsets>(
                      EdgeInsets.fromLTRB(30, 15, 30, 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            child: authProvider.status == Status.authenticating
                ? loading_view()
                : SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
