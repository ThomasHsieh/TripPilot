import '../../core/enums.dart';
import '../../l10n/generated/app_localizations.dart';

/// ExpenseCategory → 在地化標籤（餐飲/交通/購物/門票/住宿/其他）。
String expenseCategoryLabel(AppLocalizations l10n, ExpenseCategory c) {
  return switch (c) {
    ExpenseCategory.food => l10n.expenseCatFood,
    ExpenseCategory.transport => l10n.expenseCatTransport,
    ExpenseCategory.shopping => l10n.expenseCatShopping,
    ExpenseCategory.ticket => l10n.expenseCatTicket,
    ExpenseCategory.lodging => l10n.expenseCatLodging,
    ExpenseCategory.other => l10n.expenseCatOther,
  };
}
