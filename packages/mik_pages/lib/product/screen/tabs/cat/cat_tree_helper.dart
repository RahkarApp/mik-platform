import 'package:mik_data/models/models.dart';

class CategoryNode {
  final CategoryDB category;
  final List<CategoryNode> children;

  CategoryNode({required this.category, required this.children});
}

List<CategoryNode> buildCategoryTree(List<CategoryDB> categories) {
  final Map<String, CategoryNode> nodes = {};
  final List<CategoryNode> rootNodes = [];

  for (final category in categories) {
    nodes[category.uid!] = CategoryNode(category: category, children: []);
  }

  for (final category in categories) {
    final node = nodes[category.uid!];
    if (category.parent == null || category.parent!.isEmpty) {
      rootNodes.add(node!);
    } else {
      final parentNode = nodes[category.parent!];
      if (parentNode != null) {
        parentNode.children.add(node!);
      }
    }
  }

  return rootNodes;
}
