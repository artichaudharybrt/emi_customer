import '../models/locker_models.dart';

class LockerController {
  const LockerController();

  List<LockerItem> getLockerItems() {
    return const [
      LockerItem(
        name: 'Samsung Galaxy S24 5G (128 GB)',
        badge: 'Safe pick · Best for 18 months',
        price: '₹72,999',
        monthly: '₹3,899 / month · 18m',
        tenures: ['18m', '12m', '24m'],
      ),
      LockerItem(
        name: 'Dell Inspiron 15" i5, 16 GB, 512 GB SSD',
        badge: 'Work essential · Zero-cost processing',
        price: '₹58,499',
        monthly: '₹4,299 / month · 15m',
        tenures: ['9m', '15m', '21m'],
      ),
      LockerItem(
        name: 'Sony 55" 4K Google TV',
        badge: 'Living room upgrade · Recommended 24 months',
        price: '₹69,990',
        monthly: '₹5,899 / month · 24m',
        tenures: ['12m', '18m', '24m'],
      ),
    ];
  }
}























