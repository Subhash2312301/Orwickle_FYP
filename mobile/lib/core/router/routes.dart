/// Route paths, in one place so screens never hard-code strings.
class Routes {
  const Routes._();

  static const splash = '/splash';
  static const welcome = '/welcome';
  static const register = '/register';          // ?role=owner|investor|buyer
  static const verifyEmail = '/verify-email';   // ?email=
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password'; // ?email=
  static const systemCheck = '/system-check';
  static const home = '/home';
  static const changePassword = '/change-password';

  /// Pages a logged-out user may open.
  static const public = {welcome, register, verifyEmail, login, forgotPassword, resetPassword, systemCheck};
}
