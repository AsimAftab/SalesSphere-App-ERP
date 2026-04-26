// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outbox_dao.dart';

// ignore_for_file: type=lint
mixin _$OutboxDaoMixin on DatabaseAccessor<AppDatabase> {
  $MutationOutboxTable get mutationOutbox => attachedDatabase.mutationOutbox;
  OutboxDaoManager get managers => OutboxDaoManager(this);
}

class OutboxDaoManager {
  final _$OutboxDaoMixin _db;
  OutboxDaoManager(this._db);
  $$MutationOutboxTableTableManager get mutationOutbox =>
      $$MutationOutboxTableTableManager(
        _db.attachedDatabase,
        _db.mutationOutbox,
      );
}
