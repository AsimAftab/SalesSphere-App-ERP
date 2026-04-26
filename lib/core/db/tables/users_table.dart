import 'package:drift/drift.dart';

@DataClassName('UserRow')
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get fullName => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get organizationId => text().nullable()();
  TextColumn get roleId => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
