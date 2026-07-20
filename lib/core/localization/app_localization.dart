import 'package:flutter/material.dart';

class AppLanguageController extends ValueNotifier<Locale> {
  AppLanguageController() : super(const Locale('en'));

  void toggle() {
    value = value.languageCode == 'en'
        ? const Locale('bn')
        : const Locale('en');
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
    final controller = AppLanguageScope.controllerOf(this);
    final languageCode = controller.languageCode;
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
    final isEnglish = controller.languageCode == 'en';
    return TextButton(
      onPressed: controller.toggle,
      child: Text(
        isEnglish ? 'বাংলা' : 'EN',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

const Map<String, Map<String, String>> _localizedValues = {
  'en': {
    'app_name': 'MediMind',
    'tagline': 'Simple, clear medicine reminders for families.',
    'sign_in': 'Sign in',
    'sign_up': 'Sign up',
    'email_address': 'Email address',
    'password': 'Password',
    'sign_in_with_email': 'Sign in with email and password',
    'other_sign_in_options': 'Other sign-in options',
    'phone_number': 'Phone number',
    'phone_sign_in_subtitle': 'One-time code for quick access',
    'google_account': 'Google account',
    'google_sign_in_subtitle': 'Continue with your Google account',
    'create_account': 'Create account',
    'full_name': 'Full name',
    'create_your_account': 'Create your account',
    'phone_sign_in': 'Phone Sign In',
    'verification_code': 'Verification code',
    'send_code': 'Send code',
    'verify_and_sign_in': 'Verify and sign in',
    'request_code_first': 'Request the verification code first.',
    'verification_sent': 'Verification code sent.',
    'google_sign_in': 'Google Sign In',
    'continue_google': 'Continue with Google',
    'continue_google_subtitle': 'Continue with your Google account.',
    'dashboard_today': "Today's Medicines",
    'dashboard_active': 'Active',
    'dashboard_next_in': 'Next in',
    'dashboard_items': 'items',
    'add_medicine': 'Add Medicine',
    'backup': 'Backup',
    'backup_complete': 'Backup complete.',
    'no_active_medicines': 'No active medicines',
    'next_medicine': 'Next medicine',
    'add_first_reminder': 'Add a medicine reminder',
    'create_first_reminder_hint':
        'Create your first reminder to start notifications.',
    'due_in': 'Due in',
    'refresh_from_cloud': 'Refresh from cloud',
    'sign_out': 'Sign out',
    'no_medicine_saved': 'No medicines saved yet',
    'empty_medicine_hint':
        'Add a medicine once and the app will remind and back it up automatically.',
    'edit': 'Edit',
    'delete': 'Delete',
    'dose': 'Dose',
    'duration_days': 'Duration',
    'time': 'Time',
    'formula': 'Formula',
    'company': 'Company',
    'notes': 'Notes',
    'edit_medicine': 'Edit Medicine',
    'create_medicine_reminder': 'Create a medicine reminder',
    'update_medicine_details': 'Update medicine details',
    'form_hint':
        'Keep the form simple, but let each dose be entered as a clear structured line.',
    'medicine_details': 'Medicine details',
    'medicine_name_required': 'Medicine name *',
    'formula_optional': 'Formula (optional)',
    'company_optional': 'Company name (optional)',
    'notes_optional': 'Notes (optional)',
    'dosage_builder': 'Dosage builder',
    'add_dose_line': 'Add dose line',
    'preview': 'Preview',
    'dose_preview_placeholder': 'Dose summary will appear here.',
    'schedule_photo': 'Schedule & photo',
    'pick_reminder_time': 'Pick medicine reminder time',
    'reminder_time': 'Reminder time',
    'meal_offset': 'Meal offset',
    'before_meal_30': '30 min before meal',
    'at_meal': 'At meal time',
    'after_meal_30': '30 min after meal',
    'photo': 'Photo',
    'photo_saved_locally': 'Photo saved locally',
    'no_photo_selected': 'No photo selected',
    'take_photo': 'Take photo',
    'active_reminder': 'Active reminder',
    'active_reminder_subtitle': 'Keep this medicine scheduled and notified',
    'save_medicine': 'Save Medicine',
    'update_medicine': 'Update Medicine',
    'medicine_name_required_error': 'Please enter the medicine name.',
    'dose_line_required_error': 'Please add at least one dose line.',
    'dose_line': 'Dose line',
    'amount': 'Amount',
    'unit': 'Unit',
    'when': 'When',
    'frequency': 'Frequency',
    'remove_dose_line': 'Remove dose line',
    'next': 'Next',
    'paused': 'Paused',
    'dhaka': 'Dhaka, Bangladesh',
  },
  'bn': {
    'app_name': 'মেডিমাইন্ড',
    'tagline': 'পরিবারের ওষুধ মনে রাখার সহজ ও পরিষ্কার সমাধান।',
    'sign_in': 'সাইন ইন',
    'sign_up': 'সাইন আপ',
    'email_address': 'ইমেইল ঠিকানা',
    'password': 'পাসওয়ার্ড',
    'sign_in_with_email': 'ইমেইল ও পাসওয়ার্ড দিয়ে সাইন ইন',
    'other_sign_in_options': 'অন্যান্য সাইন-ইন অপশন',
    'phone_number': 'ফোন নম্বর',
    'phone_sign_in_subtitle': 'দ্রুত প্রবেশের জন্য একবারের কোড',
    'google_account': 'গুগল অ্যাকাউন্ট',
    'google_sign_in_subtitle': 'গুগল অ্যাকাউন্ট দিয়ে চালিয়ে যান',
    'create_account': 'অ্যাকাউন্ট তৈরি',
    'full_name': 'পূর্ণ নাম',
    'create_your_account': 'আপনার অ্যাকাউন্ট তৈরি করুন',
    'phone_sign_in': 'ফোন সাইন ইন',
    'verification_code': 'ভেরিফিকেশন কোড',
    'send_code': 'কোড পাঠান',
    'verify_and_sign_in': 'ভেরিফাই করে সাইন ইন',
    'request_code_first': 'আগে ভেরিফিকেশন কোড অনুরোধ করুন।',
    'verification_sent': 'ভেরিফিকেশন কোড পাঠানো হয়েছে।',
    'google_sign_in': 'গুগল সাইন ইন',
    'continue_google': 'গুগল দিয়ে চালিয়ে যান',
    'continue_google_subtitle': 'আপনার গুগল অ্যাকাউন্ট দিয়ে চালিয়ে যান।',
    'dashboard_today': 'আজকের ওষুধ',
    'dashboard_active': 'চালু',
    'dashboard_next_in': 'পরের ডোজ',
    'dashboard_items': 'টি',
    'add_medicine': 'ওষুধ যোগ করুন',
    'backup': 'ব্যাকআপ',
    'backup_complete': 'ব্যাকআপ সম্পন্ন হয়েছে।',
    'no_active_medicines': 'কোনো সক্রিয় ওষুধ নেই',
    'next_medicine': 'পরের ওষুধ',
    'add_first_reminder': 'একটি ওষুধ রিমাইন্ডার যোগ করুন',
    'create_first_reminder_hint':
        'প্রথম রিমাইন্ডার তৈরি করুন, নোটিফিকেশন চালু হবে।',
    'due_in': 'বাকি',
    'refresh_from_cloud': 'ক্লাউড থেকে রিফ্রেশ',
    'sign_out': 'সাইন আউট',
    'no_medicine_saved': 'এখনও কোনো ওষুধ সংরক্ষণ করা হয়নি',
    'empty_medicine_hint':
        'একবার ওষুধ যোগ করলে অ্যাপ মনে করাবে এবং স্বয়ংক্রিয়ভাবে ব্যাকআপ করবে।',
    'edit': 'এডিট',
    'delete': 'ডিলিট',
    'dose': 'ডোজ',
    'duration_days': 'মেয়াদ',
    'time': 'সময়',
    'formula': 'ফর্মুলা',
    'company': 'কোম্পানি',
    'notes': 'নোট',
    'edit_medicine': 'ওষুধ সম্পাদনা',
    'create_medicine_reminder': 'ওষুধ রিমাইন্ডার তৈরি করুন',
    'update_medicine_details': 'ওষুধের তথ্য আপডেট করুন',
    'form_hint':
        'ফর্ম সহজ রাখুন, তবে প্রতিটি ডোজ আলাদা লাইনে পরিষ্কারভাবে লিখুন।',
    'medicine_details': 'ওষুধের তথ্য',
    'medicine_name_required': 'ওষুধের নাম *',
    'formula_optional': 'ফর্মুলা (ঐচ্ছিক)',
    'company_optional': 'কোম্পানির নাম (ঐচ্ছিক)',
    'notes_optional': 'নোট (ঐচ্ছিক)',
    'dosage_builder': 'ডোজ বিল্ডার',
    'add_dose_line': 'ডোজ লাইন যোগ করুন',
    'preview': 'প্রিভিউ',
    'dose_preview_placeholder': 'ডোজ সারাংশ এখানে দেখাবে।',
    'schedule_photo': 'সময়সূচি ও ছবি',
    'pick_reminder_time': 'রিমাইন্ডার সময় বাছাই',
    'reminder_time': 'রিমাইন্ডার সময়',
    'meal_offset': 'খাবারের সময়ের সাথে ব্যবধান',
    'before_meal_30': 'খাবারের ৩০ মিনিট আগে',
    'at_meal': 'খাবারের সময়',
    'after_meal_30': 'খাবারের ৩০ মিনিট পরে',
    'photo': 'ছবি',
    'photo_saved_locally': 'ছবি লোকাল ডিভাইসে সংরক্ষিত',
    'no_photo_selected': 'কোনো ছবি নির্বাচন করা হয়নি',
    'take_photo': 'ছবি তুলুন',
    'active_reminder': 'চালু রিমাইন্ডার',
    'active_reminder_subtitle': 'এই ওষুধের সময়সূচি ও নোটিফিকেশন চালু রাখুন',
    'save_medicine': 'ওষুধ সংরক্ষণ',
    'update_medicine': 'ওষুধ আপডেট',
    'medicine_name_required_error': 'দয়া করে ওষুধের নাম লিখুন।',
    'dose_line_required_error': 'অন্তত একটি ডোজ লাইন যোগ করুন।',
    'dose_line': 'ডোজ লাইন',
    'amount': 'পরিমাণ',
    'unit': 'একক',
    'when': 'কখন',
    'frequency': 'বারংবারতা',
    'remove_dose_line': 'ডোজ লাইন মুছুন',
    'next': 'পরবর্তী',
    'paused': 'বন্ধ',
    'dhaka': 'ঢাকা, বাংলাদেশ',
  },
};
