import 'dart:async';
import 'dart:io';

import 'package:chatterapp/Widgets/loading.dart';
import 'package:chatterapp/constants/appConstants.dart';
import 'package:chatterapp/constants/colorConstants.dart';
import 'package:chatterapp/constants/firestoreConstants.dart';
import 'package:chatterapp/models/menuSettings.dart';
import 'package:chatterapp/models/user_chart.dart';
import 'package:chatterapp/pages/chatScreen.dart';
import 'package:chatterapp/pages/login_page.dart';
import 'package:chatterapp/pages/settings.dart';
import 'package:chatterapp/providers/authentication_provider.dart';
import 'package:chatterapp/providers/home_provider.dart';
import 'package:chatterapp/utils/debouncer.dart';
import 'package:chatterapp/utils/utilities.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchDebouncer = Debouncer(milliseconds: 25);
  final TextEditingController _searchBarController = TextEditingController();
  final ScrollController _listScrollController = ScrollController();
  final StreamController<bool> _btnClearController = StreamController<bool>();
  final _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final _firebaseMessaging = FirebaseMessaging.instance;

  late final _authProvider = context.read<AuthProvider>();
  late final _homeProvider = context.read<HomeProvider>();
  late final String _currentUserId;

  int _limit = 20;
  final int _limitIncrement = 20;
  String _textSearch = "";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (_authProvider.userFirebaseId?.isNotEmpty == true) {
      _currentUserId = _authProvider.userFirebaseId!;
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginPage()),
        (_) => false,
      );
    }
    _listScrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _btnClearController.close();
    _searchBarController.dispose();
    _listScrollController
      ..removeListener(_scrollListener)
      ..dispose();
    super.dispose();
  }

  void _showNotification(RemoteNotification remoteNotification) async {
    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      Platform.isAndroid ? 'com.dfa.chatterBox' : 'com.duytq.chatterBox',
      'Chattter Box',
      playSound: true,
      enableVibration: true,
      importance: Importance.max,
      priority: Priority.high,
    );
    final iOSPlatformChannelSpecifics = DarwinNotificationDetails();
    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    print(remoteNotification);

    await _flutterLocalNotificationsPlugin.show(
      0,
      remoteNotification.title,
      remoteNotification.body,
      platformChannelSpecifics,
      payload: null,
    );
  }

  Future<void> _handleSignOut() async {
    await _authProvider.handleSignOut();
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginPage()),
      (_) => false,
    );
  }

  void _registerNotification() {
    _firebaseMessaging.requestPermission();

    FirebaseMessaging.onMessage.listen((message) {
      print('onMessage: $message');
      if (message.notification != null) {
        _showNotification(message.notification!);
      }
      return;
    });

    _firebaseMessaging.getToken().then((token) {
      print('push token: $token');
      if (token != null) {
        _homeProvider.updateDataFirestore(FirestoreConstants.pathUserCollection,
            _currentUserId, {'pushToken': token});
      }
    }).catchError((err) {
      Fluttertoast.showToast(msg: err.message.toString());
    });
  }

  void _configLocalNotification() {
    final initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');
    final initializationSettingsIOS = DarwinInitializationSettings();
    final initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void _scrollListener() {
    if (_listScrollController.offset >=
            _listScrollController.position.maxScrollExtent &&
        !_listScrollController.position.outOfRange) {
      setState(() {
        _limit += _limitIncrement;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColorConstants.themeColor,
        title: Text(
          AppConstants.appTitle,
          style: TextStyle(color: ColorConstants.primaryColor),
        ),
        centerTitle: true,
        actions: [_buildPopupMenu()],
      ),
      body: SafeArea(
        child: Stack(children: [
          Column(
            children: [
              _buildSearchBar(),
              Expanded(
                  child: StreamBuilder(
                      stream: _homeProvider.getStreamFirestore(
                        _currentUserId,
                        FirestoreConstants.pathUserCollection,
                        _limit,
                        _textSearch,
                      ),
                      builder: (_, snapshot) {
                        if (snapshot.hasData == true) {
                          if ((snapshot.data?.docs.length ?? 0) > 0) {
                            return ListView.builder(
                              padding: EdgeInsets.all(10),
                              itemBuilder: (_, index) =>
                                  itemBuild(snapshot.data?.docs[index]),
                              itemCount: snapshot.data?.docs.length,
                              controller: _listScrollController,
                            );
                          } else {
                            return Center(
                              child: Text('No user found'),
                            );
                          }
                        } else {
                          return Center(
                            child: CircularProgressIndicator(
                              color: ColorConstants.themeColor,
                            ),
                          );
                        }
                      })),
            ],
          ),
          Positioned(
            child: _isLoading ? loading_view() : SizedBox.shrink(),
          )
        ]),
      ),
    );
  }

  Widget _buildPopupMenu() {
    return PopupMenuButton<MenuSetting>(
      onSelected: _onItemMenuPress,
      itemBuilder: (_) {
        return _menu.map((choice) {
          return PopupMenuItem<MenuSetting>(
            value: choice,
            child: Row(
              children: [
                Icon(
                  choice.icon,
                  color: ColorConstants.primaryColor,
                ),
                const SizedBox(width: 10),
                Text(
                  choice.title,
                  style: TextStyle(color: ColorConstants.primaryColor),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  final List<MenuSetting> _menu = [
    MenuSetting(title: 'Profile', icon: Icons.account_circle),
    MenuSetting(title: 'Log out', icon: Icons.exit_to_app),
  ];

  void _onItemMenuPress(MenuSetting choice) {
    if (choice.title == "Log out") {
      // Handle logout
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => settingPage()));
    }
  }

  Widget itemBuild(DocumentSnapshot? document) {
    if (document != null) {
      final userChat = UserChat.fromDocument(document);
      return Container(
        margin: const EdgeInsets.only(bottom: 10, left: 5, right: 5),
        child: TextButton(
          child: Row(
            children: [
              ClipOval(
                child: userChat.photoUrl.isNotEmpty
                    ? Image.network(
                        userChat.photoUrl,
                        fit: BoxFit.cover,
                        width: 50,
                        height: 50,
                        loadingBuilder: (_, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 50,
                            height: 50,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: ColorConstants.themeColor,
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, object, stackTrace) {
                          return Icon(
                            Icons.account_circle,
                            size: 50,
                            color: ColorConstants.greyColor,
                          );
                        },
                      )
                    : Icon(
                        Icons.account_circle,
                        size: 50,
                        color: ColorConstants.greyColor,
                      ),
              ),
              Flexible(
                child: Container(
                  child: Column(
                    children: [
                      Container(
                        child: Text(
                          userChat.nickname,
                          maxLines: 1,
                          style: TextStyle(color: ColorConstants.primaryColor),
                        ),
                        alignment: Alignment.centerLeft,
                        margin: EdgeInsets.fromLTRB(10, 0, 0, 5),
                      ),
                      Container(
                        child: Text(
                          userChat.aboutMe,
                          maxLines: 1,
                          style: TextStyle(color: ColorConstants.primaryColor),
                        ),
                        alignment: Alignment.centerLeft,
                        margin: EdgeInsets.fromLTRB(10, 0, 0, 0),
                      )
                    ],
                  ),
                  margin: EdgeInsets.only(left: 20),
                ),
              ),
            ],
          ),
          onPressed: () {
            if (Utilities.isKeyboardShowing(context)) {
              Utilities.closeKeyboard();
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Chatscreen(
                  arguments: ChatPageArguments(
                    peerId: userChat.id,
                    peerAvatar: userChat.photoUrl,
                    peerNickname: userChat.nickname,
                  ),
                ),
              ),
            );
          },
          style: ButtonStyle(
            backgroundColor:
                MaterialStateProperty.all<Color>(ColorConstants.greyColor2),
            shape: MaterialStateProperty.all<OutlinedBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          ),
        ),
      );
    } else {
      return Center(
        child: Text('HEY HI IYKYK'),
      );
    }
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.search, color: ColorConstants.greyColor, size: 20),
          SizedBox(width: 5),
          Expanded(
            child: TextFormField(
              textInputAction: TextInputAction.search,
              controller: _searchBarController,
              onChanged: (value) {
                _searchDebouncer.run(
                  () {
                    if (value.isNotEmpty) {
                      _btnClearController.add(true);
                      setState(() {
                        _textSearch = value;
                      });
                    } else {
                      _btnClearController.add(false);
                      setState(() {
                        _textSearch = "";
                      });
                    }
                  },
                );
              },
              decoration: InputDecoration.collapsed(
                hintText: 'Search by nickname (type exactly case sensitive)',
                hintStyle:
                    TextStyle(fontSize: 13, color: ColorConstants.greyColor),
              ),
              style: TextStyle(fontSize: 13),
            ),
          ),
          StreamBuilder<bool>(
            stream: _btnClearController.stream,
            builder: (_, snapshot) {
              return snapshot.data == true
                  ? GestureDetector(
                      onTap: () {
                        _searchBarController.clear();
                        _btnClearController.add(false);
                        setState(() {
                          _textSearch = "";
                        });
                      },
                      child: Icon(Icons.clear_rounded,
                          color: ColorConstants.greyColor, size: 20))
                  : SizedBox.shrink();
            },
          ),
        ],
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: ColorConstants.greyColor2,
      ),
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
      margin: EdgeInsets.fromLTRB(16, 8, 16, 8),
    );
  }
}
