/// Route paths, in one place so screens never hard-code strings.
class Routes {
  const Routes._();

  static const splash = '/splash';
  static const onboarding = '/onboarding'; // intro slides, first start only
  static const welcome = '/welcome';
  static const register = '/register'; // ?role=owner|investor|buyer
  static const verifyEmail = '/verify-email'; // ?email=
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password'; // ?email=
  static const systemCheck = '/system-check';
  static const designSystem = '/design-system'; // developer only: component gallery

  // tabs (one router branch each; which ones a user sees depends on the role)
  static const home = '/home'; // everyone: owners see their listings summary, others their account status
  static const myListings = '/listings/mine'; // owner
  static const profile = '/profile';

  static const settings = '/settings';
  static const changePassword = '/change-password';
  static const profileSetup = '/profile/setup'; // forced until the first profile is saved
  static const profileEdit = '/profile/edit';
  static const newListing = '/listings/new';
  static String listing(String id) => '/listings/$id';
  static String editListing(String id) => '/listings/$id/edit';

  /// Pages a logged-out user may open.
  static const public = {welcome, register, verifyEmail, login, forgotPassword, resetPassword, systemCheck};

  /// The first tab for a role. Admins work in the web dashboard, so the app only shows their profile.
  static String homeFor(String? role) => role == 'admin' ? profile : home;

  /// Pages only some roles may open; anything else is shared.
  static bool allowedFor(String location, String? role) {
    final ownerOnly = location.startsWith(myListings) || location == newListing;
    if (ownerOnly) return role == 'owner';
    if (location == home) return role != 'admin';
    if (location.endsWith('/edit') && location.startsWith('/listings/')) return role == 'owner';
    return true;
  }
}
