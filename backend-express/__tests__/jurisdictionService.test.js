/**
 * Jurisdiction Detection Service — Tests
 *
 * TDD RED phase for plan 15-02.
 * Tests detectJurisdiction(caseData, options) across all specified behavior cases.
 */

const JurisdictionService = require('../services/jurisdictionService');

describe('JurisdictionService', () => {
  let service;

  beforeEach(() => {
    service = new JurisdictionService();
  });

  // -------------------------------------------------------------------------
  // Basic property state detection
  // -------------------------------------------------------------------------
  describe('property state detection', () => {
    it('returns applicableStates including CA when propertyState is CA', () => {
      const result = service.detectJurisdiction({ propertyState: 'CA' });

      expect(result.propertyState).toBe('CA');
      expect(result.applicableStates).toContain('CA');
      expect(result.determinationMethod).toBe('property_location');
      expect(result.confidence).toBe('high');
    });

    it('returns applicableStates including TX when propertyState is TX', () => {
      const result = service.detectJurisdiction({ propertyState: 'TX' });

      expect(result.propertyState).toBe('TX');
      expect(result.applicableStates).toContain('TX');
      expect(result.determinationMethod).toBe('property_location');
      expect(result.confidence).toBe('high');
    });
  });

  // -------------------------------------------------------------------------
  // Servicer state fallback
  // -------------------------------------------------------------------------
  describe('servicer state fallback', () => {
    it('uses servicerState when no propertyState is provided', () => {
      const result = service.detectJurisdiction({ servicerState: 'NY' });

      expect(result.servicerState).toBe('NY');
      expect(result.applicableStates).toEqual(['NY']);
      expect(result.determinationMethod).toBe('servicer_location');
      expect(result.confidence).toBe('medium');
    });
  });

  // -------------------------------------------------------------------------
  // Both property and servicer states
  // -------------------------------------------------------------------------
  describe('both property and servicer states', () => {
    it('includes both states when propertyState and servicerState differ', () => {
      const result = service.detectJurisdiction({
        propertyState: 'TX',
        servicerState: 'NY'
      });

      expect(result.propertyState).toBe('TX');
      expect(result.servicerState).toBe('NY');
      expect(result.applicableStates).toEqual(['TX', 'NY']);
      expect(result.determinationMethod).toBe('property_location');
      expect(result.confidence).toBe('high');
    });
  });

  // -------------------------------------------------------------------------
  // Unsupported state
  // -------------------------------------------------------------------------
  describe('unsupported state', () => {
    it('returns empty applicableStates and low confidence for unsupported state', () => {
      const result = service.detectJurisdiction({ propertyState: 'WY' });

      expect(result.propertyState).toBe('WY');
      expect(result.applicableStates).toEqual([]);
      expect(result.confidence).toBe('low');
    });
  });

  // -------------------------------------------------------------------------
  // No state info at all
  // -------------------------------------------------------------------------
  describe('no state info', () => {
    it('returns empty applicableStates, method default, confidence none', () => {
      const result = service.detectJurisdiction({});

      expect(result.applicableStates).toEqual([]);
      expect(result.determinationMethod).toBe('default');
      expect(result.confidence).toBe('none');
    });

    it('handles undefined caseData gracefully', () => {
      const result = service.detectJurisdiction();

      expect(result.applicableStates).toEqual([]);
      expect(result.determinationMethod).toBe('default');
      expect(result.confidence).toBe('none');
    });

    it('handles null caseData gracefully', () => {
      const result = service.detectJurisdiction(null);

      expect(result.applicableStates).toEqual([]);
      expect(result.determinationMethod).toBe('default');
      expect(result.confidence).toBe('none');
    });
  });

  // -------------------------------------------------------------------------
  // Manual override
  // -------------------------------------------------------------------------
  describe('manual override', () => {
    it('uses manualState from options to override detection', () => {
      const result = service.detectJurisdiction(
        { propertyState: 'CA', servicerState: 'NY' },
        { manualState: 'FL' }
      );

      expect(result.applicableStates).toEqual(['FL']);
      expect(result.determinationMethod).toBe('manual');
      expect(result.confidence).toBe('high');
    });

    it('returns empty applicableStates if manualState is unsupported', () => {
      const result = service.detectJurisdiction(
        { propertyState: 'CA' },
        { manualState: 'WY' }
      );

      expect(result.applicableStates).toEqual([]);
      expect(result.determinationMethod).toBe('manual');
      expect(result.confidence).toBe('low');
    });
  });

  // -------------------------------------------------------------------------
  // Invalid state codes
  // -------------------------------------------------------------------------
  describe('invalid state codes', () => {
    it('handles invalid state code XX gracefully', () => {
      const result = service.detectJurisdiction({ propertyState: 'XX' });

      expect(result.applicableStates).toEqual([]);
      expect(result.confidence).toBe('low');
    });

    it('handles numeric state code gracefully', () => {
      const result = service.detectJurisdiction({ propertyState: '123' });

      expect(result.applicableStates).toEqual([]);
    });

    it('handles null propertyState gracefully', () => {
      const result = service.detectJurisdiction({ propertyState: null });

      expect(result.applicableStates).toEqual([]);
      expect(result.determinationMethod).toBe('default');
      expect(result.confidence).toBe('none');
    });

    it('handles empty string propertyState gracefully', () => {
      const result = service.detectJurisdiction({ propertyState: '' });

      expect(result.applicableStates).toEqual([]);
      expect(result.determinationMethod).toBe('default');
      expect(result.confidence).toBe('none');
    });
  });

  // -------------------------------------------------------------------------
  // Deduplication
  // -------------------------------------------------------------------------
  describe('deduplication', () => {
    it('does not duplicate state when propertyState and servicerState are the same', () => {
      const result = service.detectJurisdiction({
        propertyState: 'CA',
        servicerState: 'CA'
      });

      expect(result.applicableStates).toEqual(['CA']);
      expect(result.determinationMethod).toBe('property_location');
      expect(result.confidence).toBe('high');
    });
  });

  // -------------------------------------------------------------------------
  // isStateSupported filtering
  // -------------------------------------------------------------------------
  describe('isStateSupported filtering', () => {
    it('only includes states present in stateStatuteTaxonomy', () => {
      // TX is supported, WY is not
      const result = service.detectJurisdiction({
        propertyState: 'TX',
        servicerState: 'WY'
      });

      expect(result.applicableStates).toEqual(['TX']);
      expect(result.applicableStates).not.toContain('WY');
    });

    it('returns all six supported states when asked', () => {
      // Verify supported states list is correct
      const { getSupportedStates } = require('../config/stateStatuteTaxonomy');
      const supported = getSupportedStates();
      expect(supported).toEqual(expect.arrayContaining(['CA', 'NY', 'TX', 'FL', 'IL', 'MA']));
      expect(supported).toHaveLength(6);
    });
  });

  // -------------------------------------------------------------------------
  // Return object structure
  // -------------------------------------------------------------------------
  describe('return object structure', () => {
    it('returns all expected fields', () => {
      const result = service.detectJurisdiction({ propertyState: 'CA' });

      expect(result).toHaveProperty('propertyState');
      expect(result).toHaveProperty('servicerState');
      expect(result).toHaveProperty('applicableStates');
      expect(result).toHaveProperty('determinationMethod');
      expect(result).toHaveProperty('confidence');
    });

    it('sets servicerState to null when not provided', () => {
      const result = service.detectJurisdiction({ propertyState: 'CA' });

      expect(result.servicerState).toBeNull();
    });

    it('sets propertyState to null when not provided', () => {
      const result = service.detectJurisdiction({ servicerState: 'NY' });

      expect(result.propertyState).toBeNull();
    });
  });

  // -------------------------------------------------------------------------
  // Priority order: manual > property > servicer
  // -------------------------------------------------------------------------
  describe('priority order', () => {
    it('manual override takes priority over property and servicer', () => {
      const result = service.detectJurisdiction(
        { propertyState: 'CA', servicerState: 'NY' },
        { manualState: 'IL' }
      );

      expect(result.applicableStates).toEqual(['IL']);
      expect(result.determinationMethod).toBe('manual');
    });

    it('property state takes priority over servicer for determination method', () => {
      const result = service.detectJurisdiction({
        propertyState: 'FL',
        servicerState: 'MA'
      });

      expect(result.determinationMethod).toBe('property_location');
      expect(result.applicableStates).toEqual(['FL', 'MA']);
    });
  });
});
