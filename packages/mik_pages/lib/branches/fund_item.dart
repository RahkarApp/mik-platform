import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/source/remote/models/branch_fund.dart';
import 'package:mik_utils/public/price.dart';

class BranchFundItem extends StatelessWidget {
  final BranchFund item;
  final bool end;
  const BranchFundItem({required this.item, this.end = true, super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.boxBackground,
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(IconsaxPlusLinear.wallet),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(item.status == 'ACTIVE' ? 'فعال' : 'آرشیو'),
                    ],
                  ),
                  Text(item.kind == 'CASH' ? 'صندوق نقدی' : 'تنخواه'),
                  const SizedBox(height: 5),
                  Text('مانده: ${Price.showWithCurrency(item.balance)}'),
                  Text(
                    'قابل استفاده: ${Price.showWithCurrency(item.availableAmount)}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (end) EndLine(),
    ],
  );
}
