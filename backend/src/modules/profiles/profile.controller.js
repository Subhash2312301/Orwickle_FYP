// Reads the request, calls the profile service, sends the response.

const service = require('./profile.service');
const baseUrl = require('../../utils/baseUrl');

const context = req => ({ ip: req.ip, baseUrl: baseUrl(req) });

module.exports = {
  getMine: async (req, res) =>
    res.json(await service.getMyProfile(req.user.id, req.user.role, { baseUrl: baseUrl(req) })),
  updateMine: async (req, res) =>
    res.json(await service.updateMyProfile(req.user.id, req.user.role, req.body, context(req))),
  setAvatar: async (req, res) =>
    res.json(await service.setAvatar(req.user.id, req.user.role, req.image, context(req))),
  removeAvatar: async (req, res) =>
    res.json(await service.removeAvatar(req.user.id, req.user.role, context(req))),
  categories: async (req, res) => res.json(await service.listCategories()),
};
