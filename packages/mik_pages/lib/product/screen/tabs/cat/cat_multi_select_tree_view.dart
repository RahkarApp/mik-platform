import 'package:get/get.dart';
import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/source/remote/models/pim_category.dart';
import 'package:mik_data/utils/variable.dart';

class CategoryMultiSelectTreeView extends StatefulWidget {
  final Function(List<String>?) onCategorySelected;
  final List<String>? selectedCategoryIds;
  final String type;
  final List<PimCategory>? categories;
  var scrollController;

  CategoryMultiSelectTreeView({
    super.key,
    required this.onCategorySelected,
    this.scrollController,
    this.selectedCategoryIds,
    required this.type,
    this.categories,
  });

  @override
  State<CategoryMultiSelectTreeView> createState() =>
      _CategoryMultiSelectTreeViewState();
}

final _searchController = TextEditingController();

class _CategoryMultiSelectTreeViewController extends GetxController {
  late List<String> _selectedCategoryIds;
  late TreeViewController _treeController;
  TreeNode<dynamic>? catdataFiltered;
  final fs = FocusNode();
}

class _CategoryMultiSelectTreeViewState
    extends State<CategoryMultiSelectTreeView> {
  late final _page = _CategoryMultiSelectTreeViewController();

  //TreeNode<dynamic>? catdata;

  @override
  void initState() {
    super.initState();
    _searchController.clear();
    _page._selectedCategoryIds = List<String>.from(
      widget.selectedCategoryIds ?? [],
    );
    // catdata = buildTree(category.values.toList());
    _page.catdataFiltered = buildTree();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_CategoryMultiSelectTreeViewController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        return Column(
          children: [
            MySearchBar(
              controller: _searchController,
              type: SearchBarType.text,
              focusNode: _page.fs,
              callback: (value) {
                final text = value.toString();
                if (text.length > 1) {
                  // گام ۱: قرار دادن یک درخت موقت تا درخت قبلی کامل dispose شود
                  {
                    _page.catdataFiltered = TreeNode.root();
                    _page.update();
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final filtered = filterTree(buildTree(), text);
                    // گام ۲: جایگزینی درخت فیلترشده در فریم بعدی
                    {
                      _page.catdataFiltered = filtered;
                      _page.update();
                    }
                    // بعد از رندر درخت جدید والد‌ها را باز کن
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      expandParentsOfFilter(_page.catdataFiltered!, text);
                    });
                  });
                } else {
                  // وقتی پاک شد نیز به شکل مشابه عمل کن تا listener های قدیمی قطع شوند
                  {
                    _page.catdataFiltered = TreeNode.root();
                    _page.update();
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final full = buildTree();
                    {
                      _page.catdataFiltered = full;
                      _page.update();
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      expandParentsOfSelected(_page.catdataFiltered!);
                    });
                  });
                }
              },
            ),
            Expanded(
              // height: Get.height * 0.8,
              child: TreeView.simple(
                // scrollController: widget.scrollController as AutoScrollController,
                tree: _page.catdataFiltered!,
                showRootNode: false, // چون ریشه واقعی نداره
                expansionIndicatorBuilder: (context, node) =>
                    ChevronIndicator.rightDown(
                      tree: node,
                      color: AppColors.primary,
                      padding: const EdgeInsets.only(left: 8, top: 27),
                    ),
                indentation: const Indentation(style: IndentStyle.roundJoint),
                onItemTap: (node) {
                  final category = node.data!;
                  if (node.children.isEmpty) {
                    {
                      if (!_page._selectedCategoryIds.contains(node.key)) {
                        _page._selectedCategoryIds.add(node.key);
                      } else {
                        _page._selectedCategoryIds.remove(node.key);
                      }
                      _page.update();
                    }
                    widget.onCategorySelected(_page._selectedCategoryIds);
                  }
                },
                onTreeReady: (controller) {
                  _page._treeController = controller;
                  // ⏱️ بعد از اولین فریم
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    expandParentsOfSelected(_page.catdataFiltered!);
                  });
                },
                builder: (context, node) {
                  final category = node.data!;
                  bool selected = _page._selectedCategoryIds.contains(node.key);
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: ListTile(
                      title: Text(
                        category.name,
                        style: TextStyle(
                          color: selected
                              ? darkMode.value
                                    ? Colors.white
                                    : null
                              : null,
                          fontWeight: selected ? FontWeight.bold : null,
                        ),
                      ),
                      subtitle: Text(
                        'شناسه: ${node.key}',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 10,
                          height: 2,
                        ),
                      ),
                      selected: selected,
                      leading: Checkbox(
                        value: selected,
                        onChanged: (bool? value) {
                          {
                            if (value == true) {
                              _page._selectedCategoryIds.add(node.key);
                            } else {
                              _page._selectedCategoryIds.remove(node.key);
                            }
                            _page.update();
                          }
                          widget.onCategorySelected(_page._selectedCategoryIds);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  TreeNode buildTree() {
    final root = TreeNode.root();
    final Map<String, TreeNode> nodeMap = {};
    // Remote categories retain their server IDs; they are not Hive records.
    if (widget.categories case final remote?) {
      for (final item in remote) {
        nodeMap[item.id] = TreeNode(key: item.id, data: item);
      }
      for (final item in remote) {
        final parent = nodeMap[item.parentId];
        (parent ?? root).add(nodeMap[item.id]!);
      }
      return root;
    }
    final items = category.values.toList();
    sortCategories(items);
    // مرحله ۱: ساخت نودها
    for (final item in items) {
      nodeMap[item.uid!] = TreeNode(key: item.uid, data: item);
    }

    // مرحله ۲: اتصال به والد
    for (final item in items) {
      final node = nodeMap[item.uid]!;

      if (item.parent == null || item.parent!.isEmpty) {
        root.add(node);
      } else {
        final parentNode = nodeMap[item.parent];
        (parentNode ?? root).add(node);
      }
    }

    // 🔥 مرحله ۳: اگر فقط یک مادر داریم، حذفش کن
    if (root.children.length == 1) {
      final singleRoot = root.children.values.first;

      final newRoot = TreeNode.root();
      for (final child in singleRoot.children.values) {
        newRoot.add(child);
      }
      return newRoot;
    }
    // sortNode(root);

    return root;
  }

  void sortCategories(List<CategoryDB> items) {
    items.sort((a, b) {
      final aUid = int.tryParse(a.uid ?? '') ?? 0;
      final bUid = int.tryParse(b.uid ?? '') ?? 0;

      // اول parent، بعد خود uid
      final aParent = int.tryParse(a.parent ?? '') ?? 0;
      final bParent = int.tryParse(b.parent ?? '') ?? 0;

      if (aParent != bParent) {
        return aParent.compareTo(bParent);
      }
      return aUid.compareTo(bUid);
    });
  }

  List<TreeNode> findPathToRoot(TreeNode root, String uid) {
    final List<TreeNode> path = [];

    bool dfs(TreeNode node) {
      if (node.key == uid) {
        path.add(node);
        return true;
      }

      for (final child in node.children.values) {
        if (child is TreeNode && dfs(child)) {
          path.add(node);
          return true;
        }
      }
      return false;
    }

    dfs(root);
    return path;
  }

  List<List<TreeNode>> findPathsByName(TreeNode root, String name) {
    final List<List<TreeNode>> result = [];
    final lowerName = name.toLowerCase();

    void dfs(TreeNode node, List<TreeNode> path) {
      final nodeName = node.data?.name?.toLowerCase() ?? '';
      final currentPath = [...path, node];

      if (nodeName.contains(lowerName)) {
        // مسیر کامل از root تا این node را اضافه کن
        result.add(currentPath);
      }

      for (final child in node.children.values) {
        if (child is TreeNode) {
          dfs(child, currentPath);
        }
      }
    }

    dfs(root, []);
    return result;
  }

  void expandParentsOfSelected(TreeNode root) {
    if (!mounted) return;
    //if (_treeController == null) return;
    for (final uid in _page._selectedCategoryIds) {
      final path = findPathToRoot(root, uid);
      for (final node in path) {
        try {
          if (!mounted) return;
          _page._treeController.expandNode(node);
        } catch (_) {}
      }
    }
  }

  void expandParentsOfFilter(TreeNode root, name) {
    if (!mounted) return;
    try {
      final paths = findPathsByName(root, name);
      for (final path in paths) {
        for (final element in path) {
          if (!mounted) return;
          try {
            _page._treeController.expandNode(element);
          } catch (_) {}
        }
      }
    } catch (e) {
      // ممکنه controller هنوز نپرورده باشه — بی‌صدا عبور می‌کنیم
    }
  }

  TreeNode filterTree(TreeNode root, String query) {
    final lowerQuery = query.toLowerCase();

    TreeNode? filter(TreeNode node) {
      final nodeName = node.data?.name?.toLowerCase() ?? '';

      // filter بچه‌ها
      final filteredChildren = node.children.values
          .map((child) => filter(child as TreeNode))
          .whereType<TreeNode>()
          .toList();

      // اگر node خودش match است یا بچه‌ای match دارد
      if (nodeName.contains(lowerQuery) || filteredChildren.isNotEmpty) {
        final newNode = node.isRoot
            ? TreeNode.root()
            : TreeNode(
                key: node.key,
                data: node.data,
              ); // expanded را با controller باز می‌کنیم

        // فقط بچه‌های match شده را اضافه کن
        for (final child in filteredChildren) {
          newNode.add(child);
        }

        return newNode;
      }

      return null;
    }

    return filter(root) ?? TreeNode.root();
  }
}
