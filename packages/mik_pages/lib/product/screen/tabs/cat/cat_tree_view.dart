// ignore_for_file: deprecated_member_use

part of '../../screen.dart';

class CategoryTreeView extends StatefulWidget {
  final Function(String?) onCategorySelected;
  final String? selectedCategoryId;
  final ScrollController? scrollController;
  const CategoryTreeView({
    super.key,
    required this.onCategorySelected,
    this.selectedCategoryId,
    this.scrollController,
  });

  @override
  State<CategoryTreeView> createState() => _CategoryTreeViewState();
}

class _CategoryTreeViewController extends GetxController {
  late List<CategoryNode> _rootNodes;
  String? _selectedCategoryId;
  final _searchController = TextEditingController();
  List<CategoryNode> _filteredRootNodes = [];
}

class _CategoryTreeViewState extends State<CategoryTreeView> {
  late final _page = _CategoryTreeViewController();

  @override
  void initState() {
    super.initState();
    _page._selectedCategoryId = widget.selectedCategoryId;
    _page._rootNodes = buildCategoryTree(category.values.toList());
    _page._filteredRootNodes = _page._rootNodes;
    _page._searchController.addListener(_filterTree);
  }

  void _filterTree() {
    final query = _page._searchController.text.toLowerCase().toEnglishDigit();
    {
      if (query.isEmpty) {
        _page._filteredRootNodes = _page._rootNodes;
      } else {
        _page._filteredRootNodes = _filterNodes(_page._rootNodes, query);
      }
      _page.update();
    }
  }

  List<CategoryNode> _filterNodes(List<CategoryNode> nodes, String query) {
    final filteredNodes = <CategoryNode>[];
    for (final node in nodes) {
      final filteredChildren = _filterNodes(node.children, query);
      if (node.category.name!.toLowerCase().contains(query) ||
          filteredChildren.isNotEmpty) {
        final newNode = CategoryNode(
          category: node.category,
          children: filteredChildren,
        );
        filteredNodes.add(newNode);
      }
    }
    return filteredNodes;
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_CategoryTreeViewController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: MySearchBar(
                controller: _page._searchController,
                type: SearchBarType.category,
                callback: (value) {
                  _page._searchController.text = value;
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: widget.scrollController,
                shrinkWrap: true,
                itemCount: _page._filteredRootNodes.length,
                itemBuilder: (context, index) {
                  return _buildNode(_page._filteredRootNodes[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNode(CategoryNode node) {
    final isLevel6 = node.category.id.toString().length == 16;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey("${node.category.uid}${_page._searchController.text}"),
        title: Text(node.category.name!),
        initiallyExpanded: _isExpanded(node),
        children: [
          for (final child in node.children)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: _buildNode(child),
            ),
          ListTile(
            title: Text(
              isLevel6
                  ? '${node.category.name} (سطح آخر)'
                  : 'انتخاب ${node.category.name}',
              style: TextStyle(color: isLevel6 ? Colors.grey : null),
            ),
            onTap: isLevel6
                ? null
                : () {
                    {
                      _page._selectedCategoryId = node.category.uid;
                      _page.update();
                    }
                    widget.onCategorySelected(_page._selectedCategoryId);
                  },
            leading: Radio<String?>(
              value: node.category.uid,
              groupValue: _page._selectedCategoryId,
              onChanged: isLevel6
                  ? null
                  : (String? value) {
                      {
                        _page._selectedCategoryId = value;
                        _page.update();
                      }
                      widget.onCategorySelected(value);
                    },
            ),
          ),
        ],
      ),
    );
  }

  bool _isExpanded(CategoryNode node) {
    // If there's a search query, all nodes in the filtered list should be expanded.
    if (_page._searchController.text.isNotEmpty) {
      return true;
    }

    // Otherwise, expand based on the selected category.
    if (_page._selectedCategoryId == null) {
      return false;
    }
    if (node.category.uid == _page._selectedCategoryId) {
      return true;
    }
    for (final child in node.children) {
      if (_isExpanded(child)) {
        return true;
      }
    }
    return false;
  }
}
