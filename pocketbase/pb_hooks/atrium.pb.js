onRecordAfterCreateSuccess((e) => {
  if (e.record.get('role') === 'viewer') {
    const profile = new Record($app.findCollectionByNameOrId('viewer_profiles'))
    profile.set('user', e.record.id)
    e.app.save(profile)
  }
  e.next()
}, 'users')

function checkScreening(e) {
  const rules = require(`${__hooks}/lib/rules.js`)
  const rec = e.record
  const movie = $app.findRecordById('movies', rec.get('movie'))
  const start = rules.fromPbDate(rec.getString('startsAt'))
  const end = rules.screeningEnd(start, movie.getInt('durationMin'))
  rec.set('endsAt', rules.toPbDate(end))

  let busy = null
  try {
    busy = $app.findFirstRecordByFilter(
      'screenings',
      'hall = {:hall} && id != {:id} && startsAt < {:end} && endsAt > {:start}',
      { hall: rec.getString('hall'), id: rec.id, start: rules.toPbDate(start), end: rules.toPbDate(end) },
    )
  } catch (_) {
    busy = null
  }
  if (busy) {
    throw new ApiError(409, 'В это время зал занят другим сеансом', {
      startsAt: new ValidationError('hall_busy', 'Зал занят в это время другим сеансом.'),
    })
  }
  e.next()
}
onRecordCreateRequest(checkScreening, 'screenings')
onRecordUpdateRequest(checkScreening, 'screenings')

onRecordCreateRequest((e) => {
  const rules = require(`${__hooks}/lib/rules.js`)
  const ticket = e.record
  const order = $app.findRecordById('orders', ticket.getString('order'))
  const role = e.auth ? e.auth.getString('role') : ''

  const own = e.auth && order.getString('customer') === e.auth.id
  if (role !== 'cashier' && role !== 'admin' && !own) {
    throw new ForbiddenError('Нельзя добавлять билеты в чужой заказ')
  }
  if (order.getString('screening') !== ticket.getString('screening')) {
    throw new BadRequestError('Билет и заказ относятся к разным сеансам', {
      screening: new ValidationError('mismatch', 'Сеанс билета не совпадает с сеансом заказа.'),
    })
  }

  const screening = $app.findRecordById('screenings', ticket.getString('screening'))
  const hall = $app.findRecordById('halls', screening.getString('hall'))
  const start = rules.fromPbDate(screening.getString('startsAt'))
  if (role === 'viewer' && start < Date.now()) {
    throw new BadRequestError('Сеанс уже начался', {
      screening: new ValidationError('started', 'Сеанс уже начался, продажа закрыта.'),
    })
  }
  if (ticket.getInt('row') > hall.getInt('rows')) {
    throw new BadRequestError('Нет такого ряда', {
      row: new ValidationError('out_of_range', `В зале ${hall.getInt('rows')} рядов.`),
    })
  }
  if (ticket.getInt('seat') > hall.getInt('seatsPerRow')) {
    throw new BadRequestError('Нет такого места', {
      seat: new ValidationError('out_of_range', `В ряду ${hall.getInt('seatsPerRow')} мест.`),
    })
  }

  let taken = null
  try {
    taken = $app.findFirstRecordByFilter(
      'tickets',
      "screening = {:s} && row = {:r} && seat = {:p} && status != 'returned'",
      { s: screening.id, r: ticket.getInt('row'), p: ticket.getInt('seat') },
    )
  } catch (_) {
    taken = null
  }
  if (taken) {
    throw new ApiError(409, 'Место уже занято', {
      seat: new ValidationError('seat_taken', 'Это место уже куплено.'),
    })
  }

  ticket.set(
    'price',
    rules.ticketPrice(screening.getInt('basePrice'), hall.getFloat('priceFactor'), ticket.getString('category'), start),
  )
  ticket.set('status', 'sold')
  e.next()
}, 'tickets')

onRecordCreateRequest((e) => {
  const role = e.auth ? e.auth.getString('role') : ''
  e.record.set('cashier', role === 'cashier' ? e.auth.id : '')
  e.record.set('status', 'paid')
  e.record.set('total', 0)
  e.next()
}, 'orders')

function recalcTotal(e) {
  e.next()
  const orderId = e.record.getString('order')
  const list = e.app.findRecordsByFilter('tickets', "order = {:o} && status != 'returned'", '', 500, 0, { o: orderId })
  let sum = 0
  for (const t of list) {
    sum += t.getInt('price')
  }
  const order = e.app.findRecordById('orders', orderId)
  order.set('total', sum)
  e.app.save(order)
}
onRecordAfterCreateSuccess(recalcTotal, 'tickets')
onRecordAfterUpdateSuccess(recalcTotal, 'tickets')

onRecordAfterDeleteSuccess((e) => {
  e.next()
  try {
    const orderId = e.record.getString('order')
    const list = e.app.findRecordsByFilter('tickets', "order = {:o} && status != 'returned'", '', 500, 0, { o: orderId })
    let sum = 0
    for (const t of list) {
      sum += t.getInt('price')
    }
    const order = e.app.findRecordById('orders', orderId)
    order.set('total', sum)
    e.app.save(order)
  } catch (_) {}
}, 'tickets')

onRecordUpdateRequest((e) => {
  const rules = require(`${__hooks}/lib/rules.js`)
  const role = e.auth ? e.auth.getString('role') : ''
  if (role === 'viewer') {
    if (e.record.original().getString('status') !== 'sold') {
      throw new BadRequestError('Билет уже возвращён или использован', {
        status: new ValidationError('not_sold', 'Вернуть можно только действующий билет.'),
      })
    }
    const screening = $app.findRecordById('screenings', e.record.getString('screening'))
    if (rules.fromPbDate(screening.getString('startsAt')) < Date.now()) {
      throw new BadRequestError('Сеанс уже начался', {
        status: new ValidationError('started', 'Сеанс уже начался, возврат закрыт.'),
      })
    }
  }
  e.next()
}, 'tickets')

routerAdd('GET', '/api/atrium/taken/{id}', (e) => {
  const id = e.request.pathValue('id')
  const list = $app.findRecordsByFilter('tickets', "screening = {:s} && status != 'returned'", '', 2000, 0, { s: id })
  return e.json(
    200,
    list.map((t) => ({ row: t.getInt('row'), seat: t.getInt('seat') })),
  )
})
