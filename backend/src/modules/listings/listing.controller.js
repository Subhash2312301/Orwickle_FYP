// Reads the request, calls the listing service, sends the response.

const service = require('./listing.service');
const baseUrl = require('../../utils/baseUrl');

const context = req => ({ ip: req.ip, baseUrl: baseUrl(req) });
const owner = req => req.user.id;

module.exports = {
  create: async (req, res) => res.status(201).json(await service.createListing(owner(req), req.body, context(req))),
  mine: async (req, res) => res.json(await service.listMine(owner(req), baseUrl(req))),
  get: async (req, res) => res.json(await service.getListing(req.params.id, req.user, baseUrl(req))),
  update: async (req, res) => res.json(await service.updateListing(req.params.id, owner(req), req.body, context(req))),
  publish: async (req, res) => res.json(await service.changeStatus(req.params.id, owner(req), 'publish', context(req))),
  unpublish: async (req, res) =>
    res.json(await service.changeStatus(req.params.id, owner(req), 'unpublish', context(req))),
  close: async (req, res) => res.json(await service.changeStatus(req.params.id, owner(req), 'close', context(req))),
  remove: async (req, res) => {
    await service.deleteListing(req.params.id, owner(req), context(req));
    res.status(204).end();
  },
  setCover: async (req, res) => res.json(await service.setCover(req.params.id, owner(req), req.image, context(req))),
  removeCover: async (req, res) => res.json(await service.removeCover(req.params.id, owner(req), context(req))),
};
