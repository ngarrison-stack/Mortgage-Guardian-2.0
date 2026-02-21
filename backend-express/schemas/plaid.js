const Joi = require('joi');

/**
 * Schema for POST /v1/plaid/link_token
 * Create Plaid Link token for bank connection.
 */
const linkTokenSchema = Joi.object({
  user_id: Joi.string().trim().max(255).required(),
  client_name: Joi.string().trim().optional(),
  redirect_uri: Joi.string().trim().uri().optional(),
  access_token: Joi.string().trim().optional(),
  products: Joi.array().items(Joi.string()).optional()
});

/**
 * Schema for POST /v1/plaid/exchange_token
 * Exchange public token for access token.
 */
const exchangeTokenSchema = Joi.object({
  public_token: Joi.string().trim().pattern(/^public-/).message('Invalid public token format').required(),
  user_id: Joi.string().trim().optional(),
  institution_id: Joi.string().trim().optional()
});

/**
 * Schema for POST /v1/plaid/accounts
 * Get account information.
 */
const accountsSchema = Joi.object({
  access_token: Joi.string().trim().pattern(/^access[-_]/).message('Invalid access token format').required(),
  account_ids: Joi.array().items(Joi.string()).optional()
});

/**
 * Schema for POST /v1/plaid/transactions
 * Get transaction history with pagination.
 */
const transactionsSchema = Joi.object({
  access_token: Joi.string().trim().pattern(/^access[-_]/).message('Invalid access token format').required(),
  start_date: Joi.string().pattern(/^\d{4}-\d{2}-\d{2}$/).message('Dates must be in YYYY-MM-DD format').required(),
  end_date: Joi.string().pattern(/^\d{4}-\d{2}-\d{2}$/).message('Dates must be in YYYY-MM-DD format').required(),
  account_ids: Joi.array().items(Joi.string()).optional(),
  count: Joi.number().integer().min(1).max(500).default(100),
  offset: Joi.number().integer().min(0).default(0)
});

/**
 * Schema for POST /v1/plaid/item
 * Get item (bank connection) information.
 */
const itemSchema = Joi.object({
  access_token: Joi.string().trim().pattern(/^access[-_]/).message('Invalid access token format').required()
});

/**
 * Schema for POST /v1/plaid/item/webhook
 * Update webhook URL for an item.
 */
const updateWebhookSchema = Joi.object({
  access_token: Joi.string().trim().pattern(/^access[-_]/).message('Invalid access token format').required(),
  webhook: Joi.string().trim().uri().required()
});

/**
 * Schema for DELETE /v1/plaid/item
 * Remove (delete) an item and revoke access.
 */
const deleteItemSchema = Joi.object({
  access_token: Joi.string().trim().pattern(/^access[-_]/).message('Invalid access token format').required()
});

/**
 * Schema for POST /v1/plaid/sandbox_public_token
 * Create sandbox public token (for testing only).
 */
const sandboxTokenSchema = Joi.object({
  institution_id: Joi.string().trim().optional(),
  initial_products: Joi.array().items(Joi.string()).optional()
});

module.exports = {
  linkTokenSchema,
  exchangeTokenSchema,
  accountsSchema,
  transactionsSchema,
  itemSchema,
  updateWebhookSchema,
  deleteItemSchema,
  sandboxTokenSchema
};
