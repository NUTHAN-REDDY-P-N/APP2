import 'dart:io';
import 'dart:typed_data' show Uint8List; // Import for web file handling
import 'package:chatterapp/constants/colorConstants.dart';
import 'package:chatterapp/constants/firestoreConstants.dart';
import 'package:chatterapp/models/user_chart.dart';
import 'package:chatterapp/providers/settings_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../Widgets/loading.dart';

class settingPage extends StatefulWidget {
  const settingPage({super.key});

  @override
  State<settingPage> createState() => _settingPageState();
}

class _settingPageState extends State<settingPage> {
  late TextEditingController _nickNameController = TextEditingController();
  late TextEditingController _aboutMeController = TextEditingController();

  String _userId = "";
  String _nickName = "";
  String _aboutMe = "";
  String _avatarUrl = "";

  bool isLoading = false;
  File? _avatarfile;
  Uint8List? _webAvatarfile;

  late final _settingsProvider = context.read<SettingProvider>();

  final _focusNodeNickname = FocusNode();
  final _focusNodeAboutMe = FocusNode();
  @override
  void initState() {
    _readLocal();
    super.initState();
  }

  void _readLocal() {
    setState(() {
      _userId = _settingsProvider.getPref(FirestoreConstants.id) ?? " ";
      _nickName = _settingsProvider.getPref(FirestoreConstants.nickname) ?? "";
      _aboutMe = _settingsProvider.getPref(FirestoreConstants.aboutMe) ?? "";
      _avatarUrl = _settingsProvider.getPref(FirestoreConstants.photoUrl) ?? "";
    });
    _nickNameController = TextEditingController(text: _nickName);
    _aboutMeController = TextEditingController(text: _aboutMe);
  }

  Future _pickAvatar() async {
    try {
      if (kIsWeb) {
        // Web: Use FilePicker for better compatibility
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
        );

        if (result != null && result.files.isNotEmpty) {
          Uint8List webImage = result.files.first.bytes!;
          setState(() {
            _webAvatarfile = webImage; // Store Uint8List for web
            isLoading = false;
          });
          return true;
        }
      } else {
        // Mobile: Use ImagePicker
        final imagePicker = ImagePicker();
        final pickedImage = await imagePicker.pickImage(
          source: ImageSource.gallery,
        );

        if (pickedImage != null) {
          final imageFile = File(pickedImage.path);
          setState(() {
            _avatarfile = imageFile; // Store File for mobile
            isLoading = false;
          });
          return true;
        }
      }
    } catch (err) {
      Fluttertoast.showToast(msg: err.toString());
    }

