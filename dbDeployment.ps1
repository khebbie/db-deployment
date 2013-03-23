param(
    $connectionString = "Data Source=.;Initial Catalog=MyDatabase;Integrated Security=True",
    $scriptpath = (Resolve-Path .)
)

#todo
#add errors to db
#follow up on errors in the, for instance don't run a script with more than x errors

$CreateChangesTableSql="if not exists (select * from sysobjects where name='db_changes' and xtype='U')
    create table db_changes (
        ChangeSet varchar(255) not null,
		ChangeDate DateTime not null
    )"

function pSql_query($sql, $cs) 
{
    $ds = new-object "System.Data.DataSet"
    $da = new-object "System.Data.SqlClient.SqlDataAdapter" ($sql, $cs)
    $record_count = $da.Fill($ds)
   $ds.Tables | Select-Object -Expand Rows
}

function pSql_execute_nonQuery($sql, $cs)
{
    $cn = new-object system.data.SqlClient.SqlConnection($cs)
    $cmd = new-object system.data.SqlClient.SqlCommand($sql, $cn)
    $cmd.CommandTimeout = 600
    $cn.Open()
    $rowsAffected = $cmd.ExecuteNonQuery()
    $cn.Close()
}

function pSql_execute_scalar($sql, $cs)
{
    $cn = new-object system.data.SqlClient.SqlConnection($cs)
    $cmd = new-object system.data.SqlClient.SqlCommand($sql, $cn)
    $cmd.CommandTimeout = 600
    $cn.Open()
    $result = $cmd.ExecuteScalar()
    $cn.Close()
    return $result
}

function EnsureDbExists(){
    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $connectionString
    $dbName = $builder.InitialCatalog
    $builder.set_InitialCatalog("master")
    $createDbSql = "IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = '$dbName') CREATE DATABASE $dbName"
    $master = $builder.ConnectionString
    pSql_execute_nonQuery $createDbSql $master
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

 function BuildChangeString($changesetName, $nameOfFile){
    return "$changesetName/$nameOfFile"
 }

function ApplyChangesets {
    $changesetFilePath = join-path $scriptpath "changesets.txt"
    $changesetFile = cat $changesetFilePath
    foreach($change in $changesetFile){ 
        ApplyChangeset $change
    }
}
 
function ApplyChangeset ($change) {
    $changeFilesSqlPattern = join-path $scriptpath "changesets/$change/*.sql"
    $sqlFiles = ls $changeFilesSqlPattern
    $alreadyRunScripts = GetAlreadyRunScripts
    $sqlFilesToRun = $sqlFiles | where { $alreadyRunScripts.ChangeSet -notcontains (BuildChangeString $change $_.Name)}
    foreach($sqlFile in $sqlFilesToRun) {
        $sqlFileName = $sqlFile.Name
        $changeSetAndFilename = BuildChangeString $change $sqlFileName
        Write-Host "Applying changeset '$changeSetAndFilename'."
        RunSqlFile $sqlFile $changeSetAndFilename
    }
}

function ApplyProcedures {
    $objectType = "procedures"
    $folder = Join-Path $scriptPath "$objectType/*.sql"
    foreach ($file in (gci $folder)) {
        $sql = cat $file
        $name = $file.Name
        $objectName = $name.Replace(".sql", "")
        Write-Host "Applying procedure '$objectName'."
        $countSql = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_TYPE = 'PROCEDURE' AND ROUTINE_NAME = '$objectName'"
        $count = pSql_execute_scalar $countSql $connectionString
        if ($count -eq 0) { $sql = $sql.Replace("ALTER PROCEDURE", "CREATE PROCEDURE") }
        else { $sql = $sql.Replace("CREATE PROCEDURE", "ALTER PROCEDURE") }
        pSql_execute_nonQuery $sql $connectionString
    }
}

###################################################
## Script main start                             ##
###################################################

cls

Write-Host "Connection string: $connectionString"
Write-Host "Script path: $scriptPath"

EnsureDbExists
ApplyChangesets
ApplyProcedures
