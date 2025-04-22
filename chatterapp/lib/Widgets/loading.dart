import 'package:chatterapp/constants/colorConstants.dart';
import 'package:flutter/material.dart';

class loading_view extends StatelessWidget {
  const loading_view({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Center(
          child: CircularProgressIndicator(
        color: ColorConstants.themeColor,
      )),
      color: Colors.white,
    );
  }
}
