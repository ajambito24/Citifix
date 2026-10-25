import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../utils/screen_util.dart';

// ==================== SHARED HELPERS ====================
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'resolved':
      return AppColors.success;
    case 'in progress':
      return AppColors.warning;
    case 'pending':
      return AppColors.error;
    default:
      return AppColors.textSecondary;
  }
}

// "in progress" -> "In Progress"
String _statusLabel(String status) {
  return status
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

String _formatDate(
  dynamic value, {
  bool withTime = false,
  String fallback = 'Recently submitted',
}) {
  if (value is! Timestamp) return fallback;

  final d = value.toDate();
  final date = '${_months[d.month - 1]} ${d.day}, ${d.year}';
  if (!withTime) return date;

  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final period = d.hour >= 12 ? 'PM' : 'AM';
  return '$date, $hour:$minute $period';
}

Widget _statusPill(String status) {
  final color = _statusColor(status);

  return Container(
    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
    decoration: BoxDecoration(
      color: color.withAlpha(31),
      borderRadius: BorderRadius.circular(20.r),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7.w,
          height: 7.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        SizedBox(width: 6.w),
        Text(
          _statusLabel(status),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 11.sp,
          ),
        ),
      ],
    ),
  );
}

Widget _referenceChip(String reference) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(6.r),
    ),
    child: Text(
      '#$reference',
      style: TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        color: AppColors.primary,
      ),
    ),
  );
}

BoxDecoration _cardDecoration({double radius = 20, double blur = 16}) {
  return BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(radius.r),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadow,
        blurRadius: blur.r,
        offset: Offset(0, 6.h),
      ),
    ],
  );
}

// One report row, with its reference number worked out once.
class _ReportItem {
  final String id;
  final Map<String, dynamic> data;
  final String reference;

  _ReportItem(this.id, this.data, this.reference);

  factory _ReportItem.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final id = doc.id;

    // Stored reference number, or derived from the document ID
    // for older reports that don't have the field.
    final reference = (data['referenceNumber'] ??
            (id.length >= 8 ? id.substring(0, 8) : id).toUpperCase())
        .toString();

    return _ReportItem(id, data, reference);
  }

  String get status => (data['status'] ?? 'pending').toString();
  String get category => (data['category'] ?? 'Issue').toString();
  String get description => (data['description'] ?? '').toString();
}

// ==================== MY REPORTS ====================
class MyReports extends StatefulWidget {
  const MyReports({super.key});

  @override
  State<MyReports> createState() => _MyReportsState();
}

