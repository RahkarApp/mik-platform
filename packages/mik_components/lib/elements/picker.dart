// ignore_for_file: unnecessary_null_comparison

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mik_consts/colors.dart';

class Picker {
  static onePic({
    bool? cropper,
    double? maxWidth,
    double? maxHeight,
    required ImageSource source,
  }) async {
    var pick = await ImagePicker().pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: maxWidth ?? 1080,
      maxHeight: maxHeight ?? 1080,
    );
    if (pick != null) {
      if (cropper ?? false) {
        return await crop(picked: pick);
      } else {
        return pick.path;
      }
    }
    return;
  }

  static multiPic({bool? cropper, double? maxWidth, double? maxHeight}) async {
    var pick = await ImagePicker().pickMultiImage(
      maxWidth: maxWidth ?? 1080,
      maxHeight: maxHeight ?? 1080,
    );
    if (pick != null) {
      if (pick.length == 1) {
        return [await crop(picked: pick[0])];
      }
      List pl = [];
      for (var e in pick) {
        pl.add(e.path);
      }
      return pl;
    }
    return [];
  }

  static file({bool? multiple, List<String>? allowedExtensions}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions ?? <String>[], // ['xlsx', 'xls'],
      allowMultiple: multiple ?? false,
    );
    if (result != null) {
      if (multiple ?? false) {
        List pl = [];
        for (var e in result.files) {
          pl.add(e.path);
        }
      } else {
        result.files[0].path;
      }
    }
  }

  static crop({picked, pic}) async {
    if (picked == null && pic != null) {}
    var imageCroped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      maxWidth: 1024,
      maxHeight: 1024,
      // aspectRatio: ,
      // aspectRatioPresets: [
      //   CropAspectRatioPreset.square,
      //   CropAspectRatioPreset.ratio3x2,
      //   CropAspectRatioPreset.original,
      //   CropAspectRatioPreset.ratio4x3,
      //   CropAspectRatioPreset.ratio16x9
      // ],
      compressFormat: ImageCompressFormat.png,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'برش تصویر',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: 'برش تصویر'),
      ],
    );

    if (imageCroped != null) {
      return imageCroped.path;
    }
    return;
  }
}
