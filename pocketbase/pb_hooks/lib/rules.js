var CATEGORY_FACTOR = { full: 1, child: 0.5, student: 0.7 }
var MORNING_FACTOR = 0.8
var MOSCOW_OFFSET_HOURS = 3
var BREAK_MINUTES = 20

function ticketPrice(basePrice, hallFactor, category, startsAtMs) {
  var factor = CATEGORY_FACTOR[category]
  if (factor === undefined) {
    return -1
  }
  var hour = new Date(startsAtMs + MOSCOW_OFFSET_HOURS * 3600 * 1000).getUTCHours()
  var morning = hour < 12 ? MORNING_FACTOR : 1
  return Math.round(basePrice * hallFactor * factor * morning)
}

function screeningEnd(startsAtMs, durationMin) {
  return startsAtMs + (durationMin + BREAK_MINUTES) * 60 * 1000
}

function toPbDate(ms) {
  return new Date(ms).toISOString().replace('T', ' ')
}

function fromPbDate(s) {
  return new Date(String(s).replace(' ', 'T')).getTime()
}

module.exports = {
  ticketPrice: ticketPrice,
  screeningEnd: screeningEnd,
  toPbDate: toPbDate,
  fromPbDate: fromPbDate,
}
