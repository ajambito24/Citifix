import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../utils/screen_util.dart';
import 'announcement_carousel.dart';
import 'my_reports.dart';

enum NotificationType { announcement, report }

/// Returned by NotificationsScreen (via Navigator.pop) so Home can redirect.
class NotificationTarget {
  final NotificationType type;
  final String id; // announcement id or report id
  const NotificationTarget(this.type, this.id);
}

class AppNotification {
  final String id; // also the doc id in users/{uid}/notificationReads
  final NotificationType type;
  final String targetId;
  final String title;
  final String body;
  final DateTime time;

  const AppNotification({
    required this.id,
    required this.type,
    required this.targetId,
    required this.title,
    required this.body,
    required this.time,
  });
}

// ==================== NOTIFICATION IDS + READ STATE ====================
// Shared by the bell list and by push taps, so both always use the same ids.

String _statusKeyOf(String s) => s.trim().toLowerCase().replaceAll(' ', '_');

String announcementNotificationId(String announcementId) =>
    'ann_$announcementId';

String reportNotificationId(String reportId, String status, Timestamp at) =>
    'rep_${reportId}_${_statusKeyOf(status)}_${at.millisecondsSinceEpoch}';

/// Id of the newest status-change notification of a report, or null if the
/// report has none (still pending). Same rules the bell list uses.
String? latestReportNotificationId(String reportId, Map<String, dynamic> d) {
  final history = d['statusHistory'];
  String? latestId;
  int latestMillis = -1;

  if (history is List) {
    for (final e in history) {
      if (e is! Map) continue;
      final status = (e['status'] ?? '').toString().toLowerCase();
      final at = e['at'];
      if (status.isEmpty || status == 'pending' || at is! Timestamp) continue;

      if (at.millisecondsSinceEpoch >= latestMillis) {
        latestMillis = at.millisecondsSinceEpoch;
        latestId = reportNotificationId(reportId, status, at);
      }
    }
  }
  if (latestId != null) return latestId;

  // Older reports without history: the current status.
  final current = (d['status'] ?? 'pending').toString().toLowerCase();
  final updated = d['updatedAt'];
  if (current != 'pending' && updated is Timestamp) {
    return reportNotificationId(reportId, current, updated);
  }
  return null;
}

/// Marks one notification as read for the signed-in user.
Future<void> markNotificationRead(String id) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notificationReads')
        .doc(id)
        .set({'readAt': FieldValue.serverTimestamp()});
  } catch (_) {
    // read state is cosmetic: ignore failures
  }
}

/// Builds the notification list from announcements + the user's own report
/// status changes, together with which ones were already read.
class NotificationsFeed extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    List<AppNotification> items,
    Set<String> readIds,
  ) builder;

  const NotificationsFeed({super.key, required this.builder});

  @override
  State<NotificationsFeed> createState() => _NotificationsFeedState();
}

