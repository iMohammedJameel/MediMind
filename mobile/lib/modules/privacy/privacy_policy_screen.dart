import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

/// In-app privacy policy (bilingual, no external link needed — a store
/// requirement). Content follows Egyptian PDPL (Law 151/2020) plus
/// GDPR-style rights for users in other jurisdictions.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = context.lang == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('privacy.title')),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.tr('privacy.updated'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ...isAr ? _arSections(context) : _enSections(context),
        ],
      ),
    );
  }

  List<Widget> _arSections(BuildContext context) => [
        _section(context, '١. من نحن',
            'MediMind تطبيق لمساعدة المرضى وكبار السن على الالتزام بمواعيد أدويتهم، ومشاركة الاطمئنان مع مقدمي الرعاية من أفراد الأسرة.'),
        _section(context, '٢. البيانات التي نجمعها',
            '• بيانات الحساب: الاسم، البريد الإلكتروني أو رقم الهاتف، كلمة مرور مشفّرة.\n'
                '• البيانات الصحية التي تُدخلها بنفسك: قائمة الأدوية، مواعيد الجرعات، سجل الالتزام.\n'
                '• بيانات تقنية: معرّف منطقتك الزمنية لضبط دقيق للمواعيد، ونوع الجهاز، وسجلات أخطاء مجهولة الهوية (يمكن إيقافها من الإعدادات).'),
        _section(context, '٣. لماذا نجمعها',
            '• تذكيرك بمواعيد جرعاتك في الوقت الصحيح على جهازك.\n'
                '• إشعار مقدم الرعاية المرتبط بك عند فوات جرعة (بعد سماح من الطرفين).\n'
                '• تنفيذ طلبات تجديد الأدوية من الصيدلية التي تختارها.\n'
                '• تحسين استقرار التطبيق عبر تقارير مجهولة المصدر.'),
        _section(context, '٤. من نشاركه معه',
            'لا نبيع بياناتك لأي طرف. تُشارك البيانات فقط مع:\n'
                '• مقدمي الرعاية الذين ربطتَهم بنفسك عبر دائرة الرعاية، وبنطاق الصلاحيات التي وافقت عليها.\n'
                '• الصيدلية التي تختارها عند طلب تجديد دواء، ويقتصر ما تراه على الدواء المطلوب فقط.\n'
                '• الجهات الرسمية عند وجود إلزام قانوني صريح.'),
        _section(context, '٥. كيف نحمي بياناتك',
            '• كلمات المرور مُشفّرة بمعايير الصناعة ولا يمكن لأي شخص — بمن فيهم فريقنا — قراءتها.\n'
                '• الاتصال بالخادم مشفّر (HTTPS) في بيئة التشغيل.\n'
                '• مفاتيح الجلسة محفوظة في مساحة تخزين آمنة على جهازك.\n'
                '• يوضع كل موظف تحت اتفاقية سرية صارمة تغطي البيانات الصحية.'),
        _section(context, '٦. مدة الاحتفاظ',
            'نحتفظ ببياناتك طوال استخدامك للتطبيق. عند حذف حسابك من الإعدادات تُحذف بياناتك الشخصية والصحية نهائيًا خلال ٣٠ يومًا كحد أقصى، باستثناء ما يُلزمنا القانون بالاحتفاظ به ضمن سجلات مالية أو تنظيمية.'),
        _section(context, '٧. حقوقك',
            'وفقًا لقانون حماية البيانات الشخصية المصري رقم ١٥١ لسنة ٢٠٢٠ (والمبادئ المماثلة في اللوائح الأوروبية GDPR عند انطباقها):\n'
                '• حق الاطلاع على بياناتك وتصديرها.\n'
                '• حق تصحيح بياناتك من شاشة الملف الشخصي في أي وقت.\n'
                '• حق سحب موافقتك على مشاركة مقدم الرعاية بفصل الارتباط من دائرة الرعاية.\n'
                '• حق حذف حسابك نهائيًا بنفسك من: الإعدادات ← حذف الحساب، بعد تأكيد كلمة المرور.'),
        _section(context, '٨. الأطفال',
            'التطبيق غير مخصص لمن هم دون ١٢ عامًا، ولا نجمع بياناتهم عن قصد.'),
        _section(context, '٩. التعديلات',
            'قد نحدّث هذه السياسة؛ سنخطرك داخل التطبيق قبل سريان أي تعديل جوهري، ويمكنك مراجعتها في أي وقت من شاشة الإعدادات.'),
        _section(context, '١٠. التواصل',
            'لأي استفسار متعلق بالخصوصية أو لطلب نسخة من بياناتك أو حذفها، استخدم خيار "حذف الحساب" داخل التطبيق أو تواصل مع الدعم عبر القنوات الرسمية المعلنة في صفحة التطبيق على المتجر.'),
      ];

  List<Widget> _enSections(BuildContext context) => [
        _section(context, '1. Who we are',
            'MediMind helps patients and the elderly adhere to their medication schedules and keeps family caregivers reassured.'),
        _section(context, '2. Data we collect',
            '• Account data: name, email or phone number, a cryptographically hashed password.\n'
                '• Health data you enter yourself: medication list, dose times, adherence history.\n'
                '• Technical data: your timezone identifier (for accurate scheduling), device type, and anonymous crash reports (switchable off in Settings).'),
        _section(context, '3. Why we collect it',
            '• Reminding you of dose times locally on your device.\n'
                '• Notifying a caregiver you linked, when a dose is missed (both sides consent).\n'
                '• Fulfilling refill requests at the pharmacy you choose.\n'
                '• Improving app stability through anonymized reports.'),
        _section(context, '4. Who we share with',
            'We never sell your data. Data is shared only with:\n'
                '• Caregivers you explicitly linked via the Care Circle, limited to the permissions you granted.\n'
                '• The pharmacy you pick for a refill — they only see the requested medication.\n'
                '• Authorities where an explicit legal obligation exists.'),
        _section(context, '5. How we protect your data',
            '• Passwords are industry-standard hashed — unreadable to anyone, including our team.\n'
                '• Encrypted transport (HTTPS) in production.\n'
                '• Session keys live in the device secure storage.\n'
                '• All staff are bound by strict confidentiality agreements covering health data.'),
        _section(context, '6. Retention',
            'We keep your data while you use the app. When you delete your account from Settings, your personal and health data is permanently erased within at most 30 days, except records the law requires us to retain (financial/regulatory).'),
        _section(context, '7. Your rights',
            'Under the Egyptian Personal Data Protection Law 151/2020 (and equivalent GDPR principles where applicable):\n'
                '• Right to access and export your data.\n'
                '• Right to correct your data anytime from the profile screen.\n'
                '• Right to withdraw caregiver-sharing consent by unlinking in the Care Circle.\n'
                '• Right to permanently delete your account yourself: Settings → Delete account, after password confirmation.'),
        _section(context, '8. Children',
            'The app is not intended for children under 12 and we do not knowingly collect their data.'),
        _section(context, '9. Changes',
            'We may update this policy; material changes are announced in-app before they take effect, and you can always review it from Settings.'),
        _section(context, '10. Contact',
            'For any privacy request (access, export, deletion), use in-app account deletion or contact support via the official channels listed on the store page.'),
      ];

  Widget _section(BuildContext context, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(body,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.7)),
          ],
        ),
      );
}
