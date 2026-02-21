/**
 * File Validation Utility
 *
 * Provides magic number detection, filename sanitization, and per-type size limits
 * for secure document upload processing.
 *
 * Phase 04-01: Document Upload Security
 *
 * Uses file-type v16.x (last CommonJS-compatible version) for magic number detection.
 * v17+ is ESM-only and incompatible with this project's CommonJS setup.
 */

const FileType = require('file-type');
const path = require('path');

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/**
 * Whitelist of allowed file extensions for upload.
 * Only these types are accepted by the document processing pipeline.
 */
const ALLOWED_FILE_TYPES = ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'tiff', 'txt'];

/**
 * Maximum file size limits in bytes, keyed by extension.
 * The 'default' key is used for types not explicitly listed.
 */
const FILE_SIZE_LIMITS = {
  pdf: 20 * 1024 * 1024,     // 20 MB
  jpg: 10 * 1024 * 1024,     // 10 MB
  jpeg: 10 * 1024 * 1024,    // 10 MB
  png: 10 * 1024 * 1024,     // 10 MB
  heic: 10 * 1024 * 1024,    // 10 MB
  tiff: 10 * 1024 * 1024,    // 10 MB
  txt: 5 * 1024 * 1024,      // 5 MB
  default: 10 * 1024 * 1024  // 10 MB
};

// ---------------------------------------------------------------------------
// Extension-to-detected-type mapping
// ---------------------------------------------------------------------------

/**
 * Map of file extensions that file-type detects as a different extension name.
 * For example, file-type detects .jpeg files as 'jpg'.
 * This mapping allows claimed extensions to match detected types correctly.
 */
const EXTENSION_ALIASES = {
  jpeg: 'jpg'
};

// ---------------------------------------------------------------------------
// validateFileContent
// ---------------------------------------------------------------------------

/**
 * Validate file buffer content against the claimed file name.
 *
 * Performs the following checks in order:
 *   1. Buffer is non-empty
 *   2. File size is within the per-type limit
 *   3. Magic number detection via file-type
 *   4. Detected type matches claimed extension (if detectable)
 *   5. Detected type is in the allowed list
 *   6. For undetectable types (e.g. plain text), checks extension against allowed list
 *
 * @param {Buffer} buffer - The file content buffer
 * @param {string} claimedFileName - The original filename as provided by the uploader
 * @returns {Promise<Object>} Validation result:
 *   - { valid: true, detectedType: { ext, mime } } for verified files
 *   - { valid: true, detectedType: null, warning: '...' } for unverifiable but allowed files
 *   - { valid: false, error: '...' } for rejected files
 */
async function validateFileContent(buffer, claimedFileName) {
  // 1. Check for empty/missing buffer
  if (!buffer || !Buffer.isBuffer(buffer) || buffer.length === 0) {
    return { valid: false, error: 'Empty file content' };
  }

  // Extract claimed extension (lowercase, no dot)
  const claimedExt = path.extname(claimedFileName || '').toLowerCase().replace('.', '');

  // 2. Check file size against per-type limit
  const sizeLimit = FILE_SIZE_LIMITS[claimedExt] || FILE_SIZE_LIMITS.default;
  if (buffer.length > sizeLimit) {
    const limitMB = (sizeLimit / (1024 * 1024)).toFixed(0);
    return {
      valid: false,
      error: `File exceeds maximum size of ${limitMB}MB for type '${claimedExt || 'unknown'}'`
    };
  }

  // 3. Detect actual type from magic number
  const detected = await FileType.fromBuffer(buffer);

  // 4. If type was detected from magic number
  if (detected) {
    // Check if detected type is in the allowed list
    if (!ALLOWED_FILE_TYPES.includes(detected.ext)) {
      // The detected type itself is not allowed — but is the claimed extension allowed?
      // If neither is allowed, report "not allowed". If claimed is allowed but detected
      // is different, report "does not match".
      if (ALLOWED_FILE_TYPES.includes(claimedExt) || ALLOWED_FILE_TYPES.includes(EXTENSION_ALIASES[claimedExt])) {
        return { valid: false, error: 'File content does not match claimed type' };
      }
      return { valid: false, error: 'File type not allowed' };
    }

    // Check if detected type matches the claimed extension
    const normalizedClaimed = EXTENSION_ALIASES[claimedExt] || claimedExt;
    if (detected.ext !== normalizedClaimed) {
      return { valid: false, error: 'File content does not match claimed type' };
    }

    // All checks passed
    return {
      valid: true,
      detectedType: {
        ext: detected.ext,
        mime: detected.mime
      }
    };
  }

  // 5. Type could not be detected from magic number (e.g. plain text)
  // Fall back to checking the claimed extension against allowed list
  if (ALLOWED_FILE_TYPES.includes(claimedExt)) {
    return {
      valid: true,
      detectedType: null,
      warning: 'Could not verify file type from content'
    };
  }

  return { valid: false, error: 'File type not allowed' };
}

