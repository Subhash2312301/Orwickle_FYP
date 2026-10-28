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
  static const home = '/home';
  static const changePassword = '/change-password';
  static const profileSetup = '/profile/setup'; // forced until the first profile is saved
  static const profileEdit = '/profile/edit';
  static const myListings = '/listings/mine';
  static const newListing = '/listings/new';
  static String listing(String id) => '/listings/$id';
  static String editListing(String id) => '/listings/$id/edit';

  /// Pages a logged-out user may open.
  static const public = {welcome, register, verifyEmail, login, forgotPassword, resetPassword, systemCheck};
}
