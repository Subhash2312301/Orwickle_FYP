// Reads the request, calls the auth service, sends the response.

const service = require('./auth.service');

const context = req => ({ userAgent: req.get('user-agent') });

module.exports = {
  register: async (req, res) => res.status(201).json(await service.register(req.body)),
  verifyEmail: async (req, res) => res.json(await service.verifyEmail(req.body, context(req))),
  resendOtp: async (req, res) => res.json(await service.sendOtpAgain(req.body)),
  login: async (req, res) => res.json(await service.login(req.body, context(req))),
  refresh: async (req, res) => res.json(await service.refresh(req.body, context(req))),
  logout: async (req, res) => {
    await service.logout(req.body);
    res.status(204).end();
  },
  forgotPassword: async (req, res) => res.json(await service.forgotPassword(req.body)),
  resetPassword: async (req, res) => res.json(await service.resetPassword(req.body)),
  me: async (req, res) => res.json(await service.getMe(req.user.id)),
};
