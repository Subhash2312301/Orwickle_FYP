// Reads the request, calls the auth service, sends the response.

const service = require('./auth.service');

const context = req => ({ userAgent: req.get('user-agent'), ip: req.ip });

module.exports = {
  register: async (req, res) => res.status(201).json(await service.register(req.body, context(req))),
  verifyEmail: async (req, res) => res.json(await service.verifyEmail(req.body, context(req))),
  resendOtp: async (req, res) => res.json(await service.sendOtpAgain(req.body)),
  login: async (req, res) => res.json(await service.login(req.body, context(req))),
  refresh: async (req, res) => res.json(await service.refresh(req.body, context(req))),
  logout: async (req, res) => {
    await service.logout(req.body, context(req));
    res.status(204).end();
  },
  forgotPassword: async (req, res) => res.json(await service.forgotPassword(req.body)),
  resetPassword: async (req, res) => res.json(await service.resetPassword(req.body, context(req))),
  changePassword: async (req, res) =>
    res.json(await service.changePassword(req.user.id, req.body, context(req))),
  me: async (req, res) => res.json(await service.getMe(req.user.id)),
};
