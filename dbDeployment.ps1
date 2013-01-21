#todo
#add errors to db
#follow up on errors in the, for instance don't run a script with more than x errors

$connectionString = $args[0]
$CreateChangesTableSql="if not exists (select * from sysobjects where name='db_changes' and xtype='U')
    create table db_changes (
        ChangeSet varchar(255) not null,
		ChangeDate DateTime not null
    )"

function pSql_query($sql, $connectionString) 
{
    if(!$connectionString)
    {
        $connectionString = "Data Source=localhost;Initial Catalog=master;Integrated Security=True"
    }
    $ds = new-object "System.Data.DataSet"
    $da = new-object "System.Data.SqlClient.SqlDataAdapter" ($sql, $connectionString)

    $record_count = $da.Fill($ds)

   $ds.Tables | Select-Object -Expand Rows
}

function pSql_execute_nonQuery($sql, $connectionString)
{
    if(!$connectionString)
    {
        $connectionString = "Data Source=localhost;Initial Catalog=master;Integrated Security=True"
    }
    $cn = new-object system.data.SqlClient.SqlConnection($connectionString)
    $cmd = new-object system.data.SqlClient.SqlCommand($sql, $cn)
    $cmd.CommandTimeout = 600
    $cn.Open()
    $cmd.ExecuteNonQuery()
    $cn.Close()
}

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

 function BuildChangeString($changesetName, $nameOfFile){
    return "$changesetName/$nameOfFile"
 }

###################################################
## Script main start                             ##
###################################################

 cls

 EnsureDbExists

 $changesetFile = cat changesets.txt

 foreach($change in $changesetFile){ 
    $scriptpath = $MyInvocation.MyCommand.Path
    $dir = Split-Path $scriptpath
    $changeFilesSqlPattern = join-path $dir "changesets/$change/*.sql"

    $sqlFiles = ls $changeFilesSqlPattern

    $alreadyRunScripts = GetAlreadyRunScripts
 
    $sqlFilesToRun = $sqlFiles | where { $alreadyRunScripts.ChangeSet -notcontains (BuildChangeString $change $_.Name)}
 
    foreach($sqlFile in $sqlFilesToRun) {
        $changeSetAndFilename = BuildChangeString  $change $sqlFile.Name
        RunSqlFile $sqlFile $changeSetAndFilename
    }
 }