import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SideMenuController extends GetxController {
  final selectedId = 1.obs;
  // final scrollOffset = 0.0.obs;
  //  ScrollController scrollController = ScrollController(keepScrollOffset: true);

  void select(int id,) {
    selectedId.value = id;
    // scrollOffset.value = controller.offset;
  }
}
