import '../../core/enums.dart';
import '../../l10n/generated/app_localizations.dart';

/// InfoSection.category → 在地化標籤（注意事項/小費/行李/住宿/安全/海關/防疫/導遊提醒）。
String infoCategoryLabel(AppLocalizations l10n, InfoCategory category) {
  return switch (category) {
    InfoCategory.notice => l10n.categoryNotice,
    InfoCategory.tipping => l10n.categoryTipping,
    InfoCategory.baggage => l10n.categoryBaggage,
    InfoCategory.hotel => l10n.categoryHotel,
    InfoCategory.safety => l10n.categorySafety,
    InfoCategory.customs => l10n.categoryCustoms,
    InfoCategory.health => l10n.categoryHealth,
    InfoCategory.guide => l10n.categoryGuide,
  };
}
