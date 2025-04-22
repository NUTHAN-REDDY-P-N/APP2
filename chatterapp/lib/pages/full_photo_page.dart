import 'package:chatterapp/constants/appConstants.dart';
import 'package:chatterapp/constants/colorConstants.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class imageView extends StatelessWidget {
  const imageView({super.key, required this.url});
  final String url;

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
      ),
      body: Container(
        child: PhotoView(
          imageProvider: NetworkImage(url),
        ),
      ),
    );
  }
}
