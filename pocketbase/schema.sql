
CREATE TABLE users (
  id             TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
  email          TEXT DEFAULT '' NOT NULL,             -- UQ, NN
  name           TEXT DEFAULT '' NOT NULL,
  role           TEXT DEFAULT '' NOT NULL,             -- NN: viewer | cashier | admin
  password       TEXT DEFAULT '' NOT NULL,
  tokenKey       TEXT DEFAULT '' NOT NULL,
  verified       BOOLEAN DEFAULT FALSE NOT NULL,
  emailVisibility BOOLEAN DEFAULT FALSE NOT NULL,
  avatar         TEXT DEFAULT '' NOT NULL,
  created        TEXT DEFAULT '' NOT NULL,
  updated        TEXT DEFAULT '' NOT NULL
);
CREATE UNIQUE INDEX idx_tokenKey__pb_users_auth_ ON users (tokenKey);
CREATE UNIQUE INDEX idx_email__pb_users_auth_ ON users (email) WHERE email != '';

CREATE TABLE genres (
  id     TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
  title  TEXT DEFAULT '' NOT NULL                      -- NN, 2..40, UQ
);
CREATE UNIQUE INDEX idx_genres_title ON genres (title);

CREATE TABLE people (
  id         TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
  fullName   TEXT DEFAULT '' NOT NULL,                 -- NN, 2..80
  country    TEXT DEFAULT '' NOT NULL,
  birthDate  TEXT DEFAULT '' NOT NULL
);
CREATE INDEX idx_people_name ON people (fullName);

CREATE TABLE halls (
  id           TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
  name         TEXT DEFAULT '' NOT NULL,               -- NN, 2..40, UQ
  format       TEXT DEFAULT '' NOT NULL,               -- NN: 2D | 3D | IMAX | VIP
  rows         NUMERIC DEFAULT 0 NOT NULL,
  seatsPerRow  NUMERIC DEFAULT 0 NOT NULL,
  priceFactor  NUMERIC DEFAULT 0 NOT NULL              -- NN, 0.5..3
);
CREATE UNIQUE INDEX idx_halls_name ON halls (name);

CREATE TABLE movies (
  id           TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
  title        TEXT DEFAULT '' NOT NULL,               -- NN, 1..120
  description  TEXT DEFAULT '' NOT NULL,
  year         NUMERIC DEFAULT 0 NOT NULL,
  durationMin  NUMERIC DEFAULT 0 NOT NULL,
  ageRating    TEXT DEFAULT '' NOT NULL,               -- NN: 0+ | 6+ | 12+ | 16+ | 18+
  country      TEXT DEFAULT '' NOT NULL,
  poster       TEXT DEFAULT '' NOT NULL,
  genres       JSON DEFAULT '[]' NOT NULL,
  directors    JSON DEFAULT '[]' NOT NULL,
  actors       JSON DEFAULT '[]' NOT NULL
);
CREATE UNIQUE INDEX idx_movies_title_year ON movies (title, year);
CREATE INDEX idx_movies_year ON movies (year);

CREATE TABLE screenings (
  id         TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
  movie      TEXT DEFAULT '' NOT NULL,
  hall       TEXT DEFAULT '' NOT NULL,
  startsAt   TEXT DEFAULT '' NOT NULL,
  endsAt     TEXT DEFAULT '' NOT NULL,
  basePrice  NUMERIC DEFAULT 0 NOT NULL,               -- NN, 50..10000
  language   TEXT DEFAULT '' NOT NULL
);
CREATE INDEX idx_screenings_start ON screenings (startsAt);
CREATE INDEX idx_screenings_hall_start ON screenings (hall, startsAt);

CREATE TABLE viewer_profiles (
  id             TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
  user           TEXT DEFAULT '' NOT NULL,
  phone          TEXT DEFAULT '' NOT NULL,
  birthDate      TEXT DEFAULT '' NOT NULL,
  student        BOOLEAN DEFAULT FALSE NOT NULL,
  favoriteGenre  TEXT DEFAULT '' NOT NULL
);
CREATE UNIQUE INDEX idx_profiles_user ON viewer_profiles (user);

CREATE TABLE orders (
  id         TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
  screening  TEXT DEFAULT '' NOT NULL,
  customer   TEXT DEFAULT '' NOT NULL,
  cashier    TEXT DEFAULT '' NOT NULL,
  status     TEXT DEFAULT '' NOT NULL,                 -- NN: paid | refunded
  total      NUMERIC DEFAULT 0 NOT NULL,
  created    TEXT DEFAULT '' NOT NULL
);
CREATE INDEX idx_orders_customer ON orders (customer);
CREATE INDEX idx_orders_screening ON orders (screening);

CREATE TABLE tickets (
  id         TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
  "order"    TEXT DEFAULT '' NOT NULL,
  screening  TEXT DEFAULT '' NOT NULL,
  row        NUMERIC DEFAULT 0 NOT NULL,
  seat       NUMERIC DEFAULT 0 NOT NULL,
  category   TEXT DEFAULT '' NOT NULL,                 -- NN: full | child | student
  price      NUMERIC DEFAULT 0 NOT NULL,
  status     TEXT DEFAULT '' NOT NULL,                 -- NN: sold | returned | used
  created    TEXT DEFAULT '' NOT NULL
);
CREATE UNIQUE INDEX idx_tickets_seat ON tickets (screening, row, seat) WHERE status != 'returned';
CREATE INDEX idx_tickets_order ON tickets ("order");
