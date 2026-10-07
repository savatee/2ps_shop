import 'package:flutter/widgets.dart';

import '../features/admin/admin_dashboard_screen.dart';
import '../features/buyer/buyer_main_page.dart';
import '../features/login/login_user_model.dart';
import '../features/seller/seller_home_screen.dart';

class AppRouter {
  const AppRouter._();

  static Widget screenForUser(LoginUserModel user) {
    switch (user.role.trim().toLowerCase()) {
      case 'admin':
        return const AdminDashboardScreen();
      case 'seller':
        return SellerHomeScreen(
          user: {
            'user_id': user.userId,
            'name': user.name,
            'email': user.email,
            'user_phone': user.userPhone,
            'role': user.role,
          },
        );
      default:
        return BuyerMainPage(userId: user.userId);
    }
  }
}
