///
/// The following value assumes a polar radius of
/// r_p = 6356752.3
/// and an equatorial radius of
/// r_e = 6378137
/// The value is calculated as e2 == (r_e^2 - r_p^2)/(r_e^2)
/// Use exact value to avoid rounding errors
///
///
const E2 = 0.00669447819799;
const EARTH_EQ_RADIUS = 6378137.0;
const EARTH_MERIDIONAL_CIRCUMFERENCE = 40007860.0;
const EPSILON = 1e-12;
const MAX_SUPPORTED_RADIUS = 8587;
const METERS_PER_DEGREE_LATITUDE = 110574.0;
