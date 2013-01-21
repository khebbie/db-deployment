if not exists (select * from sysobjects where name='db_changestmp' and xtype='U')
    create table db_changestmp (
        ChangeSet varchar(255) not null,
		ChangeDate DateTime not null
    )