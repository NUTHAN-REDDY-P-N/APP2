import 'dart:io';

import 'package:chatterapp/constants/colorConstants.dart';
import 'package:chatterapp/constants/firestoreConstants.dart';
import 'package:chatterapp/constants/typeMessage.dart';
import 'package:chatterapp/models/message_chat.dart';
import 'package:chatterapp/pages/full_photo_page.dart';
import 'package:chatterapp/pages/login_page.dart';
import 'package:chatterapp/providers/authentication_provider.dart';
import 'package:chatterapp/providers/chat_provider.dart';
import 'package:chatterapp/providers/home_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class Chatscreen extends StatefulWidget {
  final ChatPageArguments arguments;
  const Chatscreen({super.key, required this.arguments});

  @override
  State<Chatscreen> createState() => _ChatscreenState();
}

class _ChatscreenState extends State<Chatscreen> {
  late final String _currentUserId;
  List _listMessages = [];
  int _limit = 20;
  int _limitIncrement = 20;
  String _groupChatId = "";
  File? _imageFile;
  bool _isLoading = false;
  bool _isShowSticker = false;
  String _imageUrl = "";

  final _chatInputController = TextEditingController();
  final _listScrollController = ScrollController();
  final _focusNode = FocusNode();

  late final _chatProvider = context.read<ChatProvider>();
  late final _authProvider = context.read<AuthProvider>();
  late final _homeProvider = context.read<HomeProvider>();

  @override
  void initState() {
    super.initState();
    _readLocal();
    _focusNode.addListener(_onFocusChange);
    _listScrollController.addListener(_scrollController);
  }