// ---------------------------------------------------------------------------
// sanitizeFileName
// ---------------------------------------------------------------------------

/**
 * Sanitize a file name to prevent path traversal, null byte injection,
 * and other filesystem attacks.
 *
 * Processing steps:
 *   1. Reject empty/null/undefined input
 *   2. Remove null bytes (\x00)
 *   3. Remove path separators and path traversal sequences
 *   4. Replace unsafe characters with underscores
 *   5. Truncate to 255 characters, preserving the file extension
 *
 * @param {string} fileName - The raw file name to sanitize
 * @returns {string} The sanitized file name
 * @throws {Error} If fileName is empty, null, or undefined
 */
function sanitizeFileName(fileName) {
  if (!fileName || typeof fileName !== 'string' || fileName.trim().length === 0) {
    throw new Error('File name is required');
  }

  let sanitized = fileName;

  // Remove null bytes
  sanitized = sanitized.replace(/\x00/g, '');

  // Remove path traversal sequences and separators
  sanitized = sanitized.replace(/\.\.\//g, '');
  sanitized = sanitized.replace(/\.\.\\/g, '');
  sanitized = sanitized.replace(/[/\\]/g, '');

  // Replace dots that are not part of the final extension
  // First, extract the extension if present
  const lastDotIndex = sanitized.lastIndexOf('.');
  let baseName, extension;

  if (lastDotIndex > 0) {
    baseName = sanitized.substring(0, lastDotIndex);
    extension = sanitized.substring(lastDotIndex); // includes the dot
  } else {
    baseName = sanitized;
    extension = '';
  }

  // Remove leading dots from base name (hidden file prevention)
  baseName = baseName.replace(/^\.+/, '');

  // Replace unsafe characters in the base name with underscores
  // Allow only alphanumeric, underscores, hyphens, and dots
  baseName = baseName.replace(/[^a-zA-Z0-9_\-\.]/g, '_');

  // Collapse consecutive underscores into a single underscore
  baseName = baseName.replace(/_+/g, '_');

  // Reassemble
  sanitized = baseName + extension;

  // Handle the case where sanitization results in empty string
  if (sanitized.length === 0 || sanitized === extension) {
    throw new Error('File name is required');
  }

  // Truncate to 255 characters, preserving extension
  const MAX_LENGTH = 255;
  if (sanitized.length > MAX_LENGTH) {
    if (extension) {
      const maxBaseLength = MAX_LENGTH - extension.length;
      sanitized = baseName.substring(0, maxBaseLength) + extension;
    } else {
      sanitized = sanitized.substring(0, MAX_LENGTH);
    }
  }

  return sanitized;
}

// ---------------------------------------------------------------------------
// Exports
// ---------------------------------------------------------------------------

module.exports = {
  validateFileContent,
  sanitizeFileName,
  ALLOWED_FILE_TYPES,
  FILE_SIZE_LIMITS
};
