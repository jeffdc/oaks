// External link icons - imported as raw SVG strings
import wikipedia from './wikipedia.svg?raw';
import inaturalist from './inaturalist.svg?raw';
import usda from './usda.svg?raw';
import gbif from './gbif.svg?raw';
import powo from './powo.svg?raw';
import generic from './generic.svg?raw';

// Map logo identifiers to SVG strings
export const logoIcons = {
  wikipedia,
  inaturalist,
  usda,
  gbif,
  powo,
  generic,
};

/**
 * Get the SVG icon for a logo identifier
 * @param {string} logoId - The logo identifier (e.g., "wikipedia", "inaturalist")
 * @returns {string} The SVG markup string
 */
export function getLogoIcon(logoId) {
  return logoIcons[logoId] || logoIcons.generic;
}
