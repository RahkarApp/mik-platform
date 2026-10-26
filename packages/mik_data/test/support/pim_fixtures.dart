import 'package:http/http.dart' as http;
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/source/remote/pim_store.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/pim.dart';

import 'onboarding_fixtures.dart';

const productId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const categoryId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const variantId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const priceId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const attributeId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
const optionId = 'ffffffff-ffff-4fff-8fff-ffffffffffff';

class MemoryPimStore implements PimCommandStore {
  final values = <String, PimCommand>{};
  @override
  Future<PimCommand?> read(String key) async => values[key];
  @override
  Future<void> write(String key, PimCommand command) async {
    values[key] = PimCommand.fromJson(command.toJson());
  }

  @override
  Future<void> clear(String key) async {
    values.remove(key);
  }
}

PimFX pimFixture(
  http.Client client, {
  String appId = 'mik',
  PimCommandStore? store,
}) {
  final auth = fixtureSession(client, appId: appId);
  return PimFX(
    context: BusinessContext.activate(
      auth,
      BusinessSession(
        identityId: identity,
        business: BusinessSummary(
          businessId: 12345678,
          name: 'فروشگاه نمونه',
          membershipId: membership,
          membershipType: appId == 'mik' ? 'OWNER' : 'PERSONNEL',
        ),
      ),
    ),
    store: store ?? MemoryPimStore(),
  );
}

Map<String, Object?> fixtureAuthorization(Iterable<String> permissions) => {
  'businessId': 12345678,
  'membershipId': membership,
  'personnelId': 'personnel-uuid',
  'scopeType': 'BUSINESS',
  'scopeId': '12345678',
  'allowed': true,
  'permissionCodes': permissions.toList(),
};
Map<String, dynamic> fixturePim(
  PimResource resource, {
  String creator = identity,
  String? id,
  String? name,
  String status = 'ACTIVE',
}) => {
  'businessId': 12345678,
  'revision': 3,
  'status': status,
  'createdBy': {
    'type': 'USER',
    'identityId': creator,
    'membershipId': membership,
  },
  ...switch (resource) {
    PimResource.products => {
      'productId': id ?? productId,
      'name': name ?? 'پیراهن',
      'slug': 'shirt',
      'categoryIds': [categoryId],
      'primaryCategoryId': categoryId,
      'unitId': 1,
      'brandId': null,
      'attributeValues': [],
      'variantAxes': [],
      'media': [],
    },
    PimResource.categories => {
      'categoryId': id ?? categoryId,
      'name': name ?? 'پوشاک',
      'parentId': null,
      'source': 'CATALOG',
      'templateCode': '09',
    },
    PimResource.attributes => {
      'attributeId': id ?? attributeId,
      'name': name ?? 'رنگ',
      'kind': 'COLOR',
      'dataType': 'SELECT',
      'usableForVariant': true,
      'values': [
        {
          'valueId': optionId,
          'name': 'قرمز',
          'colorHex': '#FF0000',
          'active': true,
        },
      ],
    },
    PimResource.brands => {
      'brandId': id ?? '11111111-1111-4111-8111-111111111119',
      'name': name ?? 'برند نمونه',
    },
    PimResource.variants => {
      'variantId': id ?? variantId,
      'productId': productId,
      'optionValues': [],
      'combinationKey': 'BASE',
      'barcodes': [],
      'sku': 'SHIRT-1',
    },
    PimResource.prices => {
      'productPriceId': id ?? priceId,
      'productId': productId,
      'name': name ?? 'فروش',
      'amount': 0,
      'currency': 'TOMAN',
      'isDefault': true,
      'validFrom': null,
      'validUntil': null,
    },
    PimResource.overrides => {
      'overrideId': id ?? '11111111-1111-4111-8111-111111111118',
      'productPriceId': priceId,
      'variantId': variantId,
      'amount': 0,
    },
  },
};
Map<String, Object?> fixturePimPage(
  PimResource resource, {
  List<Map<String, dynamic>>? items,
  String? next,
}) => {
  'businessId': 12345678,
  'items': items ?? [fixturePim(resource)],
  'nextCursor': next,
};
