import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppLanguageController extends ValueNotifier<Locale> {
  AppLanguageController() : super(const Locale('bn'));

  void toggle() {
    value = value.languageCode == 'en'
        ? const Locale('bn')
        : const Locale('en');
  }

  void setLanguage(String languageCode) {
    value = Locale(languageCode == 'en' ? 'en' : 'bn');
  }

  String get languageCode => value.languageCode;
}

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLanguageController controllerOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    if (scope == null || scope.notifier == null) {
      throw StateError('AppLanguageScope is missing in the widget tree.');
    }
    return scope.notifier!;
  }
}

extension AppLocalizationText on BuildContext {
  String tr(String key) {
    final languageCode = AppLanguageScope.controllerOf(this).languageCode;
    return _localizedValues[languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }
}

class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppLanguageScope.controllerOf(context);
    return Semantics(
      label: 'Language',
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppPalette.blush.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppPalette.plum.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageSegment(
              label: 'বাংলা',
              selected: controller.languageCode == 'bn',
              onTap: () => controller.setLanguage('bn'),
            ),
            _LanguageSegment(
              label: 'Eng',
              selected: controller.languageCode == 'en',
              onTap: () => controller.setLanguage('en'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageSegment extends StatelessWidget {
  const _LanguageSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppPalette.aubergine : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: label == 'Eng' ? 'Manrope' : 'NotoSansBengali',
            color: selected ? Colors.white : AppPalette.aubergine,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

const Map<String, Map<String, String>> _localizedValues = {
  'en': {
    'app_name': 'MediMind',
    'tagline': 'Simple, clear medicine reminders for families.',
    'choose_sign_in': 'Choose how to sign in',
    'phone_number': 'Phone number',
    'phone_sign_in_subtitle': 'Use any common Bangladesh number format',
    'google_account': 'Gmail account',
    'google_sign_in_subtitle': 'Continue securely with Google',
    'google_sign_in': 'Google Sign In',
    'continue_google': 'Continue with Google',
    'continue_google_subtitle': 'Continue with your Google account.',
    'create_account': 'Create account',
    'full_name': 'Full name',
    'other_sign_in_options': 'Other sign-in options',
    'sign_in': 'Sign in',
    'sign_up': 'Sign up',
    'email_address': 'Email address',
    'password': 'Password',
    'phone_sign_in': 'Phone sign in',
    'bangladesh_mobile_number': 'Bangladesh mobile number',
    'phone_format_help': 'Enter +8801…, 01…, or 1…',
    'verification_code': 'Verification code',
    'enter_six_digit_code': 'Enter the 6-digit verification code.',
    'send_code': 'Send code',
    'verify_and_sign_in': 'Verify and sign in',
    'request_code_first': 'Request the verification code first.',
    'verification_sent': 'Verification code sent.',
    'code_sent_to': 'Code sent to',
    'dashboard_today': "Today's medicines",
    'today': 'Today',
    'dashboard_active': 'Active',
    'dashboard_next_in': 'Next in',
    'dashboard_items': 'medicines',
    'add_medicine': 'Add medicine',
    'backup': 'Backup',
    'backup_complete': 'Backup complete.',
    'backup_waiting': 'Saved on this device. Backup will retry when online.',
    'no_active_medicines': 'No medicines scheduled',
    'next_medicine': 'Next medicine',
    'next_event': 'Next event',
    'no_upcoming_events': 'No upcoming events',
    'meal_event': 'Meal',
    'tomorrow_short': 'Tomorrow',
    'add_first_reminder': 'Add your first medicine',
    'create_first_reminder_hint':
        'Add a medicine and you will be reminded at the right time.',
    'due_in': 'Due in',
    'refresh_from_cloud': 'Refresh from cloud',
    'sign_out': 'Sign out',
    'no_medicine_saved': 'No medicines saved yet',
    'no_medicine_today': 'No medicine is scheduled for today.',
    'reports': 'Reports',
    'report_load_error': 'The local report could not be loaded.',
    'last_7_days': 'Last 7 days',
    'last_30_days': 'Last 30 days',
    'report_period': 'Report period',
    'report_details': 'Detailed history',
    'medicines_taken': 'Medicines taken',
    'medicines_not_taken': 'Medicines not taken',
    'meals_taken': 'Meals taken',
    'meals_not_taken': 'Meals not taken',
    'no_report_entries': 'No activity has been recorded in this period.',
    'report_range_hint':
        'Mark medicine and meal status from the dashboard to build the report.',
    'empty_medicine_hint':
        'Add a medicine once; reminders and backup will be handled automatically.',
    'edit': 'Edit',
    'delete': 'Delete',
    'dose': 'Dosage',
    'time': 'Time',
    'formula': 'Generic / formula',
    'company': 'Company',
    'notes': 'Notes',
    'type': 'Type',
    'power': 'Power',
    'edit_medicine': 'Edit medicine',
    'create_medicine_reminder': 'Create a medicine reminder',
    'update_medicine_details': 'Update medicine details',
    'medicine_details': 'Medicine details',
    'medicine_name_required': 'Medicine name *',
    'medicine_type': 'Medicine type',
    'power_value': 'Power',
    'power_unit': 'Unit',
    'formula_optional': 'Generic / formula (optional)',
    'company_optional': 'Company name (optional)',
    'notes_optional': 'Notes (optional)',
    'dosage_builder': 'Reminder times and dosage',
    'add_dose_line': 'Add another time',
    'dose_line': 'Reminder',
    'remove_dose_line': 'Remove reminder',
    'dosage': 'Dosage',
    'dosage_value': 'How much',
    'choose_reminder_time': 'Choose reminder time',
    'repeat_schedule': 'Repeat schedule',
    'repeat_medicine': 'How often to take it',
    'daily': 'Every day',
    'weekly': 'Every week',
    'every15Days': 'Every 15 days',
    'monthly': 'Every month',
    'custom': 'Custom number of days',
    'custom_repeat_days': 'Repeat every',
    'days': 'days',
    'schedule': 'Schedule',
    'every_n_days': 'Every',
    'meal_schedule': 'Meal schedule',
    'meal_schedule_enabled': 'Enable a meal-time reminder',
    'meal_schedule_help':
        'The meal reminder is calculated automatically from each medicine time.',
    'meal_relation': 'When to take the medicine',
    'before_meal_30': '30 minutes before a meal',
    'before_meal_custom': 'Before the meal',
    'at_meal': 'With the meal',
    'after_meal_30': '30 minutes after a meal',
    'after_meal_custom': 'After the meal',
    'custom_meal_minutes': 'Time difference',
    'minutes_short': 'minutes',
    'calculated_meal_times': 'Calculated meal times',
    'medicine_at': 'Medicine at',
    'meal_at': 'meal at',
    'photo': 'Medicine photo',
    'medicine_photo_help':
        'Optional. A clear photo helps identify the correct medicine on the dashboard and Android reminders.',
    'photo_saved_locally': 'Photo saved on this device',
    'no_photo_selected': 'No photo selected',
    'take_photo': 'Take photo',
    'save_medicine': 'Save medicine',
    'update_medicine': 'Update medicine',
    'medicine_name_required_error': 'Please enter the medicine name.',
    'dose_line_required_error': 'Add at least one reminder time and dosage.',
    'power_required_error': 'Enter the medicine power.',
    'duplicate_dose_time_error': 'Each reminder time must be different.',
    'custom_days_error': 'Enter a repeat interval from 1 to 365 days.',
    'meal_minutes_error': 'Enter a meal difference from 1 to 720 minutes.',
    'meal_timing_conflict_title': 'Meal timing conflict',
    'meal_timing_conflict_requested': 'This would create a meal at',
    'meal_timing_conflict_existing': 'An existing medicine already uses',
    'meal_timing_conflict_fix': 'Set this medicine time to',
    'use_suggested_time': 'Use suggested time',
    'understood': 'Understood',
    'tablet': 'Tablet',
    'capsule': 'Capsule',
    'syrup': 'Syrup',
    'drop': 'Drop',
    'insulin': 'Insulin',
    'pill': 'pill',
    'ml': 'mL',
    'drop_unit': 'drop',
    'units': 'Units',
    'medicine_status': 'Medicine',
    'meal_status': 'Meal',
    'status_taken': 'Taken',
    'status_not_taken': 'Not taken',
    'status_pending': 'Not marked',
    'mark_taken': 'Taken',
    'mark_not_taken': 'Not taken',
    'when_taken': 'When was the medicine taken?',
    'taken_now': 'Taken now',
    'taken_with_food': 'Taken with food',
    'taken_later': 'Taken at a different time',
    'choose_actual_time': 'Choose the actual time taken',
    'also_with_food': 'Was it taken with food?',
    'without_food': 'Without food',
    'with_food': 'with food',
    'next': 'Next',
    'now': 'Now',
    'dose_not_set': 'Dosage not set',
    'auth_failed': 'Authentication failed. Please try again.',
    'invalid_phone': 'Enter a valid Bangladesh mobile number.',
    'billing_required': 'Real verification SMS requires Firebase billing.',
    'phone_disabled': 'Phone sign-in is not enabled in Firebase.',
    'region_blocked': 'Firebase is not configured to send SMS to Bangladesh.',
    'unauthorized_domain': 'This web address is not authorized in Firebase.',
    'browser_verification_failed':
        'Firebase could not verify this browser. Refresh and try again.',
    'too_many_requests':
        'Too many attempts. Please wait before requesting another code.',
    'quota_exceeded': 'The Firebase SMS quota has been exceeded.',
    'invalid_code': 'The verification code is incorrect.',
    'expired_code': 'The verification code has expired. Request a new code.',
  },
  'bn': {
    'app_name': 'MediMind',
    'tagline': 'পরিবারের ওষুধ ঠিক সময়ে মনে রাখার সহজ উপায়।',
    'choose_sign_in': 'যেভাবে প্রবেশ করতে চান',
    'phone_number': 'মোবাইল নম্বর',
    'phone_sign_in_subtitle': 'বাংলাদেশি নম্বর যেকোনো প্রচলিতভাবে লিখুন',
    'google_account': 'জিমেইল অ্যাকাউন্ট',
    'google_sign_in_subtitle': 'গুগল অ্যাকাউন্ট দিয়ে নিরাপদে প্রবেশ করুন',
    'google_sign_in': 'গুগল সাইন ইন',
    'continue_google': 'গুগল দিয়ে চালিয়ে যান',
    'continue_google_subtitle': 'আপনার গুগল অ্যাকাউন্ট দিয়ে চালিয়ে যান।',
    'create_account': 'অ্যাকাউন্ট তৈরি',
    'full_name': 'পূর্ণ নাম',
    'other_sign_in_options': 'অন্যান্য সাইন-ইন অপশন',
    'sign_in': 'সাইন ইন',
    'sign_up': 'সাইন আপ',
    'email_address': 'ইমেইল ঠিকানা',
    'password': 'পাসওয়ার্ড',
    'phone_sign_in': 'মোবাইল নম্বর দিয়ে প্রবেশ',
    'bangladesh_mobile_number': 'বাংলাদেশি মোবাইল নম্বর',
    'phone_format_help': '+৮৮০১…, ০১… অথবা ১…—যেভাবে সহজ লিখুন',
    'verification_code': 'যাচাই কোড',
    'enter_six_digit_code': '৬ সংখ্যার যাচাই কোডটি লিখুন।',
    'send_code': 'কোড পাঠান',
    'verify_and_sign_in': 'যাচাই করে প্রবেশ করুন',
    'request_code_first': 'আগে যাচাই কোড পাঠাতে বলুন।',
    'verification_sent': 'যাচাই কোড পাঠানো হয়েছে।',
    'code_sent_to': 'কোড পাঠানো হয়েছে',
    'dashboard_today': 'আজকের ওষুধ',
    'today': 'আজ',
    'dashboard_active': 'চালু',
    'dashboard_next_in': 'পরেরটি',
    'dashboard_items': 'টি ওষুধ',
    'add_medicine': 'ওষুধ যোগ করুন',
    'backup': 'ব্যাকআপ নিন',
    'backup_complete': 'ব্যাকআপ সম্পন্ন হয়েছে।',
    'backup_waiting': 'এই ডিভাইসে রাখা হয়েছে। ইন্টারনেট এলে ব্যাকআপ হয়ে যাবে।',
    'no_active_medicines': 'এখন কোনো ওষুধের সময় নেই',
    'next_medicine': 'পরের ওষুধ',
    'next_event': 'এরপর যা হবে',
    'no_upcoming_events': 'সামনে কিছু নির্ধারিত নেই',
    'meal_event': 'খাবারের সময়',
    'tomorrow_short': 'আগামীকাল',
    'add_first_reminder': 'প্রথম ওষুধটি যোগ করুন',
    'create_first_reminder_hint':
        'ওষুধ যোগ করলে ঠিক সময়ে আপনাকে মনে করিয়ে দেওয়া হবে।',
    'due_in': 'সময় বাকি',
    'refresh_from_cloud': 'ক্লাউড থেকে হালনাগাদ করুন',
    'sign_out': 'বের হয়ে যান',
    'no_medicine_saved': 'এখনো কোনো ওষুধ যোগ করা হয়নি',
    'no_medicine_today': 'আজ কোনো ওষুধ খাওয়ার সময় নেই।',
    'reports': 'রিপোর্ট',
    'report_load_error': 'ডিভাইসে রাখা রিপোর্টটি খোলা যায়নি।',
    'last_7_days': 'গত ৭ দিন',
    'last_30_days': 'গত ৩০ দিন',
    'report_period': 'রিপোর্টের সময়সীমা',
    'report_details': 'বিস্তারিত হিসাব',
    'medicines_taken': 'ওষুধ নিয়েছেন',
    'medicines_not_taken': 'ওষুধ নেননি',
    'meals_taken': 'খাবার খেয়েছেন',
    'meals_not_taken': 'খাবার খাননি',
    'no_report_entries': 'এই সময়ের মধ্যে কোনো তথ্য দেওয়া হয়নি।',
    'report_range_hint':
        'ড্যাশবোর্ড থেকে ওষুধ ও খাবারের অবস্থা জানালে এখানে হিসাব দেখা যাবে।',
    'empty_medicine_hint':
        'একবার ওষুধ যোগ করুন—সময়মতো মনে করানো ও ব্যাকআপের কাজ অ্যাপই করবে।',
    'edit': 'পরিবর্তন করুন',
    'delete': 'মুছে ফেলুন',
    'dose': 'খাওয়ার পরিমাণ',
    'time': 'সময়',
    'formula': 'জেনেরিক / ফর্মুলা',
    'company': 'কোম্পানি',
    'notes': 'বিশেষ নির্দেশনা',
    'type': 'ধরন',
    'power': 'শক্তি',
    'edit_medicine': 'ওষুধের তথ্য পরিবর্তন',
    'create_medicine_reminder': 'নতুন ওষুধ যোগ করুন',
    'update_medicine_details': 'ওষুধের তথ্য হালনাগাদ করুন',
    'medicine_details': 'ওষুধের পরিচিতি',
    'medicine_name_required': 'ওষুধের নাম *',
    'medicine_type': 'ওষুধের ধরন',
    'power_value': 'শক্তির পরিমাণ',
    'power_unit': 'একক',
    'formula_optional': 'জেনেরিক / ফর্মুলা (ইচ্ছাধীন)',
    'company_optional': 'কোম্পানির নাম (ইচ্ছাধীন)',
    'notes_optional': 'বিশেষ নির্দেশনা (ইচ্ছাধীন)',
    'dosage_builder': 'খাওয়ার সময় ও পরিমাণ',
    'add_dose_line': 'আরেকটি সময় যোগ করুন',
    'dose_line': 'ওষুধের সময়',
    'remove_dose_line': 'এই সময়টি বাদ দিন',
    'dosage': 'কতটুকু খাবেন',
    'dosage_value': 'পরিমাণ',
    'choose_reminder_time': 'ওষুধ খাওয়ার সময় বেছে নিন',
    'repeat_schedule': 'কত দিন পরপর খাবেন',
    'repeat_medicine': 'ওষুধটি কত দিন পরপর নিতে হবে',
    'daily': 'প্রতিদিন',
    'weekly': 'প্রতি সপ্তাহে',
    'every15Days': 'প্রতি ১৫ দিনে',
    'monthly': 'প্রতি মাসে',
    'custom': 'নিজের মতো দিনের ব্যবধান',
    'custom_repeat_days': 'কত দিন পরপর',
    'days': 'দিন',
    'schedule': 'খাওয়ার নিয়ম',
    'every_n_days': 'প্রতি',
    'meal_schedule': 'খাবারের সঙ্গে সময় মিলিয়ে নিন',
    'meal_schedule_enabled': 'খাবারের সময়ও মনে করিয়ে দিন',
    'meal_schedule_help':
        'প্রতিটি ওষুধের সময় থেকে খাবারের সময় নিজে থেকেই হিসাব হবে।',
    'meal_relation': 'খাবারের কতক্ষণ আগে বা পরে',
    'before_meal_30': 'খাবারের ৩০ মিনিট আগে',
    'before_meal_custom': 'খাবারের আগে',
    'at_meal': 'খাবারের সঙ্গে',
    'after_meal_30': 'খাবারের ৩০ মিনিট পরে',
    'after_meal_custom': 'খাবারের পরে',
    'custom_meal_minutes': 'কত মিনিটের ব্যবধান',
    'minutes_short': 'মিনিট',
    'calculated_meal_times': 'হিসাব করা খাবারের সময়',
    'medicine_at': 'ওষুধ',
    'meal_at': 'খাবার',
    'photo': 'ওষুধের ছবি',
    'medicine_photo_help':
        'ছবি দেওয়া বাধ্যতামূলক নয়। পরিষ্কার ছবি থাকলে ড্যাশবোর্ড ও অ্যান্ড্রয়েডের রিমাইন্ডার দেখে সঠিক ওষুধটি সহজে চিনতে পারবেন।',
    'photo_saved_locally': 'ছবিটি এই ডিভাইসে রাখা আছে',
    'no_photo_selected': 'কোনো ছবি যোগ করা হয়নি',
    'take_photo': 'ছবি তুলুন',
    'save_medicine': 'ওষুধটি সংরক্ষণ করুন',
    'update_medicine': 'তথ্য হালনাগাদ করুন',
    'medicine_name_required_error': 'ওষুধের নাম লিখুন।',
    'dose_line_required_error': 'অন্তত একটি সময় ও খাওয়ার পরিমাণ লিখুন।',
    'power_required_error': 'ওষুধের শক্তি লিখুন।',
    'duplicate_dose_time_error': 'প্রতিটি রিমাইন্ডারের সময় আলাদা হতে হবে।',
    'custom_days_error': '১ থেকে ৩৬৫ দিনের মধ্যে ব্যবধান দিন।',
    'meal_minutes_error': 'খাবারের সঙ্গে ১ থেকে ৭২০ মিনিটের ব্যবধান দিন।',
    'meal_timing_conflict_title': 'খাবারের সময়ে গরমিল আছে',
    'meal_timing_conflict_requested': 'এই সময় দিলে খাবারের সময় হবে',
    'meal_timing_conflict_existing': 'আগের ওষুধ অনুযায়ী খাবারের সময়',
    'meal_timing_conflict_fix': 'একই খাবারের সঙ্গে মিলাতে ওষুধের সময় দিন',
    'use_suggested_time': 'প্রস্তাবিত সময় নিন',
    'understood': 'বুঝেছি',
    'tablet': 'ট্যাবলেট',
    'capsule': 'ক্যাপসুল',
    'syrup': 'সিরাপ',
    'drop': 'ড্রপ',
    'insulin': 'ইনসুলিন',
    'pill': 'টি',
    'ml': 'মি.লি.',
    'drop_unit': 'ফোঁটা',
    'units': 'ইউনিট',
    'medicine_status': 'ওষুধ',
    'meal_status': 'খাবার',
    'status_taken': 'নিয়েছেন',
    'status_not_taken': 'নেননি',
    'status_pending': 'জানানো হয়নি',
    'mark_taken': 'নিয়েছি',
    'mark_not_taken': 'নিইনি',
    'when_taken': 'ওষুধটি কখন নিয়েছেন?',
    'taken_now': 'এইমাত্র নিয়েছি',
    'taken_with_food': 'খাবারের সঙ্গে নিয়েছি',
    'taken_later': 'অন্য সময়ে নিয়েছি',
    'choose_actual_time': 'ওষুধ নেওয়ার আসল সময় বেছে নিন',
    'also_with_food': 'খাবারের সঙ্গে নিয়েছিলেন?',
    'without_food': 'খাবার ছাড়া',
    'with_food': 'খাবারের সঙ্গে',
    'next': 'পরের সময়',
    'now': 'এখন',
    'dose_not_set': 'খাওয়ার পরিমাণ দেওয়া হয়নি',
    'auth_failed': 'প্রবেশ করা যায়নি। আবার চেষ্টা করুন।',
    'invalid_phone': 'সঠিক বাংলাদেশি মোবাইল নম্বর লিখুন।',
    'billing_required': 'আসল এসএমএস পাঠাতে Firebase billing চালু থাকতে হবে।',
    'phone_disabled': 'Firebase-এ ফোন দিয়ে প্রবেশ চালু নেই।',
    'region_blocked': 'বাংলাদেশে এসএমএস পাঠানোর অনুমতি Firebase-এ চালু নেই।',
    'unauthorized_domain': 'এই ওয়েব ঠিকানাটি Firebase-এ অনুমোদিত নয়।',
    'browser_verification_failed':
        'Firebase এই ব্রাউজারটি যাচাই করতে পারেনি। পেজ রিফ্রেশ করে আবার চেষ্টা করুন।',
    'too_many_requests': 'অনেকবার চেষ্টা করা হয়েছে। কিছুক্ষণ পর আবার কোড চান।',
    'quota_exceeded': 'Firebase-এর এসএমএস সীমা শেষ হয়েছে। পরে চেষ্টা করুন।',
    'invalid_code': 'যাচাই কোডটি সঠিক নয়।',
    'expired_code': 'যাচাই কোডের মেয়াদ শেষ। নতুন কোড নিন।',
  },
};
