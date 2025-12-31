/**
 * Form validation utilities for edit forms
 *
 * Field length limits and character validation rules.
 */

// Maximum character lengths for fields
export const MAX_LENGTHS = {
  // Short text fields
  scientific_name: 100,
  author: 200,
  local_name: 100,  // Per individual local name
  name: 100,        // Generic name field (taxon, source)
  license: 100,

  // Medium text fields
  url: 500,

  // Long text fields (textarea)
  range: 5000,
  leaves: 5000,
  flowers: 5000,
  fruits: 5000,
  bark: 5000,
  twigs: 5000,
  buds: 5000,
  growth_habit: 5000,
  hardiness_habitat: 5000,
  miscellaneous: 5000,
  notes: 5000,
  description: 5000
};

// Characters allowed in scientific_name (letters, spaces, × symbol, hyphens)
const SCIENTIFIC_NAME_PATTERN = /^[a-zA-Z\s×\-]+$/;

/**
 * Validate scientific name characters
 * @param {string} value - The value to validate
 * @returns {{valid: boolean, message?: string}}
 */
export function validateScientificName(value) {
  if (!value || !value.trim()) {
    return { valid: true }; // Empty is handled by required validation
  }

  if (!SCIENTIFIC_NAME_PATTERN.test(value)) {
    return {
      valid: false,
      message: 'Only letters, spaces, × symbol, and hyphens allowed'
    };
  }

  if (value.length > MAX_LENGTHS.scientific_name) {
    return {
      valid: false,
      message: `Maximum ${MAX_LENGTHS.scientific_name} characters`
    };
  }

  return { valid: true };
}

/**
 * Validate URL format
 * @param {string} value - The URL to validate
 * @returns {{valid: boolean, message?: string}}
 */
export function validateUrl(value) {
  if (!value || !value.trim()) {
    return { valid: true }; // Empty is valid (optional field)
  }

  if (value.length > MAX_LENGTHS.url) {
    return {
      valid: false,
      message: `Maximum ${MAX_LENGTHS.url} characters`
    };
  }

  try {
    new URL(value);
    return { valid: true };
  } catch {
    return {
      valid: false,
      message: 'Please enter a valid URL (e.g., https://example.com)'
    };
  }
}

/**
 * Validate field length
 * @param {string} value - The value to validate
 * @param {number} maxLength - Maximum allowed length
 * @returns {{valid: boolean, message?: string}}
 */
export function validateLength(value, maxLength) {
  if (!value) {
    return { valid: true };
  }

  if (value.length > maxLength) {
    return {
      valid: false,
      message: `Maximum ${maxLength} characters`
    };
  }

  return { valid: true };
}

/**
 * Validate a local name entry
 * @param {string} value - The local name to validate
 * @returns {{valid: boolean, message?: string}}
 */
export function validateLocalName(value) {
  if (!value || !value.trim()) {
    return { valid: true };
  }

  if (value.length > MAX_LENGTHS.local_name) {
    return {
      valid: false,
      message: `Each name maximum ${MAX_LENGTHS.local_name} characters`
    };
  }

  return { valid: true };
}

/**
 * Validate an array of local names
 * @param {string[]} names - Array of local names
 * @returns {{valid: boolean, message?: string}}
 */
export function validateLocalNames(names) {
  if (!names || names.length === 0) {
    return { valid: true };
  }

  for (const name of names) {
    const result = validateLocalName(name);
    if (!result.valid) {
      return result;
    }
  }

  return { valid: true };
}

/**
 * Get character count display text
 * @param {string} value - Current value
 * @param {number} maxLength - Maximum length
 * @returns {{count: number, max: number, remaining: number, exceeded: boolean}}
 */
export function getCharacterCount(value, maxLength) {
  const count = value?.length || 0;
  return {
    count,
    max: maxLength,
    remaining: maxLength - count,
    exceeded: count > maxLength
  };
}
