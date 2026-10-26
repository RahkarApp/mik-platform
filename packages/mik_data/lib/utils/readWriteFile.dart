// ignore_for_file: file_names, empty_catches

import 'dart:convert';
import 'dart:io';
import 'package:mik_variables/variable.dart';

import '../source/remote/api.dart';
import 'variable.dart';

// import '../core/common/variables/variable.dart';

enum RWType { product, profile, smartLinkBanner }

class RW {
  static save({required RWType type, required dir, required List filePath}) async {
    if (type == RWType.product) {
      var loc = Directory('${prImageDir!.path}/$dir');
      if (!await loc.exists()) {
        await Directory(loc.path).create();
      }
      for (var i = 0; i < filePath.length; i++) {
        await File(filePath[i]).copy('${loc.path}/${filePath[i].toString().split('/').last}');
      }
      var files = await productImageList(dir);
      Map<String, String> data = {"type": "product", "dir": dir.toString()};
      API.sendFile({'files': files, 'data': data});
    } else if (type == RWType.profile) {
      var loc = Directory(userImageDir!.path);
      if (filePath[0] != null) {
        await File(filePath[0]).copy('${loc.path}/profile.${filePath[0].split('.').last}');
        Map<String, String> data = {"type": "profile", "dir": profile.getAt(0)!.id.toString()};

        API.sendFile({
          'files': ['${loc.path}/profile.${filePath[0].split('.').last}'],
          'data': data
        });
      }
    } else if (type == RWType.smartLinkBanner) {}
  }

  static saveTemp({required RWType type, required dir, required List filePath}) async {
    if (type == RWType.product) {
      var loc = Directory('${prImageDir!.path}/temp$dir');
      if (!await loc.exists()) {
        await Directory(loc.path).create();
      }
      for (var i = 0; i < filePath.length; i++) {
        await File(filePath[i]).copy('${loc.path}/${filePath[i].toString().split('/').last}');
      }
    } else if (type == RWType.profile) {
    } else if (type == RWType.smartLinkBanner) {}
  }

  static deleteTemp({required dir}) async {
    var loc = Directory('${prImageDir!.path}/$dir');
    if (await loc.exists()) {
      await loc.delete(recursive: true);
    }
  }

  static delete({required RWType type, required dir}) async {
    if (type == RWType.product) {
      var loc = Directory('${prImageDir!.path}/$dir');
      if (await loc.exists()) {
        await loc.delete(recursive: true);
      }
    } else if (type == RWType.profile) {
    } else if (type == RWType.smartLinkBanner) {}
  }

  static productImgCopy(src, dir, {bool? deleteSrc}) async {
    try {
      var loc = Directory('${prImageDir!.path}/$src');
      await loc.rename('${prImageDir!.path}/$dir');
      var files = await productImageList(dir);
      Map<String, String> data = {"type": "product", "dir": dir.toString()};
      await API.sendFile({'files': files, 'data': data});
      if (deleteSrc ?? false) {
        await Directory('${prImageDir!.path}/$src').delete(recursive: true);
      }
    } catch (e) {}
  }

  static edit({required RWType type, required dir, required List newPath}) async {
    var loc = Directory('${prImageDir!.path}/$dir');
    if (!await loc.exists()) {
      await Directory(loc.path).create();
    }
    if (type == RWType.product) {
      var cp = await productImageList(dir);
      var currentPath = [];
      cp.forEach((element) {
        currentPath.add(element);
      });
      List newAdd = newPath;
      List delFromServer = [];
      for (var i = 0; i < currentPath.length; i++) {
        bool exist = false;
        for (var j = 0; j < newPath.length; j++) {
          if (newPath[j] == currentPath[i]) {
            exist = true;
            delFromServer.add(newPath[j]);
            newAdd.remove(newPath[j]);
            break;
          }
        }
        if (!exist) await Directory(currentPath[i]).delete(recursive: true);
      }
      var newAddToServer = [];
      for (var i = 0; i < newAdd.length; i++) {
        await File(newAdd[i]).copy('${loc.path}/${newAdd[i].toString().split('/').last}');
        newAddToServer.add('${loc.path}/${newAdd[i].toString().split('/').last}');
      }
      API.delFile(jsonEncode({"type": "product", "dir": dir.toString(), 'files': delFromServer}));

      if (newAddToServer.isNotEmpty) {
        Map<String, String> data = {"type": "product", "dir": dir.toString()};
        API.sendFile({'files': newAddToServer, 'data': data});
      }
    } else if (type == RWType.profile) {
      var loc = Directory(userImageDir!.path);
      try {
        await Directory('${loc.path}/profile.${newPath[0].split('.').last}').delete(recursive: true);
      } catch (e) {}
      await File(newPath[0]).copy('${loc.path}/profile.${newPath[0].split('.').last}');
      Map<String, String> data = {"type": "profile", "dir": profile.getAt(0)!.id.toString()};
      API.sendFile({
        'files': ['${loc.path}/profile.${newPath[0].split('.').last}'],
        'data': data
      });
    } else if (type == RWType.smartLinkBanner) {}
  }

  static editTemp({required RWType type, required dir, required List newPath}) async {
    var loc = Directory('${prImageDir!.path}/temp$dir');
    if (type == RWType.product) {
      var cp = await tempProductImageList(dir);
      var currentPath = [];
      cp.forEach((element) {
        currentPath.add(element.path);
      });
      List newAdd = newPath;
      for (var i = 0; i < currentPath.length; i++) {
        bool exist = false;
        for (var j = 0; j < newPath.length; j++) {
          if (newPath[j] == currentPath[i]) {
            exist = true;
            newAdd.remove(newPath[j]);
            break;
          }
        }
        if (!exist) await Directory(currentPath[i]).delete(recursive: true);
      }
      //var newAddToServer = [];
      for (var i = 0; i < newAdd.length; i++) {
        await File(newAdd[i]).copy('${loc.path}/${newAdd[i].toString().split('/').last.replaceAll("'", "")}');
        // newAddToServer
        //     .add(loc.path + '/${newAdd[i].toString().split('/').last}');
      }
    } else if (type == RWType.profile) {
    } else if (type == RWType.smartLinkBanner) {}
  }

  static productImageList(id) async {
    var loc = Directory('${prImageDir!.path}/$id');
    if (await loc.exists()) {
      var list = await loc.list(recursive: false, followLinks: true).toList();
      var ret = [];
      for (var element in list) {
        ret.add(element.toString().split("'")[1].toString());
      }
      return ret;
    } else {
      return [];
    }
  }

  static tempProductImageList(id) async {
    var loc = Directory('${prImageDir!.path}/temp$id');
    if (await loc.exists()) {
      return await loc.list(recursive: false, followLinks: true).toList();
    } else {
      return [];
    }
  }

  static findProfilePic() async {
    var loc = Directory(userImageDir!.path);
    if (await loc.exists()) {
      var list = await loc.list(recursive: false, followLinks: true).toList();
      for (var i = 0; i < list.length; i++) {
        if (list[i].toString().split('/').last.startsWith('profile')) {
          return list[i].toString().split("'")[1];
        }
      }
      return '';
    } else {
      return '';
    }
  }

  static read(path) {
    // var loc = Directory(path);
  }
}