    return false;
  }

  Future uploadFile() async {
    final fileName = FirestoreConstants.id;
    UploadTask uploadTask;

    if (kIsWeb && _webAvatarfile != null) {
      // Convert Uint8List to Firebase Upload
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      uploadTask = FirebaseStorage.instance
          .ref()
          .child(fileName)
          .putData(_webAvatarfile!, metadata);
    } else if (_avatarfile != null) {
      uploadTask =
          FirebaseStorage.instance.ref().child(fileName).putFile(_avatarfile!);
    } else {
      return;
    }

    try {
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();

      setState(() {
        _avatarUrl = url;
        isLoading = false;
      });

      final updateInfo = UserChat(
        id: _userId,
        photoUrl: _avatarUrl,
        nickname: _nickName,
        aboutMe: _aboutMe,
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "unable to get url");
    }
  }

  void handleUpdateData() {
    _focusNodeNickname.unfocus();
    _focusNodeAboutMe.unfocus();

    setState(() {
      isLoading = true;
    });
    UserChat updateInfo = UserChat(
        id: _userId,
        photoUrl: _avatarUrl,
        nickname: _nickName,
        aboutMe: _aboutMe);

    _settingsProvider
        .updateDataFirestore(
            FirestoreConstants.pathUserCollection, _userId, updateInfo.toJson())
        .then((_) async {
      await _settingsProvider.setPref(FirestoreConstants.nickname, _nickName);
      await _settingsProvider.setPref(FirestoreConstants.aboutMe, _aboutMe);
      await _settingsProvider.setPref(FirestoreConstants.photoUrl, _avatarUrl);
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: "update success");
    }).catchError((err) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: err.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColorConstants.themeColor,
        title: Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 0, 0, 0),
          child: Text('UserProfile',
              style: TextStyle(
                  color: ColorConstants.primaryColor,
                  fontWeight: FontWeight.w600)),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoButton(
                  onPressed: () {
                    _pickAvatar().then((isSucess) {
                      if (isSucess) {
                        uploadFile();
                      }
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.all(20),
                    child: _avatarfile == null
                        ? _avatarUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(40),
                                child: Image.network(
                                  _avatarUrl,
                                  fit: BoxFit.cover,
                                  height: 90,
                                  width: 90,
                                  errorBuilder: (_, __, ___) {
                                    return Icon(
                                      Icons.account_circle,
                                      size: 90,
                                      color: ColorConstants.greyColor,
                                    );
                                  },
                                  loadingBuilder: (_, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: 90,
                                      height: 90,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: ColorConstants.themeColor,
                                          value: loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.account_circle,
                                size: 90,
                                color: ColorConstants.greyColor,
                              )
                        : ClipOval(
                            child: kIsWeb
                                ? (_webAvatarfile != null
                                    ? Image.memory(
                                        _webAvatarfile!,
                                        height: 90,
                                        width: 90,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(Icons.person,
                                        size:
                                            90)) // Placeholder for web if no image is selected
                                : (_avatarfile != null
                                    ? Image.file(
                                        _avatarfile!,
                                        height: 90,
                                        width: 90,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(Icons.person,
                                        size:
                                            90)), // Placeholder for mobile if no image is selected
                          ),
                  ),
                ),
                Column(
                  children: [
                    Container(
                      margin: EdgeInsets.only(left: 10, bottom: 5, top: 10),
                      child: Text(
                        'Username',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                          color: ColorConstants.primaryColor,
                        ),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(left: 30, right: 30),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                            primaryColor: ColorConstants.primaryColor),
                        child: TextField(
                          controller: _nickNameController,
                          onChanged: (value) {
                            _nickName = value;
                          },
                          decoration: InputDecoration(
                            hintText: "you really want a hint for Username?",
                            contentPadding: EdgeInsets.all(5),
                            hintStyle:
                                TextStyle(color: ColorConstants.greyColor),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(left: 10, bottom: 5, top: 10),
                      child: Text(
                        'AboutMe',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                          color: ColorConstants.primaryColor,
                        ),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(left: 30, right: 30),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                            primaryColor: ColorConstants.primaryColor),
                        child: TextField(
                          onChanged: (value) {
                            _aboutMe = value;
                          },
                          controller: _aboutMeController,
                          decoration: InputDecoration(
                            hintText: "It's about you not me",
                            contentPadding: EdgeInsets.all(5),
                            hintStyle:
                                TextStyle(color: ColorConstants.greyColor),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      child: TextButton(
                        onPressed: () {
                          handleUpdateData();
                        },
                        child: Text(
                          'Update',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: ColorConstants.greyColor2),
                        ),
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all<Color>(
                              ColorConstants.primaryColor),
                          padding: MaterialStateProperty.all<EdgeInsets>(
                            EdgeInsets.fromLTRB(30, 10, 30, 10),
                          ),
                        ),
                      ),
                      margin: EdgeInsets.only(top: 50, bottom: 50),
                    )
                  ],
                ),
              ],
            ),
            padding: EdgeInsets.only(left: 15, right: 15),
          ),
          Positioned(child: isLoading ? loading_view() : SizedBox.shrink()),
        ],
      ),
    );
  }
}
