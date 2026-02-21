/**
 * File Validation Utility Tests
 *
 * Tests for magic number detection, filename sanitization, and per-type size limits.
 * Part of Phase 04-01: Document Upload Security.
 *
 * Covers:
 *   - validateFileContent(buffer, claimedFileName) — magic number validation
 *   - sanitizeFileName(fileName) — path traversal & special char removal
 *   - ALLOWED_FILE_TYPES — whitelist of permitted extensions
 *   - FILE_SIZE_LIMITS — per-type maximum sizes
 */

const {
  validateFileContent,
  sanitizeFileName,
  ALLOWED_FILE_TYPES,
  FILE_SIZE_LIMITS
} = require('../../utils/fileValidation');

// ---------------------------------------------------------------------------
// Helper: create buffers with specific magic numbers
// ---------------------------------------------------------------------------

/**
 * Create a minimal PDF buffer.
 * PDF magic number: %PDF (0x25 0x50 0x44 0x46)
 */
function createPDFBuffer(sizeBytes = 1024) {
  const buf = Buffer.alloc(sizeBytes);
  buf.write('%PDF-1.4', 0, 'ascii');
  return buf;
}

/**
 * Create a minimal JPEG buffer.
 * JPEG magic number: FF D8 FF
 */
function createJPEGBuffer(sizeBytes = 1024) {
  const buf = Buffer.alloc(sizeBytes);
  buf[0] = 0xFF;
  buf[1] = 0xD8;
  buf[2] = 0xFF;
  buf[3] = 0xE0; // JFIF marker
  return buf;
}

/**
 * Create a minimal PNG buffer.
 * PNG magic number: 89 50 4E 47 0D 0A 1A 0A
 */
function createPNGBuffer(sizeBytes = 1024) {
  const buf = Buffer.alloc(sizeBytes);
  const magic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (let i = 0; i < magic.length; i++) {
    buf[i] = magic[i];
  }
  return buf;
}

/**
 * Create a minimal EXE (PE) buffer.
 * PE magic number: 4D 5A (MZ header)
 */
function createEXEBuffer(sizeBytes = 1024) {
  const buf = Buffer.alloc(sizeBytes);
  buf[0] = 0x4D; // M
  buf[1] = 0x5A; // Z
  return buf;
}

/**
 * Create a minimal ZIP buffer.
 * ZIP magic number: 50 4B 03 04
 */
function createZIPBuffer(sizeBytes = 1024) {
  const buf = Buffer.alloc(sizeBytes);
  buf[0] = 0x50; // P
  buf[1] = 0x4B; // K
  buf[2] = 0x03;
  buf[3] = 0x04;
  return buf;
}

/**
 * Create a plain text buffer (no recognizable magic number).
 */
function createTextBuffer(content = 'Hello, this is plain text content.') {
  return Buffer.from(content, 'utf-8');
}

// ===========================================================================
// validateFileContent
// ===========================================================================

