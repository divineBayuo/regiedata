// source of truth for every plan-based feature limit
// user's firestore doc (`users/{uid}`) stores `plan`: 'free' | 'pro' | 'business'
class PlanLimits {
  // org/member caps
  static int maxOrganizations(String plan) {
    switch (plan) {
      case 'pro':
        return 5;
      case 'business':
        return 999999;
      default:
        return 1;
    }
  }

  static int maxMembers(String plan) {
    switch (plan) {
      case 'pro':
      case 'business':
        return 999999;
      default:
        return 30;
    }
  }

  // days of attendance history. -1 = unlimited
  static int historyDays(String plan) {
    switch (plan) {
      case 'pro':
      case 'business':
        return -1;
      default:
        return 30;
    }
  }

  // feature flags
  static bool canExportCSV(String plan) => plan == 'pro' || plan == 'business';
  static bool hasAdvancedAnalytics(String plan) =>
      plan == 'pro' || plan == 'business';
  static bool hasFinancialTracking(String plan) =>
      plan == 'pro' || plan == 'business';
  static bool hasCustomBranding(String plan) => plan == 'business';
  static bool hasAPIAccess(String plan) => plan == 'business';
  static bool hasPrioritySupport(String plan) =>
      plan == 'pro' || plan == 'business';

  // Display helpers
  static String planName(String plan) {
    switch (plan) {
      case 'pro':
        return 'Pro';
      case 'business':
        return 'Business';
      default:
        return 'Free';
    }
  }

  static String price(String plan) {
    switch (plan) {
      case 'pro':
        return r'GHS 50';
      case 'business':
        return r'GHS 100';
      default:
        return r'GHS 0';
    }
  }

  static List<String> features(String plan) {
    switch (plan) {
      case 'pro':
        return [
          'Up to 5 Organizations',
          'Unlimited Members',
          'Full Attendance History',
          'Advanced Analytics',
          'Financial Tracking',
          'CSV Export',
          'Priority Support',
        ];
      case 'business':
        return [
          'Unlimited Organizations',
          'Unlimited Members',
          'Full Analytics Suite',
          'Custom Branding',
          'Dedicated Support',
          'API Access',
          'Team Management',
        ];
      default:
        return [
          '1 Organization',
          'Up to 30 Members',
          'Unlimited Sessions',
          '30-Day Attendance History',
          'QR & PIN Check-in',
          'Basic Analytics',
        ];
    }
  }
}
