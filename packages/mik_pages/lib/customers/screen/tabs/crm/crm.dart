part of '../../screen.dart';

class CRMTabDashboard extends GetView {
  const CRMTabDashboard({super.key});
  @override
  Widget build(BuildContext context) => Obx(
    () => CustomerCrmScreen(
      appId: 'mik',
      embedded: true,
      query: customerSearch.value,
    ),
  );
}