describe('validateFileContent', () => {
  // ---- Valid file types with matching magic numbers ----

  describe('valid files with matching magic numbers', () => {
    it('should accept PDF buffer with .pdf extension', async () => {
      const buffer = createPDFBuffer();
      const result = await validateFileContent(buffer, 'test.pdf');

      expect(result.valid).toBe(true);
      expect(result.detectedType).toBeDefined();
      expect(result.detectedType.ext).toBe('pdf');
      expect(result.detectedType.mime).toBe('application/pdf');
    });

    it('should accept JPEG buffer with .jpg extension', async () => {
      const buffer = createJPEGBuffer();
      const result = await validateFileContent(buffer, 'photo.jpg');

      expect(result.valid).toBe(true);
      expect(result.detectedType).toBeDefined();
      expect(result.detectedType.ext).toBe('jpg');
      expect(result.detectedType.mime).toBe('image/jpeg');
    });

    it('should accept JPEG buffer with .jpeg extension', async () => {
      const buffer = createJPEGBuffer();
      const result = await validateFileContent(buffer, 'photo.jpeg');

      expect(result.valid).toBe(true);
      expect(result.detectedType).toBeDefined();
      expect(result.detectedType.ext).toBe('jpg');
      expect(result.detectedType.mime).toBe('image/jpeg');
    });

    it('should accept PNG buffer with .png extension', async () => {
      const buffer = createPNGBuffer();
      const result = await validateFileContent(buffer, 'scan.png');

      expect(result.valid).toBe(true);
      expect(result.detectedType).toBeDefined();
      expect(result.detectedType.ext).toBe('png');
      expect(result.detectedType.mime).toBe('image/png');
    });
  });

  // ---- Disguised files (content doesn't match extension) ----

  describe('disguised files — content does not match claimed type', () => {
    it('should reject EXE buffer disguised as .pdf', async () => {
      const buffer = createEXEBuffer();
      const result = await validateFileContent(buffer, 'document.pdf');

      expect(result.valid).toBe(false);
      expect(result.error).toBe('File content does not match claimed type');
    });

    it('should reject ZIP buffer disguised as .jpg', async () => {
      const buffer = createZIPBuffer();
      const result = await validateFileContent(buffer, 'photo.jpg');

      expect(result.valid).toBe(false);
      expect(result.error).toBe('File content does not match claimed type');
    });

    it('should reject EXE buffer disguised as .png', async () => {
      const buffer = createEXEBuffer();
      const result = await validateFileContent(buffer, 'image.png');

      expect(result.valid).toBe(false);
      expect(result.error).toBe('File content does not match claimed type');
    });
  });

  // ---- Disallowed file types ----

  describe('disallowed file types', () => {
    it('should reject ZIP buffer even with .zip extension', async () => {
      const buffer = createZIPBuffer();
      const result = await validateFileContent(buffer, 'archive.zip');

      expect(result.valid).toBe(false);
      expect(result.error).toBe('File type not allowed');
    });

    it('should reject EXE buffer with .exe extension', async () => {
      const buffer = createEXEBuffer();
      const result = await validateFileContent(buffer, 'program.exe');

      expect(result.valid).toBe(false);
      expect(result.error).toBe('File type not allowed');
    });
  });

  // ---- Edge cases ----

  describe('edge cases', () => {
    it('should reject empty buffer', async () => {
      const buffer = Buffer.alloc(0);
      const result = await validateFileContent(buffer, 'empty.pdf');

      expect(result.valid).toBe(false);
      expect(result.error).toBe('Empty file content');
    });

    it('should reject null buffer', async () => {
      const result = await validateFileContent(null, 'file.pdf');

      expect(result.valid).toBe(false);
      expect(result.error).toBe('Empty file content');
    });

    it('should reject undefined buffer', async () => {
      const result = await validateFileContent(undefined, 'file.pdf');

      expect(result.valid).toBe(false);
      expect(result.error).toBe('Empty file content');
    });

    it('should reject buffer exceeding PDF size limit', async () => {
      // PDF limit is 20MB — create a buffer just over that
      const overLimitSize = 20 * 1024 * 1024 + 1;
      const buffer = createPDFBuffer(overLimitSize);
      const result = await validateFileContent(buffer, 'huge.pdf');

      expect(result.valid).toBe(false);
      expect(result.error).toMatch(/File exceeds maximum size/);
    });

    it('should reject buffer exceeding image size limit', async () => {
      // Image limit is 10MB — create a JPEG buffer just over that
      const overLimitSize = 10 * 1024 * 1024 + 1;
      const buffer = createJPEGBuffer(overLimitSize);
      const result = await validateFileContent(buffer, 'huge.jpg');

      expect(result.valid).toBe(false);
      expect(result.error).toMatch(/File exceeds maximum size/);
    });

    it('should reject buffer exceeding txt size limit', async () => {
      // Text limit is 5MB — create a text-like buffer just over that
      const overLimitSize = 5 * 1024 * 1024 + 1;
      const content = 'A'.repeat(overLimitSize);
      const buffer = Buffer.from(content, 'utf-8');
      const result = await validateFileContent(buffer, 'huge.txt');

      expect(result.valid).toBe(false);
      expect(result.error).toMatch(/File exceeds maximum size/);
    });

    it('should accept undetectable type (plain text) with allowed .txt extension', async () => {
      const buffer = createTextBuffer();
      const result = await validateFileContent(buffer, 'notes.txt');

      expect(result.valid).toBe(true);
      expect(result.detectedType).toBeNull();
      expect(result.warning).toBe('Could not verify file type from content');
    });

    it('should reject undetectable type with disallowed extension', async () => {
      const buffer = createTextBuffer();
      const result = await validateFileContent(buffer, 'script.sh');

      expect(result.valid).toBe(false);
      expect(result.error).toBe('File type not allowed');
    });

    it('should accept PDF buffer within size limit', async () => {
      const buffer = createPDFBuffer(1024);
      const result = await validateFileContent(buffer, 'small.pdf');

      expect(result.valid).toBe(true);
      expect(result.detectedType.ext).toBe('pdf');
    });
  });
});

