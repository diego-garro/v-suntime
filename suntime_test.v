module suntime

import time

const today = time.new_time(year: 2022, month: 6, day: 6)
const tomorrow = today.add_days(1)


fn test_valid_sunrise_and_sunset_calculation_for_given_coordinates() {
	sun := Sun{lat: 9.928069, lon: -84.090725}
	sunrise := sun.get_sunrise_time(tomorrow) or {time.now()}
	sunset := sun.get_sunset_time(today) or {time.now()}

	assert sunrise.str() == '2022-06-07 11:15:00'
	assert sunset.str() == '2022-06-06 23:55:00'
}

fn test_sun_never_rises_or_sets_on_a_give_location() ? {
	sun := Sun{lat: 85.0, lon: 21.0}
	sunrise := sun.get_sunrise_time(tomorrow)?
	sunset := sun.get_sunset_time(today)?

	println(typeof(sunrise).name)

	assert sunrise.msg() == 'The sun never rises on this location (on the specified date)'
	// assert sunset == error('The sun never sets on this location (on the specified date)')
}
