/**
 * Joi validation middleware factory.
 *
 * Creates Express middleware that validates req[source] against a Joi schema.
 * Returns 400 with { error, message } on failure; replaces req[source] with
 * the validated (and coerced) value on success.
 *
 * @param {import('joi').ObjectSchema} schema - Joi schema to validate against
 * @param {'body'|'query'|'params'} [source='body'] - Request property to validate
 * @returns {import('express').RequestHandler} Express middleware
 */
function validate(schema, source = 'body') {
  return (req, res, next) => {
    const { error, value } = schema.validate(req[source], {
      abortEarly: false,
      stripUnknown: true
    });

    if (error) {
      const message = error.details.map(d => d.message).join(', ');
      return res.status(400).json({
        error: 'Bad Request',
        message
      });
    }

    req[source] = value;
    next();
  };
}

module.exports = { validate };
