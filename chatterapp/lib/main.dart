import 'package:chatterapp/constants/appConstants.dart';
import 'package:chatterapp/constants/colorConstants.dart';
import 'package:chatterapp/firebase_options.dart';
import 'package:chatterapp/pages/chatScreen.dart';
import 'package:chatterapp/pages/homeScreen.dart';
import 'package:chatterapp/pages/splash_page.dart';
import 'package:chatterapp/providers/authentication_provider.dart';
import 'package:chatterapp/providers/chat_provider.dart';
import 'package:chatterapp/providers/home_provider.dart';
import 'package:chatterapp/providers/settings_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SharedPreferences prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  MyApp({super.key, required this.prefs});
  final _firebaseFirestore = FirebaseFirestore.instance;
  final _firebaseStorage = FirebaseStorage.instance;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(
                firebaseStorage: _firebaseStorage,
                firebaseAuth: FirebaseAuth.instance,
                googleSignIn: GoogleSignIn(
                    clientId:
                        '608591321767-cet6hs5nsa7qrtlo1fqf4i2gv4ojj5k2.apps.googleusercontent.com'),
                firebaseFirestore: this._firebaseFirestore,
                prefs: this.prefs)),
        Provider(
            create: (_) => SettingProvider(
                prefs: prefs,
                firebaseFirestore: _firebaseFirestore,
                firebaseStorage: _firebaseStorage)),
        Provider(
            create: (_) => ChatProvider(
                firebaseFirestore: _firebaseFirestore,
                firebaseStorage: _firebaseStorage,
                prefs: prefs)),
        Provider(
            create: (_) => HomeProvider(firebaseFirestore: _firebaseFirestore))
      ],
      child: MaterialApp(
        title: AppConstants.appTitle,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: ColorConstants.themeColor,
        ),
        home: SplashPage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
