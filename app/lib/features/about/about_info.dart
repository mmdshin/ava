/// Everything shown on the About page, in one place so it is easy to
/// update without touching layout code.
abstract final class AboutInfo {
  static const appName = 'آوا – دستیار پرستاری';

  /// Must match pubspec.yaml's `version:` (without the `+build` part).
  static const appVersion = '1.0.0';

  static const disclaimer =
      'آوا یک ابزار آموزشی و کمک‌تصمیم است و جایگزین قضاوت بالینی، '
      'دستورات پزشک و پروتکل‌های مرکز درمانی نیست. برنامه‌های مراقبتی '
      'پیشنهادی باید با توجه به شرایط هر بیمار بازبینی شوند و مسئولیت '
      'تصمیم‌های مراقبتی بر عهده کادر درمان است.';

  static const purpose =
      'آوا یک دستیار آموزشی و بالینی برای پرستاران و دانشجویان پرستاری '
      'است که با هدف تسهیل دسترسی به تشخیص‌های پرستاری، برنامه‌های '
      'مراقبتی و آموزش زبان استاندارد پرستاری طراحی شده است.';

  /// The university the app was developed at (shown with its logo).
  static const university = 'دانشگاه علوم پزشکی مشهد';
  static const universityEnglish = 'Mashhad University of Medical Sciences';
  static const faculty = 'دانشکده پرستاری و مامایی';
  static const universityWebsite = 'https://mums.ac.ir';

  static const research =
      'آوا در قالب یک طرح پژوهشی مصوب دانشگاه علوم پزشکی مشهد '
      'توسعه داده شده است.';

  static const projectCode = '4040599';
  static const trialCode = 'IRCT20250926067364N1';

  /// Sources the care plans and assessment are based on. The section is
  /// hidden while this list is empty.
  static const references = <String>[];

  /// Contact e-mail for feedback. The row is hidden while empty.
  static const contactEmail = '';
}