  @override
  void dispose() {
    _chatInputController.dispose();
    _listScrollController
      ..removeListener(_scrollController)
      ..dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      setState(() {
        _isShowSticker = false;
      });
    }
  }

  void _scrollController() {
    if (_listScrollController.hasClients) {
      if (_listScrollController.offset >=
              _listScrollController.position.maxScrollExtent &&
          !_listScrollController.position.outOfRange) {
        if (_limit <= _listMessages.length) {
          _limit += _limitIncrement;
        }
      }
    }
  }

  Widget _buildStickers() {
    return Container(
      child: Column(
        children: [
          Row(
            children: [
              _buildItemSticker(
                  'D:\\Desktop\\APP2\\chatterapp\\assets\\gif-1.gif'),
              _buildItemSticker("D:\Desktop\APP2\chatterapp\assets\gif-2.gif"),
              _buildItemSticker("D:\Desktop\APP2\chatterapp\assets\gif-3.gif"),
            ],
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          ),
          Row(
            children: [
              _buildItemSticker("D:\Desktop\APP2\chatterapp\assets\gif-4.gif"),
              _buildItemSticker("D:\Desktop\APP2\chatterapp\assets\gif-5.gif"),
              _buildItemSticker("D:\Desktop\APP2\chatterapp\assets\gif-6.gif"),
            ],
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          ),
          Row(
            children: [
              _buildItemSticker("D:\Desktop\APP2\chatterapp\assets\gif-7.gif"),
              _buildItemSticker("D:\Desktop\APP2\chatterapp\assets\gif-8.gif"),
              _buildItemSticker("D:\Desktop\APP2\chatterapp\assets\gif-9.gif"),
            ],
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          )
        ],
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      ),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: ColorConstants.greyColor2, width: 0.5)),
        color: Colors.white,
      ),
      padding: EdgeInsets.symmetric(vertical: 8),
    );
  }

  Widget _buildItemSticker(String stickerName) {
    return TextButton(
      onPressed: () => _onSendMessage(stickerName, TypeMessage.sticker),
      child: Image.asset(
        'images/$stickerName.gif',
        width: 50,
        height: 50,
        fit: BoxFit.cover,
      ),
    );
  }

  Future pickImage() async {
    final imagePicker = ImagePicker();
    final pickedXfile = await imagePicker
        .pickImage(source: ImageSource.gallery)
        .catchError((err) {
      Fluttertoast.showToast(msg: err.toString());
      return null;
    });
    if (pickedXfile != null) {
      final imagefile = File(pickedXfile.path);
      setState(() {
        _imageFile = imagefile;
        _isLoading = true;
      });
      return true;
    } else {
      return false;
    }
  }

  void _getSticker() {
    _focusNode.unfocus();
    setState(() {
      _isShowSticker = !_isShowSticker;
    });
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColorConstants.themeColor,
        title: Padding(
          padding: const EdgeInsets.fromLTRB(2.0, 0, 0, 0),
          child: Text(widget.arguments.peerNickname,
              style: TextStyle(
                  color: ColorConstants.primaryColor,
                  fontWeight: FontWeight.w600)),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
          child: PopScope(
              child: Stack(
        children: [
          Column(
            children: [
              _buildListMessage(),
              _isShowSticker ? _buildStickers() : SizedBox.shrink(),
              _buildInput(),
            ],
          )
        ],
      ))),
    );
  }

  Future<void> _uploadFile() async {
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final uploadTask = _chatProvider.uploadFile(_imageFile!, fileName);
    try {
      final snapshot = await uploadTask;
      _imageUrl = await snapshot.ref.getDownloadURL();
      setState(() {
        _isLoading = false;
        _onSendMessage(_imageUrl, TypeMessage.image);
      });
    } on FirebaseException catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(msg: e.message ?? e.toString());
    }
  }

  void _onSendMessage(String content, int type) {
    if (content.trim().isNotEmpty) {
      _chatInputController.clear();
      _chatProvider.sendMessage(
        content,
        type,
        _currentUserId,
        widget.arguments.peerId,
        _groupChatId,
      );
      if (_listScrollController.hasClients) {
        _listScrollController.animateTo(0,
            duration: Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } else {
      Fluttertoast.showToast(
          msg: 'Nothing to send', backgroundColor: ColorConstants.greyColor);
    }
  }

  Widget _buildInput() {
    return Container(
      child: Row(
        children: [
          Material(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 1),
              child: IconButton(
                icon: Icon(Icons.image),
                onPressed: () {
                  pickImage().then((isSuccess) {
                    if (isSuccess) {}
                    _uploadFile();
                  });
                },
                color: ColorConstants.primaryColor,
              ),
              color: Colors.white,
            ),
          ),
          Material(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 1),
              child: IconButton(
                onPressed: () {},
                icon: Icon(Icons.face),
                color: ColorConstants.primaryColor,
              ),
              color: Colors.white,
            ),
          ),
          Flexible(
              child: Container(
            child: TextField(
              controller: _chatInputController,
              decoration: InputDecoration.collapsed(
                hintText: 'Type your message...',
                hintStyle:
                    TextStyle(color: const Color.fromARGB(255, 150, 148, 148)),
              ),
              onSubmitted: (value) {
                _onSendMessage(_chatInputController.text, TypeMessage.text);
              },
              style:
                  TextStyle(color: ColorConstants.primaryColor, fontSize: 15),
            ),
          )),
          Material(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 8),
              child: IconButton(
                onPressed: () {
                  _onSendMessage(_chatInputController.text, TypeMessage.text);
                },
                icon: Icon(Icons.send),
                color: ColorConstants.primaryColor,
              ),
              color: Colors.white,
            ),
          )
        ],
      ),
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
          border: Border(
              top: BorderSide(color: ColorConstants.greyColor2, width: 0.5)),
          color: Colors.white),
    );
  }

  Widget _buildListMessage() {
    return Flexible(
      child: _groupChatId.isNotEmpty
          ? StreamBuilder<QuerySnapshot>(
              stream: _chatProvider.getChatStream(_groupChatId, _limit),
              builder: (_, snapshot) {
                if (snapshot.hasData) {
                  _listMessages = snapshot.data!.docs;
                  if (_listMessages.length > 0) {
                    return ListView.builder(
                      padding: EdgeInsets.all(10),
                      itemBuilder: (_, index) =>
                          _buildItemMessage(index, snapshot.data?.docs[index]),
                      itemCount: snapshot.data?.docs.length,
                      reverse: true,
                      controller: _listScrollController,
                    );
                  } else {
                    return Center(child: Text("No message here yet..."));
                  }
                } else {
                  return Center(
                    child: CircularProgressIndicator(
                      color: ColorConstants.themeColor,
                    ),
                  );
                }
              },
            )
          : Center(
              child: CircularProgressIndicator(
                color: ColorConstants.themeColor,
              ),
            ),
    );
  }

  Widget _buildItemMessage(int index, DocumentSnapshot? document) {
    if (document == null) return SizedBox.shrink();
    final messageChat = MessageChat.fromDocument(document);
    if (messageChat.idFrom == _currentUserId) {
      // Right (my message)
      return Row(
        children: [
          messageChat.type == TypeMessage.text
              // Text
              ? Container(
                  child: Text(
                    messageChat.content,
                    style: TextStyle(color: ColorConstants.greyColor2),
                  ),
                  padding: EdgeInsets.fromLTRB(15, 10, 15, 10),
                  width: 200,
                  decoration: BoxDecoration(
                      color: ColorConstants.primaryColor,
                      borderRadius: BorderRadius.circular(8)),
                  margin: EdgeInsets.only(
                      bottom: _isLastMessageRight(index) ? 20 : 10, right: 10),
                )
              : messageChat.type == TypeMessage.image
                  // Image
                  ? Container(
                      clipBehavior: Clip.hardEdge,
                      decoration:
                          BoxDecoration(borderRadius: BorderRadius.circular(8)),
                      child: GestureDetector(
                        child: Image.network(
                          messageChat.content,
                          loadingBuilder: (_, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              decoration: BoxDecoration(
                                color: ColorConstants.greyColor2,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8),
                                ),
                              ),
                              width: 200,
                              height: 200,
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
                          errorBuilder: (_, __, ___) {
                            return Image.asset(
                              'images/img_not_available.jpeg',
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                            );
                          },
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => imageView(
                                url: messageChat.content,
                              ),
                            ),
                          );
                        },
                      ),
                      margin: EdgeInsets.only(
                          bottom: _isLastMessageRight(index) ? 20 : 10,
                          right: 10),
                    )
                  // Sticker
                  : Container(
                      child: Image.asset(
                        'images/${messageChat.content}.gif',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                      margin: EdgeInsets.only(
                          bottom: _isLastMessageRight(index) ? 20 : 10,
                          right: 10),
                    ),
        ],
        mainAxisAlignment: MainAxisAlignment.end,
      );
    } else {
      // Left (peer message)
      return Container(
        child: Column(
          children: [
            Row(
              children: [
                ClipOval(
                  child: _isLastMessageLeft(index)
                      ? Image.network(
                          widget.arguments.peerAvatar,
                          loadingBuilder: (_, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                color: ColorConstants.themeColor,
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) {
                            return Icon(
                              Icons.account_circle,
                              size: 35,
                              color: ColorConstants.greyColor,
                            );
                          },
                          width: 35,
                          height: 35,
                          fit: BoxFit.cover,
                        )
                      : Container(width: 35),
                ),
                messageChat.type == TypeMessage.text
                    ? Container(
                        child: Text(
                          messageChat.content,
                          style: TextStyle(color: ColorConstants.greyColor2),
                        ),
                        padding: EdgeInsets.fromLTRB(15, 10, 15, 10),
                        width: 200,
                        decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 34, 34, 34),
                            borderRadius: BorderRadius.circular(8)),
                        margin: EdgeInsets.only(left: 10),
                      )
                    : messageChat.type == TypeMessage.image
                        ? Container(
                            clipBehavior: Clip.hardEdge,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8)),
                            child: GestureDetector(
                              child: Image.network(
                                messageChat.content,
                                loadingBuilder: (_, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: ColorConstants.greyColor2,
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(8),
                                      ),
                                    ),
                                    width: 200,
                                    height: 200,
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
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'images/img_not_available.jpeg',
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.cover,
                                ),
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        imageView(url: messageChat.content),
                                  ),
                                );
                              },
                            ),
                            margin: EdgeInsets.only(left: 10),
                          )
                        : Container(
                            child: Image.asset(
                              'images/${messageChat.content}.gif',
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                            margin: EdgeInsets.only(
                                bottom: _isLastMessageRight(index) ? 20 : 10,
                                right: 10),
                          ),
              ],
            ),

            // Time
            _isLastMessageLeft(index)
                ? Container(
                    child: Text(
                      DateFormat('dd MMM kk:mm').format(
                          DateTime.fromMillisecondsSinceEpoch(
                              int.parse(messageChat.timestamp))),
                      style: TextStyle(
                          color: ColorConstants.greyColor,
                          fontSize: 12,
                          fontStyle: FontStyle.italic),
                    ),
                    margin: EdgeInsets.only(left: 50, top: 5, bottom: 5),
                  )
                : SizedBox.shrink()
          ],
          crossAxisAlignment: CrossAxisAlignment.start,
        ),
        margin: EdgeInsets.only(bottom: 10),
      );
    }
  }

  bool _isLastMessageLeft(int index) {
    if ((index > 0 &&
            _listMessages[index - 1].get(FirestoreConstants.idFrom) ==
                _currentUserId) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  bool _isLastMessageRight(int index) {
    if ((index > 0 &&
            _listMessages[index - 1].get(FirestoreConstants.idFrom) !=
                _currentUserId) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  void _onBackPress() {
    _chatProvider.updateDataFirestore(
      FirestoreConstants.pathUserCollection,
      _currentUserId,
      {FirestoreConstants.chattingWith: null},
    );
    Navigator.pop(context);
  }

  void _readLocal() {
    if (_authProvider.userFirebaseId?.isNotEmpty == true) {
      _currentUserId = _authProvider.userFirebaseId!;
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginPage()),
        (_) => false,
      );
    }
    String peerId = widget.arguments.peerId;
    if (_currentUserId.compareTo(peerId) > 0) {
      _groupChatId = '$_currentUserId-$peerId';
      _chatProvider.messageMetaData(_groupChatId, _currentUserId, peerId);
    } else {
      _groupChatId = '$peerId-$_currentUserId';
      _chatProvider.messageMetaData(_groupChatId, _currentUserId, peerId);
    }

    _chatProvider.updateDataFirestore(
      FirestoreConstants.pathUserCollection,
      _currentUserId,
      {FirestoreConstants.chattingWith: peerId},
    );
  }
}

class ChatPageArguments {
  final String peerId;
  final String peerAvatar;
  final String peerNickname;

  ChatPageArguments({
    required this.peerId,
    required this.peerAvatar,
    required this.peerNickname,
  });
}
