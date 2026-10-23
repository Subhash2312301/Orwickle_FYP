// Reads the request, calls the profile service, sends the response.

const service = require('./profile.service');

module.exports = {
  getMine: async (req, res) => res.json(await service.getMyProfile(req.user.id, req.user.role)),
  updateMine: async (req, res) =>
    res.json(await service.updateMyProfile(req.user.id, req.user.role, req.body, { ip: req.ip })),
  categories: async (req, res) => res.json(await service.listCategories()),
};
