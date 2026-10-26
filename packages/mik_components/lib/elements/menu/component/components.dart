import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/responsive.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';

// Widget desktopChile = Container();
Widget pages(String route, {dynamic argument}) {
  // platformSpecificFunction(route);
  switch (route) {
    // case RoutesName.INVOICES:
    //   return desktopChile;
    // case RoutesName.SALE:
    //   return FactorBody(
    //     factorType: FactorType.sale,
    //   );
    // case RoutesName.BUY:
    //   return FactorBody(
    //     factorType: FactorType.buy,
    //   );
    // case RoutesName.CHEQUE:
    //   return ChequeBody();
    // case RoutesName.COST:
    //   return CostBody();
    // case RoutesName.BILL:
    //   return BillBody();
    // case RoutesName.ORDER:
    //   return OrderBody();
    // case RoutesName.PRODUCTS:
    //   return ProductBody();
    // case RoutesName.CUSTOMERS:
    //   return PersonBody(
    //     personType: PersonType.customers,
    //   );
    // case RoutesName.SUPPLIERS:
    //   return PersonBody(
    //     personType: PersonType.suppliers,
    //   );
    // case RoutesName.FACTORDAY:
    //   return FactorDayBody();
    //   case RoutesName.DELPRODUCT:
    //   return DelProductBody();
    //   case RoutesName.SELECTFEATURES:
    //   return SelectFeaturesBody();
    //   case RoutesName.MYMAP:
    //   return MyMapBody(myMapModel: argument,);

    default:
      return Container();
  }
}

class ItemList extends StatelessWidget {
  final dynamic icon;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const ItemList({
    super.key,
    required this.icon,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                icon is IconData
                    ? Icon(
                        icon,
                        size: isDesktop ? 22 : 18,
                        color: selected
                            ? AppColors.primary
                            : theme.iconTheme.color,
                      )
                    : icon,
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: isDesktop ? 15 : 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? AppColors.primary
                          : theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: selected ? 1 : 0.3,
                  child: Icon(
                    IconsaxPlusLinear.arrow_left_1,
                    size: 16,
                    color: selected ? AppColors.primary : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MenuItem {
  final int id;
  final dynamic icon;
  final String text;
  final String? route;
  final dynamic arguments;
  bool isPermission;

  MenuItem(
    this.id,
    this.icon,
    this.text,
    this.route, {
    this.arguments,
    required this.isPermission,
  });
}
