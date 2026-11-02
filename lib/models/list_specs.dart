import 'list_query.dart';

const ListSpec kGenreSpec = ListSpec(sortFields: ['title'], defaultSort: 'title');

const ListSpec kPersonSpec = ListSpec(
  sortFields: ['fullName', 'country'],
  defaultSort: 'fullName',
  filterKeys: ['country'],
);

const ListSpec kHallSpec = ListSpec(
  sortFields: ['name', 'rows', 'priceFactor'],
  defaultSort: 'name',
  filterKeys: ['format'],
);

const ListSpec kMovieSpec = ListSpec(
  sortFields: ['title', 'year', 'durationMin'],
  defaultSort: 'title',
  filterKeys: ['genre', 'age', 'yearFrom', 'yearTo'],
);

const ListSpec kScreeningSpec = ListSpec(
  sortFields: ['startsAt', 'basePrice', 'movie'],
  defaultSort: 'startsAt',
  filterKeys: ['movie', 'hall', 'date', 'language', 'period'],
  filterDefaults: {'period': 'upcoming'},
);

const ListSpec kOrderSpec = ListSpec(
  sortFields: ['created', 'total'],
  defaultSort: 'created',
  defaultAscending: false,
  filterKeys: ['status', 'channel', 'date', 'screening'],
);

const ListSpec kTicketSpec = ListSpec(
  sortFields: ['created', 'price', 'screening'],
  defaultSort: 'created',
  defaultAscending: false,
  filterKeys: ['status', 'category', 'screening', 'period'],
);

const ListSpec kUserSpec = ListSpec(
  sortFields: ['name', 'email', 'role'],
  defaultSort: 'name',
  filterKeys: ['role'],
);
