import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../utils/screen_util.dart';
import 'map_page.dart';
import 'my_reports.dart';
import 'profile.dart';
import 'report_page.dart';
import 'chatbotPage.dart';

class ResidentHome extends StatefulWidget {
  const ResidentHome({super.key});

  @override
  State<ResidentHome> createState() => _ResidentHomeState();
}

class _ResidentHomeState extends State<ResidentHome> {
  int currentIndex = 0;

  void changeTab(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: currentIndex,
        children: [
          HomeContent(
            onMapPressed: () => changeTab(1),
            onReportsPressed: () => changeTab(2),
          ),
          MapPage(
            active: currentIndex == 1,
          ),
          const MyReports(),
          const Profile(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: changeTab,
        height: 68.h,
        elevation: 8,
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.shadow,
        indicatorColor: AppColors.primarySoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12.sp,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          );
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
              color: AppColors.textSecondary,
            ),
            selectedIcon: Icon(
              Icons.home,
              color: AppColors.primary,
            ),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.map_outlined,
              color: AppColors.textSecondary,
            ),
            selectedIcon: Icon(
              Icons.map,
              color: AppColors.primary,
            ),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.description_outlined,
              color: AppColors.textSecondary,
            ),
            selectedIcon: Icon(
              Icons.description,
              color: AppColors.primary,
            ),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
              color: AppColors.textSecondary,
            ),
            selectedIcon: Icon(
              Icons.person,
              color: AppColors.primary,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  final VoidCallback onMapPressed;
  final VoidCallback onReportsPressed;

  const HomeContent({
    super.key,
    required this.onMapPressed,
    required this.onReportsPressed,
  });

  // Soft white used for the decorative circles on the banner.
  static const Color _bannerGlow = Color(0x1FFFFFFF);

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);

    return SafeArea(
      child: ResponsiveBody(
        alignment: Alignment.topCenter,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            SizedBox(height: 20.h),
            _buildWelcomeCard(),
            SizedBox(height: 28.h),
            _buildSectionTitle('Quick Actions', Icons.bolt),
            SizedBox(height: 14.h),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14.w,
              mainAxisSpacing: 14.h,
              childAspectRatio: 1.0,
              children: [
                _button(
                  context,
                  Icons.report_problem,
                  'Report Issue',
                  'Submit a new report',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReportPage(),
                      ),
                    );
                  },
                ),
                _button(
                  context,
                  Icons.map,
                  'Map',
                  'View nearby issues',
                  onMapPressed,
                ),
                _button(
                  context,
                  Icons.description,
                  'My Reports',
                  'Track your reports',
                  onReportsPressed,
                ),
                _button(
                  context,
                  Icons.smart_toy,
                  'CitiFix Chatbot',
                  'Ask for help',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const Chatbot(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===== HEADER =====
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Home',
          style: TextStyle(
            fontSize: 28.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'What would you like to do today?',
          style: TextStyle(
            fontSize: 14.sp,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ===== WELCOME BANNER =====
  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 24.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30.w,
            top: -30.w,
            child: Container(
              width: 120.w,
              height: 120.w,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _bannerGlow,
              ),
            ),
          ),
          Positioned(
            right: 24.w,
            bottom: -24.w,
            child: Container(
              width: 80.w,
              height: 80.w,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _bannerGlow,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(24.w),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to CitiFix!',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Report community issues '
                        'and help make Sampaloc better.',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 14.sp,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                Icon(
                  Icons.location_city,
                  size: 44.w,
                  color: AppColors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== SECTION TITLE =====
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 22.w, color: AppColors.primary),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  // ===== QUICK ACTION TILE =====
  Widget _button(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 24.r,
                offset: Offset(0, 8.h),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 28.w,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
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