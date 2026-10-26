enum AcquisitionSource {
  colleagues('COLLEAGUE', 'همکاران'),
  ai('AI', 'هوش‌مصنوعی'),
  advertising('ADVERTISING', 'تبلیغات'),
  search('SEARCH', 'جستجو در اینترنت'),
  marketplace('MARKETPLACE', 'مارکت‌های آنلاین'),
  other('OTHER', 'سایر');

  final String code, label;
  const AcquisitionSource(this.code, this.label);
}
