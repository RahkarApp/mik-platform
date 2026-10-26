import 'dart:convert';
import 'package:http/http.dart' as http;

String _baseUrl = "cms.rahkarapp.ir";
List<String> sectionID = ['69882bc85e32fd255a3af4b0', '698831615e32fd255a3af8e1']; //help

class HelpCenterAPI {
  static getCat() async {
    Map<String, dynamic> section = {};
    for (var i = 0; i < sectionID.length; i++) {
      section['where[or][$i][section][equals]'] = sectionID[i];
    }
    Map<String, dynamic> query = {...section, 'limit': '100', 'select[title]': 'true', 'select[id]': 'true'};
    return await getAPI(path: "/api/categories", query: query);
  }

  static getHelpList({String? page, String? cat, String? search}) async {
    Map<String, dynamic> section = {};
    for (var i = 0; i < sectionID.length; i++) {
      section['where[or][$i][section][equals]'] = sectionID[i];
    }
    Map<String, dynamic> query = {
      ...section,
      // 'where[section][equals]': sectionID,
      if (cat != null && search == null) 'where[categories][equals]': cat,
      if (search != null) 'where[or][0][title][contains]': search,
      if (search != null) 'where[or][1][meta.description][contains]': search,
      if (search != null) 'where[or][2][content.root.children.children.text][contains]': search,
      'depth': '0',
      'page': page ?? '1',
      'limit': '10',
      'select[title]': 'true',
      'select[slug]': 'true',
      'select[excerpt]': 'true',
      'select[createdAt]': 'true',
      'select[categories]': 'true',
      'select[id]': 'true',
      'select[heroImage]': 'true',
      'select[meta]': 'true',
    };
    return await getAPI(path: "/api/posts", query: query);
  }

  static getHelp(postID) async {
    var query = {'depth': '0', 'where[id][equals]': postID};
    return await getAPI(path: "/api/posts/", query: query);
  }

  static getMedia(mediaId) async {
    var d = await getAPI(path: "/api/media/$mediaId");
    if (!d['hasError']) {
      return 'https://$_baseUrl${d['data']['url']}';
    }
    return '';
  }

  //====================================
  static getAPI({path, query}) async {
    try {
      var res = await http.get(Uri.https(_baseUrl, '$path', query ?? {}), headers: {"Content-Type": "application/json"}).timeout(const Duration(milliseconds: 6000));
      if (res.statusCode == 200) {
        if (res.body.isEmpty) {
          return {"message": "آموزش وجود ندارد!", "hasError": true};
        } else {
          return {"message": "success", "hasError": false, "data": jsonDecode(res.body)};
        }
      } else {
        return {"message": "خطا در دریافت اطلاعات!", "hasError": true};
      }
    } catch (e) {
      return {"message": "خطا در دریافت اطلاعات!", "hasError": true};
    }
  }
}
