// External link icons - imported as raw SVG strings
import wikipedia from './wikipedia.svg?raw';
import inaturalist from './inaturalist.svg?raw';
import usda from './usda.svg?raw';
import gbif from './gbif.svg?raw';
import powo from './powo.svg?raw';
import fna from './fna.svg?raw';
import feis from './feis.svg?raw';
import generic from './generic.svg?raw';

// Map logo identifiers to SVG strings
export const logoIcons = {
  wikipedia,
  inaturalist,
  usda,
  gbif,
  powo,
  fna,
  feis,
  generic,
};

// Map known source names to logo identifiers (for when logo field is empty)
const nameToLogoMap = {
  'flora of north america': 'fna',
  'fire effects information system': 'feis',
  'wikipedia': 'wikipedia',
  'inaturalist': 'inaturalist',
};

/**
 * Get the logo identifier for a link, inferring from name if logo is not set
 * @param {Object} link - The link object with name, url, and logo fields
 * @returns {string} The logo identifier
 */
export function getLinkLogoId(link) {
  // Use explicit logo if set
  if (link.logo) {
    return link.logo;
  }
  // Try to infer from name
  const nameLower = (link.name || '').toLowerCase();
  return nameToLogoMap[nameLower] || 'generic';
}

/**
 * Get the SVG icon for a logo identifier
 * @param {string} logoId - The logo identifier (e.g., "wikipedia", "inaturalist")
 * @returns {string} The SVG markup string
 */
export function getLogoIcon(logoId) {
  return logoIcons[logoId] || logoIcons.generic;
}