class _NotificationsFeedState extends State<NotificationsFeed> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final _db = FirebaseFirestore.instance;

  late final Stream<QuerySnapshot>? _announcements = _user == null
      ? null
      : _db
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .limit(kAnnouncementLimit)
          .snapshots();

  late final Stream<QuerySnapshot>? _reports = _user == null
      ? null
      : _db
          .collection('reports')
          .where('userId', isEqualTo: _user.uid)
          .snapshots();

  late final Stream<QuerySnapshot>? _reads = _user == null
      ? null
      : _db
          .collection('users')
          .doc(_user.uid)
          .collection('notificationReads')
          .snapshots();

  String _reportTitle(String ref, String status) {
    switch (status) {
      case 'in progress':
        return 'Report #$ref is now In Progress';
      case 'resolved':
        return 'Report #$ref has been resolved';
      case 'rejected':
        return 'Report #$ref was rejected';
      default:
        return 'Report #$ref was updated';
    }
  }

  List<AppNotification> _build(
    QuerySnapshot? ann,
    QuerySnapshot? rep,
  ) {
    final items = <AppNotification>[];

    for (final doc in ann?.docs ?? <QueryDocumentSnapshot>[]) {
      final d = doc.data() as Map<String, dynamic>;
      final text = (d['text'] ?? '').toString().trim();
      final created = d['createdAt'];
      items.add(AppNotification(
        id: announcementNotificationId(doc.id),
        type: NotificationType.announcement,
        targetId: doc.id,
        title: 'New announcement',
        body: text.isEmpty ? 'Photo' : text,
        time: created is Timestamp ? created.toDate() : DateTime.now(),
      ));
    }

    for (final doc in rep?.docs ?? <QueryDocumentSnapshot>[]) {
      final d = doc.data() as Map<String, dynamic>;
      final ref = reportReferenceOf(doc.id, d);
      final category = (d['category'] ?? 'Issue').toString();
      final history = d['statusHistory'];
      var added = false;

      if (history is List) {
        for (final e in history) {
          if (e is! Map) continue;
          final status = (e['status'] ?? '').toString().toLowerCase();
          final at = e['at'];
          if (status.isEmpty || status == 'pending' || at is! Timestamp) {
            continue;
          }
          items.add(AppNotification(
            id: reportNotificationId(doc.id, status, at),
            type: NotificationType.report,
            targetId: doc.id,
            title: _reportTitle(ref, status),
            body: category,
            time: at.toDate(),
          ));
          added = true;
        }
      }

      // Older reports without history: one notification for the current status.
      final current = (d['status'] ?? 'pending').toString().toLowerCase();
      final updated = d['updatedAt'];
      if (!added && current != 'pending' && updated is Timestamp) {
        items.add(AppNotification(
          id: reportNotificationId(doc.id, current, updated),
          type: NotificationType.report,
          targetId: doc.id,
          title: _reportTitle(ref, current),
          body: category,
          time: updated.toDate(),
        ));
      }
    }

    items.sort((a, b) => b.time.compareTo(a.time));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return widget.builder(context, const [], const {});

    return StreamBuilder<QuerySnapshot>(
      stream: _announcements,
      builder: (context, annSnap) => StreamBuilder<QuerySnapshot>(
        stream: _reports,
        builder: (context, repSnap) => StreamBuilder<QuerySnapshot>(
          stream: _reads,
          builder: (context, readSnap) {
            final readIds = (readSnap.data?.docs ?? <QueryDocumentSnapshot>[])
                .map((d) => d.id)
                .toSet();
            return widget.builder(
              context,
              _build(annSnap.data, repSnap.data),
              readIds,
            );
          },
        ),
      ),
    );
  }
}

// ==================== BELL (used in Home header) ====================
class NotificationBell extends StatelessWidget {
  final VoidCallback onPressed;
  const NotificationBell({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return NotificationsFeed(
      builder: (context, items, readIds) {
        final unread = items.where((n) => !readIds.contains(n.id)).length;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox(
            width: 44.w,
            height: 44.w,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 26.w,
                  color: AppColors.textPrimary,
                ),
                if (unread > 0)
                  Positioned(
                    right: 2.w,
                    top: 2.w,
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                      constraints: BoxConstraints(minWidth: 18.w),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== SCREEN ====================
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  CollectionReference<Map<String, dynamic>>? get _readsRef {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notificationReads');
  }

  void _markRead(AppNotification n) {
    markNotificationRead(n.id);
  }

  Future<void> _markAllRead(List<AppNotification> unread) async {
    final ref = _readsRef;
    if (ref == null || unread.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final n in unread) {
      batch.set(ref.doc(n.id), {'readAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);

    return NotificationsFeed(
      builder: (context, items, readIds) {
        final unread = items.where((n) => !readIds.contains(n.id)).toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              'Notifications',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            actions: [
              if (unread.isNotEmpty)
                IconButton(
                  tooltip: 'Mark all as read',
                  icon: const Icon(Icons.done_all),
                  onPressed: () => _markAllRead(unread),
                ),
            ],
          ),
          body: items.isEmpty
              ? Center(
                  child: Text(
                    'No notifications yet.',
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: ScreenUtil.maxContentWidth,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.all(16.w),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final n = items[i];
                        return _tile(context, n, !readIds.contains(n.id));
                      },
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, AppNotification n, bool unread) {
    final isAnn = n.type == NotificationType.announcement;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _markRead(n);
        Navigator.pop(context, NotificationTarget(n.type, n.targetId));
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: unread ? AppColors.white : AppColors.white.withAlpha(180),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 12.r,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAnn ? Icons.campaign : Icons.assignment_turned_in,
                size: 22.w,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: unread ? FontWeight.bold : FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    n.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    timeAgo(n.time),
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                margin: EdgeInsets.only(left: 8.w, top: 4.h),
                width: 10.w,
                height: 10.w,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}