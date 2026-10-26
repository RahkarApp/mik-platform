// ignore_for_file: must_be_immutable, invalid_use_of_protected_member, prefer_typing_uninitialized_variables

import 'dart:developer';

import 'package:mik_components/base/alert.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_reorderable_grid_view/widgets/reorderable_builder.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:image_compression/image_compression.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mik_components/base/responsive.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_utils/public/PermissionHandler.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';
import 'package:image/image.dart' as img;
import 'package:mik_consts/colors.dart';

class ImageSelector extends GetView {
  final bool remote;
  var callback;
  RxList? list;
  String? name;
  RxList imgSelectName = <String>[].obs;
  RxList<Uint8List> imgSelectBytes = <Uint8List>[].obs;
  ImageSelector({
    super.key,
    this.remote = false,
    this.name,
    required this.callback,
    this.list,
    required this.imgSelectName,
    required this.imgSelectBytes,
  });
  RxList imgSelect = [].obs;

  final gkey = GlobalKey();
  final _gridViewKey = GlobalKey();
  @override
  Widget build(BuildContext context) {
    //  WidgetsBinding.instance.addPostFrameCallback((_) {
    imgSelect = [].obs;
    if (list != null) {
      imgSelect.value.addAll(list!);
    }
    // });
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: darkMode.isFalse ? Colors.white : Colors.grey.shade700,
      ),
      margin: const EdgeInsets.only(bottom: 10, right: 10, left: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 12, left: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name ?? 'تصاویر:', style: const TextStyle(fontSize: 16)),
                Flexible(
                  child: BTN(
                    name: 'از گالری',
                    icon: IconsaxPlusLinear.gallery_add,
                    borderOnly: true,
                    navigate: true,
                    color: darkMode.value
                        ? Colors.grey.shade300
                        : Colors.grey.shade700,
                    textColor: darkMode.value
                        ? Colors.grey.shade300
                        : Colors.grey.shade700,
                    onTap: () async {
                      await selectImg(ImageSource.gallery);
                      callback(
                        imgSelect.value,
                        imgSelectName.value,
                        imgSelectBytes.value,
                      );
                    },
                  ),
                ),
                Flexible(
                  child: Platform.isAndroid || Platform.isIOS
                      ? BTN(
                          name: 'از دوربین',
                          borderOnly: true,
                          navigate: true,
                          icon: IconsaxPlusLinear.camera,
                          color: darkMode.value
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                          textColor: darkMode.value
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                          onTap: () async {
                            await selectImg(ImageSource.camera);
                            callback(
                              imgSelect.value,
                              imgSelectName.value,
                              imgSelectBytes.value,
                            );
                          },
                        )
                      : Container(),
                ),
              ],
            ),
          ),
          Container(
            alignment: Alignment.center,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Obx(
                  () => imgSelect.isEmpty || imgSelect.isNotEmpty
                      ? ReorderableBuilder(
                          onReorder:
                              (ReorderedListFunction reorderedListFunction) {
                                imgSelect.value = reorderedListFunction(
                                  imgSelect.value,
                                );
                                imgSelectName.value = reorderedListFunction(
                                  imgSelectName.value,
                                );

                                callback(
                                  imgSelect.value,
                                  imgSelectName.value,
                                  imgSelectBytes.value,
                                );
                              },
                          builder: (List<Widget> children) {
                            return Wrap(
                              key: _gridViewKey,
                              alignment: WrapAlignment.start,
                              runAlignment: WrapAlignment.start,
                              crossAxisAlignment: WrapCrossAlignment.start,
                              spacing: 10,
                              runSpacing: 10,
                              children: children,
                            );
                          },
                          children: [
                            for (int i = 0; i < imgSelect.length; i++)
                              showItem(imgSelect[i], i, context),
                          ],
                        )
                      : Container(),
                ),
                const Text(
                  'برای نمایش بهتر عکسها را مربع انتخاب کنید.',
                  style: TextStyle(color: Colors.grey),
                ),
                Obx(
                  () => imgSelect.isNotEmpty && imgSelect.value.length > 1
                      ? const Text(
                          'برای جابجایی تصاویر روی آنها نگه‌دارید.',
                          style: TextStyle(color: Colors.grey),
                        )
                      : Container(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  showItem(img, i, context) {
    RxBool edit = false.obs;
    Widget imageWidget;

    if (remote) {
      imageWidget = i < imgSelectBytes.length
          ? Image.memory(imgSelectBytes[i], fit: BoxFit.cover)
          : const SizedBox.shrink();
    } else if (kIsWeb) {
      print('img is ${img}');
      if (img.startsWith('http') || img.startsWith('https')) {
        // اگر تصویر از URL باشد
        imageWidget = Image.network(
          img,
          headers: {
            "Content-Type": "application/json",
            'auth-token': jwt.getAt(mikyarProfileIndex)!.token.toString(),
          },
          errorBuilder: (context, error, stackTrace) {
            return SizedBox(
              height: Get.width / 3.7,
              width: Get.width / 3.7,
              child: const Icon(
                IconsaxPlusLinear.box,
                size: 40,
                color: Colors.grey,
              ),
            );
          },
        );
      } else if (imgSelectBytes.isNotEmpty) {
        print('image widget byte');
        // اگر کاربر خودش تصویری انتخاب کرده باشد
        imageWidget = Image.memory(imgSelectBytes[i]);
      } else {
        // تصویر نامعتبر
        imageWidget = SizedBox(
          height: Get.width / 3.7,
          width: Get.width / 3.7,
          child: const Icon(
            IconsaxPlusLinear.box,
            size: 40,
            color: Colors.grey,
          ),
        );
      }
    } else {
      if (!kIsWeb && File(img).existsSync()) {
        // تصویر لوکال در ویندوز یا موبایل
        imageWidget = Image.file(File(img));
      } else {
        // اگر تصویر نامعتبر بود، عکس پیش‌فرض نشان بده
        imageWidget = SizedBox(
          height: Get.width / 3.7,
          width: Get.width / 3.7,
          child: const Icon(
            IconsaxPlusLinear.box,
            size: 40,
            color: Colors.grey,
          ),
        );
      }
    }

    return InkWell(
      key: Key('$i'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => edit.toggle(),
      child: SizedBox(
        height: Responsive.isMobile(context) ? Get.width / 3.7 : 100,
        width: Responsive.isMobile(context) ? Get.width / 3.7 : 100,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Container(alignment: Alignment.center, child: imageWidget),
              Container(
                alignment: Alignment.topLeft,
                child: Container(
                  // maxRadius: 12,
                  // backgroundColor: purple,
                  height: 20,
                  constraints: const BoxConstraints(minWidth: 20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  // padding: EdgeInsets.all(1),
                  alignment: Alignment.center,
                  child: Text(
                    imgSelect.indexOf(img) == 0
                        ? 'اصلی'
                        : (imgSelect.indexOf(img) + 1).toString(),
                    style: const TextStyle(color: Colors.white, height: 1),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Obx(
                () => edit.isTrue
                    ? Container(
                        color: Colors.black54,
                        height: Get.width / 3.7,
                        width: Get.width / 3.7,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (!remote && !Platform.isWindows && !kIsWeb)
                              InkWell(
                                onTap: () async {
                                  edit.value = false;
                                  await editImage(img);
                                  callback(
                                    imgSelect.value,
                                    imgSelectName.value,
                                    imgSelectBytes.value,
                                  );
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    border: Border.all(color: Colors.white),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        IconsaxPlusLinear.crop,
                                        color: Colors.white,
                                      ),
                                      Text(
                                        'ویرایش',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 15),
                            InkWell(
                              onTap: () async {
                                edit.value = false;
                                await deleteImg(img, i);
                                callback(
                                  imgSelect.value,
                                  imgSelectName.value,
                                  imgSelectBytes.value,
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  border: Border.all(color: Colors.red),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      IconsaxPlusLinear.trash_square,
                                      color: Colors.red,
                                    ),
                                    Text(
                                      'حذف',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  deleteImg(img, i) {
    imgSelect.removeAt(i);
    if (remote) {
      imgSelectName.removeAt(i);
      imgSelectBytes.removeAt(i);
    }
  }

  editImage(img) async {
    var imageCroped = await imageCroper(img);
    if (imageCroped != null) {
      int index = imgSelect.indexOf(img);
      imgSelect.replaceRange(index, index + 1, [imageCroped.path]);
    }
  }

  imageCroper(img) async {
    var imageCroped = await ImageCropper().cropImage(
      sourcePath: img,
      maxWidth: 1024,
      maxHeight: 1024,
      //  aspectRatio: CropAspectRatio
      // ,      // aspectRatioPresets: [
      //   CropAspectRatioPreset.square,
      //   CropAspectRatioPreset.ratio3x2,
      //   CropAspectRatioPreset.original,
      //   CropAspectRatioPreset.ratio4x3,
      //   CropAspectRatioPreset.ratio16x9
      // ],
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'برش تصویر',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: 'برش تصویر',
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
      ],
      compressFormat: ImageCompressFormat.png,
    );
    return imageCroped;
  }

  String sanitizeFileName(String fileName) {
    // جایگزینی فاصله با _ یا حذف فاصله‌ها
    return fileName.replaceAll(' ', '_');
  }

  OutputType _getFormatWindows(String path) {
    switch (path.split('.').last) {
      case 'jpg':
      case 'jpeg':
        return OutputType.jpg;
      case 'png':
        return OutputType.png;
      default:
        return OutputType.jpg;
    }
  }

  CompressFormat _getFormat(String path) {
    switch (path.split('.').last) {
      case 'jpg':
      case 'jpeg':
        return CompressFormat.jpeg;
      case 'png':
        return CompressFormat.png;
      case 'heic':
        return CompressFormat.heic;
      case 'webp':
        return CompressFormat.webp;
      default:
        return CompressFormat.jpeg;
    }
  }

  Future<Map<String, dynamic>?> compressImage({
    String? path,
    Uint8List? bytes,
    int maxSizeKB = 200,
    String? outputPath,
  }) async {
    // بررسی حجم اولیه
    int fileSizeKB;
    if (path != null) {
      File file = File(path);
      fileSizeKB = file.lengthSync() ~/ 1024;
    } else if (bytes != null) {
      fileSizeKB = bytes.length ~/ 1024;
    } else {
      return null;
    }

    // if (fileSizeKB <= maxSizeKB) {
    //   return path != null ? File(path) : null; // برای وب، بعداً فایل می‌سازیم
    // }

    // تنظیم کیفیت اولیه
    int quality = 85;
    Uint8List? compressedBytes;

    if (path != null) {
      final tempDir = await getTemporaryDirectory();

      if (Platform.isWindows && !kIsWeb) {
        String newPath = '${tempDir.path}\\${outputPath}';

        final original = File(path).readAsBytesSync();
        final image = img.decodeImage(original);

        final jpg = img.encodeJpg(image!, quality: 80);

        File(newPath).writeAsBytesSync(jpg);
        Configuration config = Configuration(
          outputType: _getFormatWindows(path),
          jpgQuality: 10,
          pngCompression: PngCompression.defaultCompression,
        );
        var input = ImageFile(filePath: newPath, rawBytes: bytes!);

        final output = compress(
          ImageFileConfiguration(input: input, config: config),
        );

        return {'file': newPath, 'bytes': output.rawBytes, 'name': outputPath};
      } else {
        var compressedFile = await FlutterImageCompress.compressAndGetFile(
          path,
          outputPath == null
              ? tempDir.path + '_compressed.jpg'
              : '${tempDir.path}/${outputPath}',
          quality: quality,
          format: _getFormat(path),
          minWidth: 1080,
          minHeight: 1080,
        );

        if (compressedFile == null) return null;

        File newFile = File(compressedFile.path);
        fileSizeKB = newFile.lengthSync() ~/ 1024;

        // کاهش کیفیت تا رسیدن به حجم دلخواه
        while (fileSizeKB > maxSizeKB && quality > 10) {
          quality -= 10;
          compressedFile = await FlutterImageCompress.compressAndGetFile(
            path,
            outputPath == null
                ? tempDir.path + '_compressed.jpg'
                : '${tempDir.path}/${outputPath}',
            quality: quality,
            format: _getFormat(path),
            minWidth: 1080,
            minHeight: 1080,
          );
          if (compressedFile == null) return null;
          newFile = File(compressedFile.path);
          fileSizeKB = newFile.lengthSync() ~/ 1024;
        }

        return {
          'file': newFile.path,
          'bytes': newFile.readAsBytesSync(),
          'name': outputPath,
        };
      }
      // فشرده‌سازی برای فایل (موبایل/دسکتاپ)
    } else if (bytes != null) {
      // فشرده‌سازی برای وب (بایت)
      compressedBytes = await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
        minWidth: 1080,
        minHeight: 1080,
      );

      fileSizeKB = compressedBytes.length ~/ 1024;

      // کاهش کیفیت تا رسیدن به حجم دلخواه
      while (fileSizeKB > maxSizeKB && quality > 10) {
        quality -= 10;
        compressedBytes = await FlutterImageCompress.compressWithList(
          bytes,
          quality: quality,
          minWidth: 1080,
          minHeight: 1080,
        );
        fileSizeKB = compressedBytes.length ~/ 1024;
      }

      return {'file': '', 'bytes': compressedBytes, 'name': outputPath};
    }

    return null;
  }

  Future<void> selectImg(ImageSource source) async {
    if (remote) {
      try {
        Uint8List? bytes;
        if (source == ImageSource.camera &&
            !kIsWeb &&
            (Platform.isAndroid || Platform.isIOS)) {
          final picked = await ImagePicker().pickImage(
            source: source,
            maxWidth: 1600,
            maxHeight: 1600,
          );
          bytes = await picked?.readAsBytes();
        } else {
          final picked = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['jpg', 'jpeg', 'png'],
            withData: true,
            allowMultiple: false,
          );
          if (picked != null) {
            bytes = picked.files.single.bytes;
            if (bytes == null)
              throw StateError(
                'خواندن عکس انتخاب‌شده انجام نشد؛ دوباره تلاش کنید.',
              );
          }
        }
        if (bytes == null) return;
        if (bytes.length > 10 * 1024 * 1024) {
          throw StateError('حداکثر حجم عکس ۱۰ مگابایت است.');
        }
        final decoded = img.decodeImage(bytes);
        if (decoded == null) {
          throw StateError('فایل انتخاب‌شده عکس معتبر نیست.');
        }
        final oriented = img.bakeOrientation(decoded);
        final resized = oriented.width > 1600 || oriented.height > 1600
            ? img.copyResize(
                oriented,
                width: oriented.width >= oriented.height ? 1600 : null,
                height: oriented.height > oriented.width ? 1600 : null,
              )
            : oriented;
        final data = Uint8List.fromList(img.encodeJpg(resized, quality: 88));
        imgSelect.assignAll(['product.jpg']);
        imgSelectName.assignAll(<String>['product.jpg']);
        imgSelectBytes.assignAll([data]);
      } catch (failure) {
        Alert.error(
          failure is StateError
              ? failure.message.toString()
              : 'انتخاب عکس انجام نشد؛ دوباره تلاش کنید.',
        );
      }
      return;
    }
    var pick;
    if (source == ImageSource.camera) {
      await PermissionHandler.camera();

      pick = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1080,
        maxHeight: 1080,
      );

      if (pick != null) {
        var imageCroped = await imageCroper(pick.path);
        if (imageCroped != null) {
          // فشرده‌سازی تصویر
          var compressedImage = await compressImage(
            path: imageCroped.path,
            maxSizeKB: 200,
          );
          if (compressedImage != null) {
            imgSelect.add(sanitizeFileName(compressedImage['file']));
          }
        }
      }
    } else {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        lockParentWindow: true,
        withData: true, // برای وب، بایت‌ها را می‌خواند
      );

      if (result != null) {
        pick = result.files;
      }

      if (pick != null) {
        if (pick.length == 1 &&
            (Platform.isAndroid || Platform.isIOS) &&
            !kIsWeb) {
          var imageCroped = await imageCroper(pick[0].path);
          if (imageCroped != null) {
            String fileName =
                '${DateTime.now().millisecondsSinceEpoch}_compressed.${imageCroped.path.split('.').last}';
            // فشرده‌سازی تصویر
            var compressedImage = await compressImage(
              path: imageCroped.path,
              maxSizeKB: 200,
              outputPath: fileName,
            );
            if (compressedImage != null) {
              imgSelect.add(sanitizeFileName(compressedImage['file']));
              log('path image is = ${compressedImage['file']}');

              imgSelectName.add(sanitizeFileName(fileName));
              imgSelectBytes.add(compressedImage['bytes']);
            }
          }
        } else {
          for (var element in pick) {
            Map<String, dynamic>? compressedImage;
            String fileName =
                '${DateTime.now().millisecondsSinceEpoch}_compressed.${element.name.split('.').last}';
            if (!kIsWeb && !Platform.isWindows && element.path != null) {
              // فشرده‌سازی برای موبایل
              compressedImage = await compressImage(
                path: element.path,
                maxSizeKB: 200,
                outputPath: fileName,
              );
              if (compressedImage != null) {
                imgSelect.add(sanitizeFileName(compressedImage['file']));
              }
              imgSelectName.add(fileName);
              imgSelectBytes.add(element.bytes);
            } else if (Platform.isWindows && !kIsWeb && element.path != null) {
              compressedImage = await compressImage(
                path: element.path,
                maxSizeKB: 200,
                bytes: element.bytes,
                outputPath: fileName,
              );
              if (compressedImage != null) {
                imgSelect.add(sanitizeFileName(compressedImage['file']));
              }
              imgSelectName.add(compressedImage!['name']);
              imgSelectBytes.add(compressedImage['bytes']);
            } else if (kIsWeb && element.bytes != null) {
              // فشرده‌سازی برای وب
              compressedImage = await compressImage(
                bytes: element.bytes,
                maxSizeKB: 200,
                outputPath: fileName,
              );
              if (compressedImage != null) {
                imgSelect.add(sanitizeFileName(compressedImage['file']));
                imgSelectName.add(sanitizeFileName(fileName));
                imgSelectBytes.add(compressedImage['bytes']);
              }
            } else {
              imgSelect.add('');
            }
            log('path image is = ${compressedImage!['file']}');
          }
        }
      }
    }
  }
}
