import 'package:timeago/timeago.dart' as timeago;

bool _configured = false;

void configureRelativeTimeLocales() {
  if (_configured) {
    return;
  }

  timeago.setLocaleMessages('ar', timeago.ArMessages());
  timeago.setLocaleMessages('ar_short', timeago.ArShortMessages());
  timeago.setLocaleMessages('en', timeago.EnMessages());
  timeago.setDefaultLocale('ar');
  _configured = true;
}

String formatRelativeTime(DateTime value, {String locale = 'ar'}) {
  configureRelativeTimeLocales();
  final normalized = value.isUtc ? value.toLocal() : value;
  return timeago.format(normalized, locale: locale, allowFromNow: true);
}

String formatRelativeTimeFromString(
  String raw, {
  String locale = 'ar',
  String fallback = '',
}) {
  final value = raw.trim();
  if (value.isEmpty) {
    return fallback;
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return fallback.isEmpty ? value : fallback;
  }

  return formatRelativeTime(parsed, locale: locale);
}