// ===========================================================================
// sanitizeFileName
// ===========================================================================

describe('sanitizeFileName', () => {
  describe('clean filenames — no change needed', () => {
    it('should return "report.pdf" unchanged', () => {
      expect(sanitizeFileName('report.pdf')).toBe('report.pdf');
    });

    it('should return "photo_2024.jpg" unchanged', () => {
      expect(sanitizeFileName('photo_2024.jpg')).toBe('photo_2024.jpg');
    });
  });

  describe('path traversal removal', () => {
    it('should strip "../../../etc/passwd" to "etcpasswd"', () => {
      const result = sanitizeFileName('../../../etc/passwd');
      expect(result).toBe('etcpasswd');
      expect(result).not.toContain('..');
      expect(result).not.toContain('/');
    });

    it('should strip "..\\..\\windows\\system32\\config" traversal', () => {
      const result = sanitizeFileName('..\\..\\windows\\system32\\config');
      expect(result).not.toContain('..');
      expect(result).not.toContain('\\');
    });
  });

  describe('null byte removal', () => {
    it('should strip null bytes from "file\\x00name.pdf"', () => {
      const result = sanitizeFileName('file\x00name.pdf');
      expect(result).toBe('filename.pdf');
      expect(result).not.toContain('\x00');
    });
  });

  describe('special character replacement', () => {
    it('should replace spaces and parentheses in "my document (1).pdf"', () => {
      const result = sanitizeFileName('my document (1).pdf');
      expect(result).toBe('my_document_1_.pdf');
    });

    it('should replace angle brackets and pipes', () => {
      const result = sanitizeFileName('file<name>|test.pdf');
      expect(result).not.toContain('<');
      expect(result).not.toContain('>');
      expect(result).not.toContain('|');
    });
  });

  describe('error handling', () => {
    it('should throw on empty string', () => {
      expect(() => sanitizeFileName('')).toThrow();
    });

    it('should throw on null', () => {
      expect(() => sanitizeFileName(null)).toThrow();
    });

    it('should throw on undefined', () => {
      expect(() => sanitizeFileName(undefined)).toThrow();
    });
  });

  describe('length truncation', () => {
    it('should truncate very long names to 255 chars preserving extension', () => {
      const longName = 'a'.repeat(300) + '.pdf';
      const result = sanitizeFileName(longName);

      expect(result.length).toBeLessThanOrEqual(255);
      expect(result).toMatch(/\.pdf$/);
    });

    it('should truncate long names without extension to 255 chars', () => {
      const longName = 'b'.repeat(300);
      const result = sanitizeFileName(longName);

      expect(result.length).toBeLessThanOrEqual(255);
    });
  });
});

// ===========================================================================
// Constants
// ===========================================================================

describe('ALLOWED_FILE_TYPES', () => {
  it('should be an array', () => {
    expect(Array.isArray(ALLOWED_FILE_TYPES)).toBe(true);
  });

  it('should include pdf, jpg, jpeg, png, heic, tiff, txt', () => {
    const expected = ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'tiff', 'txt'];
    for (const type of expected) {
      expect(ALLOWED_FILE_TYPES).toContain(type);
    }
  });

  it('should NOT include exe, zip, sh, bat', () => {
    const forbidden = ['exe', 'zip', 'sh', 'bat'];
    for (const type of forbidden) {
      expect(ALLOWED_FILE_TYPES).not.toContain(type);
    }
  });
});

describe('FILE_SIZE_LIMITS', () => {
  it('should be an object', () => {
    expect(typeof FILE_SIZE_LIMITS).toBe('object');
    expect(FILE_SIZE_LIMITS).not.toBeNull();
  });

  it('should set PDF limit to 20MB', () => {
    expect(FILE_SIZE_LIMITS.pdf).toBe(20 * 1024 * 1024);
  });

  it('should set image limits to 10MB', () => {
    const imageTypes = ['jpg', 'jpeg', 'png', 'heic', 'tiff'];
    for (const type of imageTypes) {
      expect(FILE_SIZE_LIMITS[type]).toBe(10 * 1024 * 1024);
    }
  });

  it('should set txt limit to 5MB', () => {
    expect(FILE_SIZE_LIMITS.txt).toBe(5 * 1024 * 1024);
  });

  it('should set a default limit of 10MB', () => {
    expect(FILE_SIZE_LIMITS.default).toBe(10 * 1024 * 1024);
  });
});
