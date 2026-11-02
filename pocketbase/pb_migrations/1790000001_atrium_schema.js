migrate(
  (app) => {
    const ROLE = '@request.auth.role'
    const ADMIN = `${ROLE} = "admin"`
    const STAFF = `(${ROLE} = "admin" || ${ROLE} = "cashier")`
    const AUTH = '@request.auth.id != ""'

    const users = app.findCollectionByNameOrId('users')
    const name = users.fields.getByName('name')
    name.required = true
    name.min = 2
    name.max = 80
    users.fields.add(
      new SelectField({
        name: 'role',
        required: true,
        maxSelect: 1,
        values: ['viewer', 'cashier', 'admin'],
      }),
    )
    users.listRule = `id = @request.auth.id || ${ADMIN}`
    users.viewRule = `id = @request.auth.id || ${ADMIN}`
    users.createRule = `@request.body.role = "viewer" || ${ADMIN}`
    users.updateRule = `(id = @request.auth.id && @request.body.role:isset = false) || ${ADMIN}`
    users.deleteRule = ADMIN
    app.save(users)

    const genres = new Collection({
      type: 'base',
      name: 'genres',
      fields: [{ type: 'text', name: 'title', required: true, min: 2, max: 40 }],
      indexes: ['CREATE UNIQUE INDEX idx_genres_title ON genres (title)'],
      listRule: '',
      viewRule: '',
      createRule: ADMIN,
      updateRule: ADMIN,
      deleteRule: ADMIN,
    })
    app.save(genres)

    const people = new Collection({
      type: 'base',
      name: 'people',
      fields: [
        { type: 'text', name: 'fullName', required: true, min: 2, max: 80 },
        { type: 'text', name: 'country', max: 60 },
        { type: 'date', name: 'birthDate' },
      ],
      indexes: ['CREATE INDEX idx_people_name ON people (fullName)'],
      listRule: '',
      viewRule: '',
      createRule: ADMIN,
      updateRule: ADMIN,
      deleteRule: ADMIN,
    })
    app.save(people)

    const halls = new Collection({
      type: 'base',
      name: 'halls',
      fields: [
        { type: 'text', name: 'name', required: true, min: 2, max: 40 },
        { type: 'select', name: 'format', required: true, maxSelect: 1, values: ['2D', '3D', 'IMAX', 'VIP'] },
        { type: 'number', name: 'rows', required: true, onlyInt: true, min: 1, max: 20 },
        { type: 'number', name: 'seatsPerRow', required: true, onlyInt: true, min: 1, max: 30 },
        { type: 'number', name: 'priceFactor', required: true, min: 0.5, max: 3 },
      ],
      indexes: ['CREATE UNIQUE INDEX idx_halls_name ON halls (name)'],
      listRule: '',
      viewRule: '',
      createRule: ADMIN,
      updateRule: ADMIN,
      deleteRule: ADMIN,
    })
    app.save(halls)

    const movies = new Collection({
      type: 'base',
      name: 'movies',
      fields: [
        { type: 'text', name: 'title', required: true, min: 1, max: 120 },
        { type: 'text', name: 'description', max: 2000 },
        { type: 'number', name: 'year', required: true, onlyInt: true, min: 1900, max: 2100 },
        { type: 'number', name: 'durationMin', required: true, onlyInt: true, min: 1, max: 400 },
        { type: 'select', name: 'ageRating', required: true, maxSelect: 1, values: ['0+', '6+', '12+', '16+', '18+'] },
        { type: 'text', name: 'country', max: 60 },
        {
          type: 'file',
          name: 'poster',
          maxSelect: 1,
          maxSize: 2097152,
          mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
          thumbs: ['200x300'],
        },
        {
          type: 'relation',
          name: 'genres',
          collectionId: genres.id,
          required: true,
          minSelect: 1,
          maxSelect: 5,
          cascadeDelete: false,
        },
        { type: 'relation', name: 'directors', collectionId: people.id, maxSelect: 5, cascadeDelete: false },
        { type: 'relation', name: 'actors', collectionId: people.id, maxSelect: 20, cascadeDelete: false },
      ],
      indexes: [
        'CREATE UNIQUE INDEX idx_movies_title_year ON movies (title, year)',
        'CREATE INDEX idx_movies_year ON movies (year)',
      ],
      listRule: '',
      viewRule: '',
      createRule: ADMIN,
      updateRule: ADMIN,
      deleteRule: ADMIN,
    })
    app.save(movies)

    const screenings = new Collection({
      type: 'base',
      name: 'screenings',
      fields: [
        { type: 'relation', name: 'movie', collectionId: movies.id, required: true, maxSelect: 1, cascadeDelete: false },
        { type: 'relation', name: 'hall', collectionId: halls.id, required: true, maxSelect: 1, cascadeDelete: false },
        { type: 'date', name: 'startsAt', required: true },
        { type: 'date', name: 'endsAt' },
        { type: 'number', name: 'basePrice', required: true, min: 50, max: 10000 },
        { type: 'select', name: 'language', required: true, maxSelect: 1, values: ['Дубляж', 'Оригинал, субтитры'] },
      ],
      indexes: [
        'CREATE INDEX idx_screenings_start ON screenings (startsAt)',
        'CREATE INDEX idx_screenings_hall_start ON screenings (hall, startsAt)',
      ],
      listRule: '',
      viewRule: '',
      createRule: ADMIN,
      updateRule: ADMIN,
      deleteRule: ADMIN,
    })
    app.save(screenings)

    const profiles = new Collection({
      type: 'base',
      name: 'viewer_profiles',
      fields: [
        {
          type: 'relation',
          name: 'user',
          collectionId: users.id,
          required: true,
          maxSelect: 1,
          cascadeDelete: true,
        },
        { type: 'text', name: 'phone', max: 20, pattern: '^\\+?[0-9 ()\\-]{7,20}$' },
        { type: 'date', name: 'birthDate' },
        { type: 'bool', name: 'student' },
        { type: 'relation', name: 'favoriteGenre', collectionId: genres.id, maxSelect: 1, cascadeDelete: false },
      ],
      indexes: ['CREATE UNIQUE INDEX idx_profiles_user ON viewer_profiles (user)'],
      listRule: `user = @request.auth.id || ${ADMIN}`,
      viewRule: `user = @request.auth.id || ${ADMIN}`,
      createRule: `${AUTH} && (@request.body.user = @request.auth.id || ${ADMIN})`,
      updateRule: `user = @request.auth.id || ${ADMIN}`,
      deleteRule: ADMIN,
    })
    app.save(profiles)

    const orders = new Collection({
      type: 'base',
      name: 'orders',
      fields: [
        { type: 'relation', name: 'screening', collectionId: screenings.id, required: true, maxSelect: 1, cascadeDelete: false },
        { type: 'relation', name: 'customer', collectionId: users.id, maxSelect: 1, cascadeDelete: false },
        { type: 'relation', name: 'cashier', collectionId: users.id, maxSelect: 1, cascadeDelete: false },
        { type: 'select', name: 'status', required: true, maxSelect: 1, values: ['paid', 'refunded'] },
        { type: 'number', name: 'total', min: 0 },
        { type: 'autodate', name: 'created', onCreate: true, onUpdate: false },
      ],
      indexes: [
        'CREATE INDEX idx_orders_customer ON orders (customer)',
        'CREATE INDEX idx_orders_screening ON orders (screening)',
      ],
      listRule: `${AUTH} && (customer = @request.auth.id || cashier = @request.auth.id || ${ADMIN})`,
      viewRule: `${AUTH} && (customer = @request.auth.id || cashier = @request.auth.id || ${ADMIN})`,
      createRule: `${AUTH} && (${STAFF} || @request.body.customer = @request.auth.id)`,
      updateRule: `${STAFF} || (${AUTH} && customer = @request.auth.id && @request.body.total:isset = false && @request.body.customer:isset = false && @request.body.cashier:isset = false && @request.body.screening:isset = false)`,
      deleteRule: ADMIN,
    })
    app.save(orders)

    const tickets = new Collection({
      type: 'base',
      name: 'tickets',
      fields: [
        { type: 'relation', name: 'order', collectionId: orders.id, required: true, maxSelect: 1, cascadeDelete: true },
        { type: 'relation', name: 'screening', collectionId: screenings.id, required: true, maxSelect: 1, cascadeDelete: false },
        { type: 'number', name: 'row', required: true, onlyInt: true, min: 1, max: 20 },
        { type: 'number', name: 'seat', required: true, onlyInt: true, min: 1, max: 30 },
        { type: 'select', name: 'category', required: true, maxSelect: 1, values: ['full', 'child', 'student'] },
        { type: 'number', name: 'price', min: 0 },
        { type: 'select', name: 'status', required: true, maxSelect: 1, values: ['sold', 'returned', 'used'] },
        { type: 'autodate', name: 'created', onCreate: true, onUpdate: false },
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_tickets_seat ON tickets (screening, row, seat) WHERE status != 'returned'",
        'CREATE INDEX idx_tickets_order ON tickets (order)',
      ],
      listRule: `${AUTH} && (order.customer = @request.auth.id || ${STAFF})`,
      viewRule: `${AUTH} && (order.customer = @request.auth.id || ${STAFF})`,
      createRule: AUTH,
      updateRule: `${STAFF} || (${AUTH} && order.customer = @request.auth.id && @request.body.status = "returned" && @request.body.row:isset = false && @request.body.seat:isset = false && @request.body.price:isset = false && @request.body.category:isset = false)`,
      deleteRule: ADMIN,
    })
    app.save(tickets)
  },
  (app) => {
    for (const n of ['tickets', 'orders', 'viewer_profiles', 'screenings', 'movies', 'halls', 'people', 'genres']) {
      try {
        app.delete(app.findCollectionByNameOrId(n))
      } catch (_) {}
    }
    const users = app.findCollectionByNameOrId('users')
    users.fields.removeByName('role')
    app.save(users)
  },
)
