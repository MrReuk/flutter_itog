migrate(
  (app) => {
    const rules = require(`${__hooks}/lib/rules.js`)
    const col = (n) => app.findCollectionByNameOrId(n)
    const add = (collection, data) => {
      const r = new Record(col(collection))
      for (const k in data) r.set(k, data[k])
      app.save(r)
      return r
    }

    const mkUser = (email, password, name, role) =>
      add('users', { email, password, passwordConfirm: password, name, role, verified: true })
    mkUser('admin@atrium.test', 'Admin12345', 'Администратор Атриума', 'admin')
    mkUser('cashier@atrium.test', 'Cashier12345', 'Кассир Мария Орлова', 'cashier')
    const viewer = mkUser('viewer@atrium.test', 'Viewer12345', 'Иван Зрителев', 'viewer')

    const su = new Record(app.findCollectionByNameOrId('_superusers'))
    su.set('email', 'root@atrium.test')
    su.set('password', 'Root123456')
    app.save(su)

    const genreNames = ['Драма', 'Комедия', 'Триллер', 'Фантастика', 'Приключения', 'Мелодрама', 'Анимация', 'Детектив']
    const g = {}
    genreNames.forEach((t) => (g[t] = add('genres', { title: t }).id))

    const peopleData = [
      ['Алексей Громов', 'Россия'],
      ['Мария Светлова', 'Россия'],
      ['Дмитрий Ветров', 'Россия'],
      ['Елена Март', 'Россия'],
      ['Ольга Рябина', 'Беларусь'],
      ['Павел Нордин', 'Россия'],
      ['Анна Лесная', 'Россия'],
      ['Игорь Волков', 'Россия'],
      ['Сергей Мирный', 'Казахстан'],
      ['Татьяна Ясная', 'Россия'],
      ['Роман Каменев', 'Россия'],
      ['Вера Полярная', 'Россия'],
    ]
    const p = peopleData.map(([fullName, country]) => add('people', { fullName, country }).id)

    const hallData = [
      ['Зал 1', '2D', 8, 12, 1.0],
      ['Зал 2', '3D', 7, 10, 1.2],
      ['Зал IMAX', 'IMAX', 10, 14, 1.6],
      ['Зал VIP', 'VIP', 4, 8, 2.0],
    ]
    const halls = hallData.map(([name, format, rows, seatsPerRow, priceFactor]) =>
      add('halls', { name, format, rows, seatsPerRow, priceFactor }),
    )

    const movieData = [
      ['Последний рейс', 2025, 118, '16+', 'Россия', [g['Триллер'], g['Драма']], [p[0]], [p[1], p[2]], 'Пилот-ветеран получает последний рейс в своей карьере и узнаёт, что груз на борту не тот, о котором ему сказали.'],
      ['Тихая гавань', 2024, 104, '12+', 'Россия', [g['Драма'], g['Мелодрама']], [p[3]], [p[4], p[5]], 'История двух людей, которые встретились в маленьком портовом городе накануне зимы.'],
      ['Звёздный курьер', 2026, 132, '12+', 'Россия', [g['Фантастика'], g['Приключения']], [p[5]], [p[6], p[7], p[8]], 'Курьер межпланетной почты везёт посылку, из-за которой за ним охотятся сразу три флота.'],
      ['Лето в коммуналке', 2023, 96, '6+', 'Россия', [g['Комедия']], [p[2]], [p[9], p[10]], 'Семейная комедия о том, как три поколения делят одну квартиру в жаркий июль.'],
      ['Тайна старого маяка', 2025, 110, '12+', 'Беларусь', [g['Детектив'], g['Приключения']], [p[4]], [p[0], p[11]], 'Подростки находят в маяке карту, которая ведёт к давно потерянной экспедиции.'],
      ['Северный ветер', 2024, 125, '16+', 'Россия', [g['Драма']], [p[7]], [p[1], p[3]], 'Хроника одной зимовки на полярной станции и решения, которые нельзя отменить.'],
      ['Облако по имени Тим', 2026, 88, '0+', 'Россия', [g['Анимация'], g['Комедия']], [p[9]], [p[10]], 'Маленькое облако мечтает пролиться дождём над пустыней.'],
      ['Код возврата', 2025, 101, '16+', 'Россия', [g['Триллер']], [p[11]], [p[6], p[8]], 'Программистка находит в старом коде сообщение, которое ведёт к её пропавшему брату.'],
      ['Дом на два берега', 2023, 114, '12+', 'Казахстан', [g['Мелодрама'], g['Драма']], [p[8]], [p[2], p[4]], 'Двое соседей строят мост через реку, которая разделила их семьи.'],
      ['Охотники за ветром', 2026, 140, '12+', 'Россия', [g['Приключения'], g['Фантастика']], [p[0]], [p[5], p[7], p[11]], 'Экипаж дирижабля пересекает штормовой океан ради одного редкого семени.'],
    ]
    const movies = movieData.map(([title, year, durationMin, ageRating, country, genres, directors, actors, description]) =>
      add('movies', { title, year, durationMin, ageRating, country, genres, directors, actors, description }),
    )

    const slots = [10, 13.5, 17, 20.5]
    const midnightUtc = new Date()
    midnightUtc.setUTCHours(0, 0, 0, 0)
    const created = []
    for (let d = 0; d < 7; d++) {
      halls.forEach((hall, hi) => {
        slots.forEach((slot, si) => {
          const movie = movies[(d * 3 + hi * 2 + si) % movies.length]
          const hour = Math.floor(slot)
          const min = Math.round((slot - hour) * 60)
          const start = midnightUtc.getTime() + d * 86400000 + ((hour - 3) * 60 + min) * 60000
          const base = si === 0 ? 300 : si === 1 ? 350 : 400
          const s = add('screenings', {
            movie: movie.id,
            hall: hall.id,
            startsAt: rules.toPbDate(start),
            endsAt: rules.toPbDate(rules.screeningEnd(start, movie.getInt('durationMin'))),
            basePrice: base,
            language: (d + hi + si) % 5 === 0 ? 'Оригинал, субтитры' : 'Дубляж',
          })
          created.push({ record: s, hall, start })
        })
      })
    }

    const future = created.find((c) => c.start > Date.now() + 3600000)
    if (future) {
      const order = add('orders', {
        screening: future.record.id,
        customer: viewer.id,
        status: 'paid',
        total: 0,
      })
      let total = 0
      ;[[4, 5, 'full'], [4, 6, 'student']].forEach(([row, seat, category]) => {
        const price = rules.ticketPrice(
          future.record.getInt('basePrice'),
          future.hall.getFloat('priceFactor'),
          category,
          future.start,
        )
        total += price
        add('tickets', { order: order.id, screening: future.record.id, row, seat, category, price, status: 'sold' })
      })
      order.set('total', total)
      app.save(order)
    }
  },
  (app) => {
  },
)
