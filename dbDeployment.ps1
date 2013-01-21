$connectionString = "Data Source=wks-klh-1;Initial Catalog=ce-shop-drift;User ID=sa;Password=ExpandIT1;Packet Size=512"

$CreateChangesTableSql="if not exists (select * from sysobjects where name='db_changes' and xtype='U')
    create table db_changes (
        ChangeSet varchar(255) not null,
		ChangeDate DateTime not null
    )"

function EnsureDbExists(){
    pSql_execute_nonQuery $CreateChangesTableSql $connectionString
 }

 function GetAlreadyRunScripts(){
    pSql_query "select ChangeSet  from db_changes" $connectionString
 }

 function MarkScriptAsRun($file) {
    pSql_execute_nonQuery "insert into db_changes (ChangeSet, ChangeDate) values ('$file', GETDATE())" $connectionString
 }

 function RunSqlFile($file, $nameToMark) {
    $content = cat $file 
    if([string]::IsNullOrEmpty($content))
    {
        Write-Host "File not run or run with errors since it is empty" $file 
        return
    }
    try {
     pSql_execute_nonQuery $content $connectionString
     MarkScriptAsRun($nameToMark)
     }
     catch {
     Write-Host "File not run or run with errors" $file 
     $error[0]
     }
 }
###################################################
## Script main start                             ##
###################################################

 cls

 EnsureDbExists

 $changeFile = cat changesets.txt

 foreach($change in $changeFile)
 { 
    $changeFilesSql = "changesets/$change/*.sql"
    $sqlFiles = ls $changeFilesSql

    $alreadyRunScripts = GetAlreadyRunScripts
 
    $sqlFilesToRun = $sqlFiles | where { $alreadyRunScripts.ChangeSet -notcontains $_.Name }
 
    foreach($sqlFile in $sqlFilesToRun) {
        $filename = $sqlFile.Name
        $changeSetAndFilename = "$change/$filename"
        RunSqlFile $sqlFile $changeSetAndFilename
    }
 }