class _MyReportsState extends State<MyReports> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _filter = 'all';

  static const _filters = <(String, String)>[
    ('all', 'All'),
    ('pending', 'Pending'),
    ('in progress', 'In Progress'),
    ('resolved', 'Resolved'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Newest first. A null createdAt means the server timestamp hasn't
  // arrived yet (just submitted), so it counts as newest.
  int _millis(dynamic createdAt) {
    if (createdAt is Timestamp) return createdAt.millisecondsSinceEpoch;
    return DateTime.now().millisecondsSinceEpoch;
  }

  bool _matches(_ReportItem item) {
    if (_filter != 'all' && item.status.toLowerCase() != _filter) {
      return false;
    }

    final q = _query.trim().toLowerCase().replaceFirst('#', '');
    if (q.isEmpty) return true;

    return item.category.toLowerCase().contains(q) ||
        item.description.toLowerCase().contains(q) ||
        item.reference.toLowerCase().contains(q) ||
        item.status.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'Please login first.',
            style: TextStyle(
              fontSize: 15.sp,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'My Reports',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .where(
              'userId',
              isEqualTo: user.uid,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _message(
              icon: Icons.error_outline,
              color: AppColors.error,
              title: 'Error loading reports',
              subtitle: '${snapshot.error}',
            );
          }

          final List<QueryDocumentSnapshot> docs = [
            ...(snapshot.data?.docs ?? <QueryDocumentSnapshot>[]),
          ];

          if (docs.isEmpty) {
            return _message(
              icon: Icons.description_outlined,
              color: AppColors.primary,
              title: 'No reports yet',
              subtitle: 'Your submitted reports will appear here.',
            );
          }

          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            return _millis(bData['createdAt'])
                .compareTo(_millis(aData['createdAt']));
          });

          final items = docs.map(_ReportItem.fromDoc).toList();
          final filtered = items.where(_matches).toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ScreenUtil.maxContentWidth,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                    child: _buildSearchBar(),
                  ),
                  SizedBox(height: 12.h),
                  _buildFilterChips(items),
                  SizedBox(height: 8.h),
                  Expanded(
                    child: filtered.isEmpty
                        ? _message(
                            icon: Icons.search_off,
                            color: AppColors.textSecondary,
                            title: 'No matching reports',
                            subtitle: 'Try a different search or filter.',
                          )
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(
                              16.w,
                              8.h,
                              16.w,
                              24.h,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];

                              return ReportCard(
                                title: item.category,
                                description: item.description,
                                status: item.status,
                                imageUrl:
                                    (item.data['imageUrl'] ?? '').toString(),
                                createdAt: item.data['createdAt'],
                                referenceNumber: item.reference,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ReportDetailPage(
                                        report: item.data,
                                        reference: item.reference,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: _cardDecoration(radius: 14, blur: 12),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _query = value;
          });
        },
        style: TextStyle(fontSize: 15.sp),
        decoration: InputDecoration(
          hintText: 'Search reports or #reference',
          hintStyle: TextStyle(
            fontSize: 14.sp,
            color: AppColors.textSecondary,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 22.w,
            color: AppColors.primary,
          ),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 20.w,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _query = '';
                    });
                  },
                ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14.h),
        ),
      ),
    );
  }

  Widget _buildFilterChips(List<_ReportItem> items) {
    int countFor(String key) {
      if (key == 'all') return items.length;
      return items.where((i) => i.status.toLowerCase() == key).length;
    }

    return SizedBox(
      height: 40.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final key = _filters[index].$1;
          final label = _filters[index].$2;
          final selected = _filter == key;

          return GestureDetector(
            onTap: () {
              setState(() {
                _filter = key;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 8.r,
                    offset: Offset(0, 3.h),
                  ),
                ],
              ),
              child: Text(
                '$label ${countFor(key)}',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: selected ? AppColors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Centered icon + text, used for the empty, error and no-match states.
  Widget _message({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96.w,
              height: 96.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(31),
              ),
              child: Icon(icon, size: 48.w, color: color),
            ),
            SizedBox(height: 20.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== REPORT CARD ====================
class ReportCard extends StatelessWidget {
  final String title;
  final String description;
  final String status;
  final String imageUrl;
  final dynamic createdAt;
  final String referenceNumber;
  final VoidCallback? onTap;

  const ReportCard({
    super.key,
    required this.title,
    required this.description,
    required this.status,
    required this.imageUrl,
    required this.createdAt,
    this.referenceNumber = '',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 14.h),
        padding: EdgeInsets.all(14.w),
        decoration: _cardDecoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== THUMBNAIL =====
            Container(
              width: 84.w,
              height: 84.w,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14.r),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Icon(
                            Icons.broken_image,
                            size: 28.w,
                            color: AppColors.textSecondary,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.report_problem,
                      size: 28.w,
                      color: AppColors.textSecondary,
                    ),
            ),
            SizedBox(width: 14.w),

            // ===== DETAILS =====
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (referenceNumber.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    _referenceChip(referenceNumber),
                  ],
                  SizedBox(height: 6.h),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      height: 1.3,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      _statusPill(status),
                      const Spacer(),
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== REPORT DETAIL ====================
class ReportDetailPage extends StatelessWidget {
  final Map<String, dynamic> report;
  final String reference;

  const ReportDetailPage({
    super.key,
    required this.report,
    required this.reference,
  });

  String _coordinates() {
    final lat = report['latitude'];
    final lng = report['longitude'];

    if (lat is num && lng is num) {
      return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);

    final category = (report['category'] ?? 'Issue').toString();
    final description = (report['description'] ?? '').toString();
    final status = (report['status'] ?? 'pending').toString();
    final imageUrl = (report['imageUrl'] ?? '').toString();
    final adminNotes = (report['adminNotes'] ?? '').toString().trim();

    final createdAt = report['createdAt'];
    final updatedAt = report['updatedAt'];
    final resolvedAt = report['resolvedAt'];

    // Only show "Last Updated" when it actually differs from submission.
    final showUpdated = createdAt is Timestamp &&
        updatedAt is Timestamp &&
        (updatedAt.millisecondsSinceEpoch - createdAt.millisecondsSinceEpoch)
                .abs() >
            60000;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Report Details',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: SafeArea(
        child: ResponsiveBody(
          alignment: Alignment.topCenter,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ===== PHOTO =====
              Container(
                height: 240.h,
                decoration: _cardDecoration(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20.r),
                  child: imageUrl.isEmpty
                      ? _photoPlaceholder(Icons.report_problem)
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                          errorBuilder: (_, __, ___) =>
                              _photoPlaceholder(Icons.broken_image),
                        ),
                ),
              ),
              SizedBox(height: 16.h),

              // ===== SUMMARY =====
              Container(
                padding: EdgeInsets.all(18.w),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        _statusPill(status),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        _referenceChip(reference),
                        SizedBox(width: 10.w),
                        Text(
                          _formatDate(createdAt),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // ===== DETAILS =====
              Container(
                padding: EdgeInsets.all(18.w),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Report Details',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _detailRow(
                      Icons.description,
                      'Description',
                      description.isEmpty ? '—' : description,
                    ),
                    SizedBox(height: 16.h),
                    _detailRow(
                      Icons.location_on,
                      'Location',
                      _coordinates(),
                    ),
                    SizedBox(height: 16.h),
                    _detailRow(
                      Icons.event,
                      'Submitted',
                      _formatDate(
                        createdAt,
                        withTime: true,
                      ),
                    ),
                    if (showUpdated) ...[
                      SizedBox(height: 16.h),
                      _detailRow(
                        Icons.update,
                        'Last Updated',
                        _formatDate(updatedAt, withTime: true),
                      ),
                    ],
                    if (resolvedAt is Timestamp) ...[
                      SizedBox(height: 16.h),
                      _detailRow(
                        Icons.check_circle_outline,
                        'Resolved',
                        _formatDate(resolvedAt, withTime: true),
                      ),
                    ],
                  ],
                ),
              ),

              // ===== ADMIN NOTES (only when there are any) =====
              if (adminNotes.isNotEmpty) ...[
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(18.w),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Admin Notes',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      _detailRow(
                        Icons.admin_panel_settings,
                        'Note from the team',
                        adminNotes,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPlaceholder(IconData icon) {
    return Container(
      color: AppColors.background,
      alignment: Alignment.center,
      child: Icon(icon, size: 48.w, color: AppColors.textSecondary),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(icon, size: 20.w, color: AppColors.primary),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}