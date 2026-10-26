import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_variables/variable.dart';

class ReportBTNDashboard extends GetView {
  final String name;
  final IconData icon;
  final String desc;
  final VoidCallback onTap;

  ReportBTNDashboard({
    required this.name,
    required this.desc,
    required this.icon,
    required this.onTap,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10, left: 10, top: 5, bottom: 5),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
      height: 80,
      width: Get.width,
      child: Material(
        elevation: 2,
        color: darkMode.isFalse ? Colors.grey.shade100 : Colors.grey.shade900,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => onTap(),
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(left: 20),
                  width: 50,
                  child: Icon(icon, size: 35),
                ),
                //const SizedBox(width: 20),
                Flexible(
                  fit: FlexFit.tight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        desc,
                        style: const TextStyle(
                          height: 2,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(IconsaxPlusLinear.arrow_left_1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
