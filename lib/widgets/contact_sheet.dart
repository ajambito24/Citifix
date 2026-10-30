import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../utils/screen_util.dart';

/// One row in the contact sheet. If [dial] is null the row shows no call
/// button, so unknown numbers never get a fake tap target.
class _Contact {
  final IconData icon;
  final String name;
  final String detail;
  final String? dial;

  const _Contact({
    required this.icon,
    required this.name,
    required this.detail,
    this.dial,
  });
}

// ===== EDIT THESE =====
// Only 911, 143, 8888 and the Manila city government line were found in
// public sources. Verify the city line and fill in the District 4 numbers.
const _cityHall = <_Contact>[
  _Contact(
    icon: Icons.location_on,
    name: 'Manila City Hall',
    detail: 'Padre Burgos Ave, Ermita, Manila',
  ),
  _Contact(
    icon: Icons.phone,
    name: 'City Hall Trunkline',
    detail: '(02) 8568-6909',
    dial: '+63285686909',
  ),
  _Contact(
    icon: Icons.schedule,
    name: 'Office Hours',
    // TODO: confirm with the city office.
    detail: 'Mon to Fri, 8:00 AM to 5:00 PM',
  ),
];

const _districtFour = <_Contact>[
  _Contact(
    icon: Icons.support_agent,
    name: 'District 4 (Sampaloc) Hotline',
    // TODO: add the real number, then set dial.
    detail: 'Number not added yet',
  ),
  _Contact(
    icon: Icons.apartment,
    name: 'District 4 Office',
    // TODO: add the real office address.
    detail: 'Address not added yet',
  ),
];

const _emergency = <_Contact>[
  _Contact(
    icon: Icons.emergency,
    name: 'National Emergency',
    detail: '911',
    dial: '911',
  ),
  _Contact(
    icon: Icons.volunteer_activism,
    name: 'Philippine Red Cross',
    detail: '143',
    dial: '143',
  ),
  _Contact(
    icon: Icons.campaign,
    name: 'Public Complaint Hotline',
    detail: '8888',
    dial: '8888',
  ),
];

void showContactSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.white,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (_) => const _ContactSheet(),
  );
}

class _ContactSheet extends StatelessWidget {
  const _ContactSheet();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: ScreenUtil.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Contact Us',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 16.h),
              _section(context, 'Manila City Hall', _cityHall),
              _section(context, 'District 4', _districtFour),
              _section(context, 'Emergency', _emergency, urgent: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    List<_Contact> items, {
    bool urgent = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: urgent ? AppColors.error : AppColors.primary,
            ),
          ),
          SizedBox(height: 8.h),
          for (final c in items) _row(context, c, urgent: urgent),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, _Contact c, {required bool urgent}) {
    final accent = urgent ? AppColors.error : AppColors.primary;

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: [
            Icon(c.icon, size: 22.w, color: accent),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    c.detail,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (c.dial != null)
              IconButton.filled(
                onPressed: () => _call(context, c.dial!),
                style: IconButton.styleFrom(backgroundColor: accent),
                icon: Icon(Icons.call, size: 20.w, color: AppColors.white),
                tooltip: 'Call ${c.name}',
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _call(BuildContext context, String dial) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(Uri(scheme: 'tel', path: dial));
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the phone app.')),
      );
    }
  }
}