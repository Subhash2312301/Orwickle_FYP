// The address the client used to reach this server, e.g. http://10.0.2.2:4000 from the Android emulator.
// Used to build links to locally stored files.
module.exports = req => `${req.protocol}://${req.get('host')}`;
