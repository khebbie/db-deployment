if not exists (select * from sysobjects where name='db_changesklh' and xtype='U')
    create table db_changesklh (
        ChangeSet varchar(255) not null,
		ChangeDate DateTime not null
    )