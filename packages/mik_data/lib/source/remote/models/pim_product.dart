import 'pim_axis.dart';
import 'pim_attribute_value.dart';
import 'pim_media.dart';
import 'pim_record.dart';
import 'remote_json.dart';

class PimProduct extends PimRecord {
  @override
  final String id, name;
  final String slug, primaryCategoryId;
  final String? brandId, model, description, shortDescription;
  final int unitId;
  final List<String> categoryIds;
  final List<PimAxis> variantAxes;
  final List<PimAttributeValue> attributeValues;
  final List<PimMedia> media;
  PimProduct.fromJson(Object? value) : this._(RemoteJson(value));
  PimProduct._(super.json)
    : id = json.text('productId'),
      name = json.text('name'),
      slug = json.text('slug'),
      primaryCategoryId = json.text('primaryCategoryId'),
      categoryIds = json.strings('categoryIds'),
      unitId = json.number('unitId'),
      brandId = json.optionalText('brandId'),
      model = json.optionalText('model'),
      description = json.optionalText('description'),
      shortDescription = json.optionalText('shortDescription'),
      variantAxes = json.items('variantAxes', PimAxis.fromJson),
      attributeValues = json.items(
        'attributeValues',
        PimAttributeValue.fromJson,
      ),
      media = json.items('media', PimMedia.fromJson);
}
