This page describe the update database script from the deployment process
==========================================================================

In the deployment folder a file called "changesets" exists.
In this file a list of directories exists. 
All these directories exists in the changesets folder.

For each directory in this file a number of sql files exists.
Whenever the update script runs it will run all sql scripts in order (see naming below) in each folder listed in the changesets.txt file.

When a folder has been run once, it will not be run again in any future runs of the script.

This means that when a changeset (folder) has been run, it will do no good adding a sql file to that folder, since it will not be run again.

Naming of sql files
-------------------
The files in a changeset folder are run in alphanumeric order, meaning that files beginning with 1,2,3, etc are run first. Then files beginning with a,b,c .. will be run

Example
-------

So this folder structure could be one way of doing it
<pre>
|-changesets
|  |-AddColumnToTable
|  |  \--1 AddColumnToTable.sql
|  \-CreateTable
|     |-1 CreateTable.sql
|     \-2 AddIndices.sql
\-changesets.txt
</pre>

The changesets.txt would simply look like this:  

     CreateTable  
     AddColumnToTable  

Internal Stuff
--------------
The script keeps track of which files have been run in a table called db_changes.
If this table does not exist when the script is run, the script will create it.

In the table, only changesets ie. directory names are saved.
