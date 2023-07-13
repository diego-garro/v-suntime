module suntime

import math
import time

struct SunTimeError {
	Error
	message string
}

fn (err SunTimeError) msg() string {
	return err.message
}

// Approximated calculation of the sunrise and sunset datetimes for
// a given coordinates.
//
// @param lat: the latitude as a double.
// @param lon: the longitude as a double.
struct Sun {
pub:
	lat f64
	lon f64
}

pub fn new_sun(lat f64, lon f64) Sun {
	return Sun{
		lat: lat
		lon: lon
	}
}

// get_sunrise_time calculates the sunrise UTC time for a given date.
//
// @param date: Reference date.
//
// Returns the `time.Time` sunrise datetime or an error where there
// is no sunrise on the given location and date.
pub fn (s Sun) get_sunrise_time(t time.Time) ?time.Time {
	sunrise := s.calc_sun_time(date: t) or {
		return error('The sun never rises on this location (on the specified date)')
	}
	return sunrise
}

// get_sunset_time calculates the sunrise UTC time for a given date.
//
// @param date: Reference date.
//
// Returns the `time.Time` sunset datetime or an error where there
// is no sunrise on the given location and date.
pub fn (s Sun) get_sunset_time(t time.Time) ?time.Time {
	sunrise := s.calc_sun_time(date: t, is_rise_time: false) or {
		return error('The sun never sets on this location (on the specified date)')
	}
	return sunrise
}

// a given coordinates.
//
// @param lat: the latitude as a double.
// @param lon: the longitude as a double.
[params]
struct CalcSunTime {
mut:
	date         time.Time
	is_rise_time bool = true
	zenith       f64  = 90.8
}

// Calculates sunrise or sunset date in UTC.
//
// Returns SunTimeError when there is no sunrise or sunset on given
// location and date.
fn (s Sun) calc_sun_time(cst CalcSunTime) ?time.Time {
	// is_rise_time == false, returns sunset time
	mut day := cst.date.day
	mut month := cst.date.month
	mut year := cst.date.year

	to_rad := math.pi / 180.0

	// 1. Fisrt step: Calculate the day of the year.
	n1 := math.floor(275 * month / 9)
	n2 := math.floor((month + 9) / 12)
	n3 := (1 + math.floor((year - 4 * math.floor(year / 4) + 2) / 3))
	n := n1 - (n2 * n3) + day - 30

	// 2. Second step: Convert tha longitude to hour value and calculate an approximate time.
	lng_hour := s.lon / 15

	mut t := f64(0)
	if cst.is_rise_time {
		t = n + ((6 - lng_hour) / 24)
	} else { // Sunset
		t = n + ((18 - lng_hour) / 24)
	}

	// 3. Third step: Calculate the Sun's mean anomaly.
	m := (0.9856 * t) - 3.289

	// 4. Fourth step: Calculate the Sun's true longitude.
	mut l := m + (1.916 * math.sin(to_rad * m)) + (0.020 * math.sin(to_rad * 2 * m)) + 282.634
	l = force_range(l, 360.0) // NOTE: l adjusted into the range [0, 360).

	// 5.a Fifth.a step: Calculate the Sun's right ascension.
	mut ra := (1 / to_rad) * math.atan(0.91764 * math.tan(to_rad * l))
	ra = force_range(ra, 360.0)

	// 5.b Fifth.b step: Right ascension value needs to be in the same quadrant as l.
	l_quadrant := math.floor(l / 90) * 90
	ra_quadrant := math.floor(ra / 90) * 90
	ra = ra + (l_quadrant - ra_quadrant)

	// 5.c Fifth.c step: Right ascension value needs to be converted into hours.
	ra = ra / 15

	// 6. Sixth step: Calculate the Sun's declination.
	sin_dec := 0.39782 * math.sin(to_rad * l)
	cos_dec := math.cos(math.sin(sin_dec))

	// 7.a Seventh.a step: Calculate the Sun's local hour angle.
	cos_h := (math.cos(to_rad * cst.zenith) - (sin_dec * math.sin(to_rad * s.lat))) / (cos_dec * math.cos(to_rad * s.lat))

	if cos_h > 1 {
		return error('The Sun never rises on this location (on the specified date)')
	}
	if cos_h < -1 {
		return error('The Sun never sets on this location (on the specified date)')
	}

	// 7.b Seventh.b step: Finish calculating h and convert into hours.
	mut h := f64(0)
	if cst.is_rise_time {
		h = 360 - (1 / to_rad) * math.acos(cos_h)
	} else { // setting
		h = (1 / to_rad) * math.acos(cos_h)
	}

	h = h / 15

	// 8. Eighth step: Calculate local mean time of rising/setting.
	lt := h + ra - (0.06571 * t) - 6.622

	// 9. Nineth step: Adjust back to UTC.
	mut ut := lt - lng_hour
	ut = force_range(ut, 24) // UTC time in decimal format (e.g. 23.23)

	// 10. Tenth step: Return.
	mut hr := force_range(ut, 24)
	mut min := math.round((ut - int(ut)) * 60)
	if min == 60 {
		hr += 1
		min = 0
	}

	// Check corner case https://github.com/SatAgro/suntime/issues/1
	if hr == 24 {
		hr = 0
		day += 1

		days_in_current_month := time.days_in_month(cst.date.month, cst.date.year) or {31}
		if day > days_in_current_month {
			day = 1
			month += 1

			if month > 12 {
				month = 1
				year += 1
			}
		}
	}

	return time.Time{
		year: year
		month: month
		day: day
		hour: int(hr)
		minute: int(min)
	}
}

// `force_range` forces v to be >= 0 and < max.
fn force_range(v f64, max f64) f64 {
	if v < 0 {
		return v + max
	} else if v >= max {
		return v - max
	} else {
		return v
	}
}
