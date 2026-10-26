// ignore_for_file: deprecated_member_use

import 'dart:developer';

import 'package:mik_data/utils/variable.dart';
import 'package:uuid/uuid.dart';



class ID {
  static int endId(data) {
    List ww = data.values.toList();
    if (ww.isEmpty) return 0;
    try {
      ww.sort((a, b) {
        return a.id.compareTo(b.id);
      });
      return ww.last!.id ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static int newId(data) {
    List ww = data.values.toList();
    if (ww.isEmpty) return 1;
    ww.sort((a, b) {
      return (a.id ?? 1).compareTo((b.id ?? 1));
    });
    return (ww.last!.id ?? 0) + 1;
  }

  static String newCatId(List<dynamic> allCats, String parentId) {
    // Sub-category
    final parentIdStr = parentId.toString();
    final parentLength = parentIdStr.length;

    final int childLength;
    final int suffixLength;

    if (parentLength == 2) {
      childLength = 4;
      suffixLength = 2;
    } else if ([4, 7, 10, 13].contains(parentLength)) {
      childLength = parentLength + 3;
      suffixLength = 3;
    } else if (parentLength == 16) {
      throw Exception('Cannot add sub-category to a level 6 category.');
    } else {
      throw Exception('Invalid parent category ID structure.');
    }

    List childrenIds = allCats.map((cat) => cat['id']).toList().where((id) => id != null && id.toString().length == childLength && id.toString().startsWith(parentIdStr)).toList();
    final currentIds = category.values.map((cat) => cat.uid).toList().toList().where((id) => id != null && id.toString().length == childLength && id.toString().startsWith(parentIdStr)).toList();
    List allIds = childrenIds;
    allIds.addAll(currentIds);
    childrenIds = allIds.toSet().toList();
    log('childrenIds: $childrenIds');

    if (childrenIds.isEmpty) {
      if (parentLength == 2) {
        return '${parentIdStr}10';
      } else {
        return '${parentIdStr}001';
      }
    }

    childrenIds.sort();
    final lastChildId = childrenIds.last!;
    final lastSuffix = int.parse(lastChildId.toString().substring(parentLength));
    final newSuffix = lastSuffix + 1;

    final maxSuffix = int.parse('9' * suffixLength);
    if (newSuffix > maxSuffix) {
      final suffixSet = childrenIds.map((id) => int.parse(id.toString().substring(parentLength))).toSet();
      final startSuffix = (parentLength == 2) ? 10 : 1;
      for (int i = startSuffix; i <= maxSuffix; i++) {
        if (!suffixSet.contains(i)) {
          return '$parentIdStr${i.toString().padLeft(suffixLength, '0')}';
        }
      }
      throw Exception('No available sub-category ID.');
    }
    String id = '$parentIdStr${newSuffix.toString().padLeft(suffixLength, '0')}';
    // if(category.values.where((r)=>r.uid==id).toList().isNotEmpty){
    //   id =
    // }
    return id;
    //}
  }

  static String uidNew({id}) {
    var uuid = const Uuid();
    if (id != null) {
      return uuid.v5(Uuid.NAMESPACE_URL, (profile.getAt(0)!.id! + 0 + DateTime.now().millisecondsSinceEpoch + id).toString());
    }
    return uuid.v5(Uuid.NAMESPACE_URL, (profile.getAt(0)!.id! + 0 + DateTime.now().millisecondsSinceEpoch).toString());
  }
}
