class Category {
  const Category({
    required this.title,
    required this.subtitle,
    required this.emi,
  });

  final String title;
  final String subtitle;
  final String emi;
}

class CategorySection {
  const CategorySection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<Category> items;
}

class LockerSummary {
  const LockerSummary({
    required this.amountLabel,
    required this.nextDebitDate,
  });

  final String amountLabel;
  final String nextDebitDate;
}

























