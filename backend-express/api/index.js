// Serverless function handler for Vercel
const app = require('../server');

// Export a serverless function handler
module.exports = async (req, res) => {
  return app(req, res);
};
