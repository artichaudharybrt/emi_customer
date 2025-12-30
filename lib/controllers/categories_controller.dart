import '../models/category.dart';

class CategoriesController {
  const CategoriesController();

  List<String> getBrowseTabs() {
    return const [
      'All',
      'Phones & tablets',
      'Laptops & PCs',
      'TV & appliances',
      'Budget picks',
    ];
  }

  List<CategorySection> getSections() {
    return const [
      CategorySection(
        title: 'Popular right now',
        items: [
          Category(
            title: 'Smartphones',
            subtitle: '3,240 products · Top brands',
            emi: 'EMI from ₹899 / month',
          ),
          Category(
            title: 'Laptops & PCs',
            subtitle: '1,120 products · Study & work',
            emi: 'EMI from ₹1,499 / month',
          ),
          Category(
            title: 'Televisions',
            subtitle: '860 products · 4K Smart TVs',
            emi: 'EMI from ₹999 / month',
          ),
          Category(
            title: 'Washing machines',
            subtitle: '540 products · Front & top load',
            emi: 'EMI from ₹899 / month',
          ),
        ],
      ),
      CategorySection(
        title: 'Home & essentials',
        items: [
          Category(
            title: 'Refrigerators',
            subtitle: '330 products · Double & single door',
            emi: 'EMI from ₹1,299 / month',
          ),
          Category(
            title: 'Air conditioners',
            subtitle: '270 products · Split & window',
            emi: 'EMI from ₹1,799 / month',
          ),
          Category(
            title: 'Kitchen appliances',
            subtitle: '680 products · Mixers, ovens & more',
            emi: 'EMI from ₹399 / month',
          ),
        ],
      ),
      CategorySection(
        title: 'Work, study & play',
        items: [
          Category(
            title: 'Tablets & iPads',
            subtitle: '410 products · Work & binge',
            emi: 'EMI from ₹799 / month',
          ),
          Category(
            title: 'Audio & wearables',
            subtitle: '1,540 products · Earbuds, watches',
            emi: 'EMI from ₹199 / month',
          ),
          Category(
            title: 'Gaming & consoles',
            subtitle: '650 products · Consoles, accessories',
            emi: 'EMI from ₹1,299 / month',
          ),
        ],
      ),
    ];
  }

  LockerSummary getLockerSummary() {
    return const LockerSummary(
      amountLabel: 'Latest usage: ₹23,577 / month',
      nextDebitDate: 'First EMI on 05 Jan',
    );
  }
}

















