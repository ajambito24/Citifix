import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../utils/screen_util.dart';

/// How many announcements the carousel (and the notification list) shows.
const int kAnnouncementLimit = 5;

String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt).inSeconds.clamp(0, 1 << 31);
  if (diff < 60) return 'Just now';
  if (diff < 3600) return '${diff ~/ 60} min ago';
  if (diff < 86400) return '${diff ~/ 3600} hr ago';
  if (diff < 172800) return 'Yesterday';
  if (diff < 604800) return '${diff ~/ 86400} days ago';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
}

class _Announcement {
  final String id;
  final String text;
  final String imageUrl;
  final String authorName;
  final DateTime? createdAt;

  _Announcement(this.id, Map<String, dynamic> d)
      : text = (d['text'] ?? '').toString(),
        imageUrl = (d['imageUrl'] ?? '').toString(),
        authorName = (d['authorName'] ?? 'Administrator').toString(),
        createdAt = d['createdAt'] is Timestamp
            ? (d['createdAt'] as Timestamp).toDate()
            : null;
}

class AnnouncementCarousel extends StatefulWidget {
  /// Set this to an announcement id to make the carousel slide to it.
  final ValueNotifier<String?>? focusId;

  const AnnouncementCarousel({super.key, this.focusId});

  @override
  State<AnnouncementCarousel> createState() => _AnnouncementCarouselState();
}

class _AnnouncementCarouselState extends State<AnnouncementCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.92);
  late final Stream<QuerySnapshot> _stream = FirebaseFirestore.instance
      .collection('announcements')
      .orderBy('createdAt', descending: true)
      .limit(kAnnouncementLimit)
      .snapshots();

  List<_Announcement> _items = [];
  int _page = 0;

  @override
  void initState() {
    super.initState();
    widget.focusId?.addListener(_focus);
  }

  @override
  void dispose() {
    widget.focusId?.removeListener(_focus);
    _controller.dispose();
    super.dispose();
  }

  void _focus() {
    final id = widget.focusId?.value;
    if (id == null) return;

    // The list hasn't loaded yet (e.g. the app was opened from a push):
    // keep the id and try again when the announcements arrive.
    if (_items.isEmpty) return;

    final index = _items.indexWhere((a) => a.id == id);
    if (index >= 0 && _controller.hasClients) {
      _controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
    widget.focusId?.value = null; // so the same one can be focused again
  }

  void _openFull(_Announcement a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              a.authorName,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (a.createdAt != null)
              Text(
                timeAgo(a.createdAt!),
                style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
              ),
            if (a.imageUrl.isNotEmpty) ...[
              SizedBox(height: 14.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(14.r),
                child: Image.network(
                  a.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
            if (a.text.isNotEmpty) ...[
              SizedBox(height: 14.h),
              Text(
                a.text,
                style: TextStyle(
                  fontSize: 15.sp,
                  height: 1.4,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
            SizedBox(height: 10.h),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _note('Could not load announcements.');
        }
        if (!snapshot.hasData) {
          return SizedBox(
            height: 120.h,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        _items = snapshot.data!.docs
            .map((d) => _Announcement(d.id, d.data() as Map<String, dynamic>))
            .toList();

        // A focus request that arrived before the list loaded.
        if (widget.focusId?.value != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _focus();
          });
        }

        if (_items.isEmpty) return _note('No announcements yet.');

        final page = _page.clamp(0, _items.length - 1);

        return Column(
          children: [
            SizedBox(
              height: 300.h,
              child: PageView.builder(
                controller: _controller,
                itemCount: _items.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _card(_items[i]),
              ),
            ),
            if (_items.length > 1) ...[
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_items.length, (i) {
                  final active = i == page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    width: active ? 18.w : 7.w,
                    height: 7.w,
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  );
                }),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _note(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 28.h),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _card(_Announcement a) {
    final hasImage = a.imageUrl.isNotEmpty;

    return GestureDetector(
      onTap: () => _openFull(a),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 16.r,
              offset: Offset(0, 6.h),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasImage)
              SizedBox(
                height: 150.h,
                child: Image.network(
                  a.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.background,
                    child: Icon(Icons.broken_image,
                        size: 36.w, color: AppColors.textSecondary),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(14.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14.r,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            a.authorName.isEmpty
                                ? 'A'
                                : a.authorName[0].toUpperCase(),
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            a.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (a.createdAt != null)
                          Text(
                            timeAgo(a.createdAt!),
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    if (a.text.isNotEmpty)
                      Flexible(
                        child: Text(
                          a.text,
                          maxLines: hasImage ? 3 : 8,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.sp,
                            height: 1.4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}