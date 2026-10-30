import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../services/push_service.dart';
import '../../utils/screen_util.dart';
import '../../widgets/contact_sheet.dart';
import 'announcement_carousel.dart';
import 'chatbotPage.dart';
import 'map_page.dart';
import 'my_reports.dart';
import 'notifications_screen.dart';
import 'profile.dart';
import 'report_page.dart';

class ResidentHome extends StatefulWidget {
  const ResidentHome({super.key});

  @override
  State<ResidentHome> createState() => _ResidentHomeState();
}

class _ResidentHomeState extends State<ResidentHome> {

  int currentIndex = 0;

  final ValueNotifier<String?> _focusAnnouncement =
      ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();

    final push = PushService.instance;
    push.tap.addListener(_onPushTap);
    unawaited(push.init());
  }

  @override
  void dispose() {
    PushService.instance.tap.removeListener(_onPushTap);
    _focusAnnouncement.dispose();
    super.dispose();
  }

  void changeTab(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  void _openReportForm() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReportPage()),
    );
  }

  // ===== ROUTING (shared by the bell and by push taps) =====
  // fromPush: the notification was tapped outside the app, so the matching
  // bell item is marked as read here (the bell marks its own tiles itself).
  Future<void> _handleTarget(
    NotificationTarget target, {
    bool fromPush = false,
  }) async {
    if (target.type == NotificationType.announcement) {
      if (fromPush) {
        markNotificationRead(announcementNotificationId(target.id));
      }
      changeTab(0);
      _focusAnnouncement.value = target.id;
    } else {
      await _openReport(target.id, markRead: fromPush);
    }
  }

  Future<void> _openNotifications() async {
    final target = await Navigator.push<NotificationTarget>(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    if (target == null || !mounted) return;

    await _handleTarget(target);
  }

  // A push can be tapped while another screen is open on top of Home
  // (report form, notifications list, ...): go back to Home first.
  void _openFromPush(NotificationTarget target) {
    if (!mounted) return;

    final route = ModalRoute.of(context);
    if (route != null) {
      Navigator.of(context).popUntil((r) => r == route || r.isFirst);
    }
    _handleTarget(target, fromPush: true);
  }

  // Push tapped (app closed, in the background, or open).
  void _onPushTap() {
    final target = PushService.instance.tap.value;
    if (target == null) return;

    PushService.instance.tap.value = null;
    _openFromPush(target);
  }

  Future<void> _openReport(String reportId, {bool markRead = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .get();
      if (!mounted) return;

      if (!doc.exists) {
        messenger.showSnackBar(
          const SnackBar(content: Text('That report no longer exists.')),
        );
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      if (markRead) {
        final notificationId = latestReportNotificationId(doc.id, data);
        if (notificationId != null) markNotificationRead(notificationId);
      }

      changeTab(2); // My Reports, so Back lands there
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportDetailPage(
            report: data,
            reference: reportReferenceOf(doc.id, data),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the report.')),
      );
    }
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
            onNotificationsPressed: _openNotifications,
            focusAnnouncement: _focusAnnouncement,
          ),
          MapPage(active: currentIndex == 1),
          const MyReports(),
          const Profile(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildReportButton(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ===== CENTER REPORT BUTTON =====
  Widget _buildReportButton() {
    return Container(
      width: 68.w,
      height: 68.w,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryRing,
      ),
      padding: EdgeInsets.all(5.w),
      child: FloatingActionButton(
        heroTag: null,
        onPressed: _openReportForm,
        tooltip: 'Report an issue',
        elevation: 6,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        shape: const CircleBorder(),
        child: Icon(Icons.add_a_photo, size: 28.w),
      ),
    );
  }

  // ===== BOTTOM BAR =====
  Widget _buildBottomBar() {
    return BottomAppBar(
      height: 64.h,
      padding: EdgeInsets.zero,
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: AppColors.shadow,
      elevation: 8,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        children: [
          _navItem(0, Icons.home_outlined, Icons.home, 'Home'),
          _navItem(1, Icons.map_outlined, Icons.map, 'Map'),
          // Gap under the floating button, with its label.
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: Text(
                  'Report',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
          _navItem(
            2,
            Icons.description_outlined,
            Icons.description,
            'My Reports',
          ),
          _navItem(3, Icons.person_outline, Icons.person, 'Profile'),
        ],
      ),
    );
  }

  Widget _navItem(
    int index,
    IconData icon,
    IconData selectedIcon,
    String label,
  ) {
    final selected = currentIndex == index;
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: () => changeTab(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, size: 24.w, color: color),
            SizedBox(height: 2.h),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  final VoidCallback onNotificationsPressed;
  final ValueNotifier<String?> focusAnnouncement;

  const HomeContent({
    super.key,
    required this.onNotificationsPressed,
    required this.focusAnnouncement,
  });

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ResponsiveBody(
        alignment: Alignment.topCenter,
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 48.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWelcomeCard(),
            SizedBox(height: 28.h),
            _buildSectionTitle('Announcements', Icons.campaign),
            SizedBox(height: 14.h),
            AnnouncementCarousel(focusId: focusAnnouncement),
            SizedBox(height: 28.h),
            _buildSectionTitle('Need help?', Icons.support_agent),
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: _helpButton(
                    Icons.phone_in_talk,
                    'Contact Us',
                    () => showContactSheet(context),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: _helpButton(
                    Icons.smart_toy,
                    'CitiFix Chatbot',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const Chatbot()),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
          ),
        ],
      ),
    );
  }

  // ===== HEADER =====
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ScreenUtil.maxContentWidth,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 12.w, 8.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Home',
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  NotificationBell(onPressed: onNotificationsPressed),
                ],
              ),
            ),
          ),
        ),
      ),
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
          Positioned.fill(
            child: Opacity(
              opacity: 0.25,
              child: Image.asset(
                'assets/manilacityhallbackground.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(24.w),
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
                  'Report community issues and help make Sampaloc better.',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 14.sp,
                    height: 1.4,
                  ),
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

  // ===== HELP BUTTON =====
  Widget _helpButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 24.r,
                offset: Offset(0, 8.h),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22.w, color: AppColors.primary),
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}