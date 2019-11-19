#!/bin/bash

section_print () {
  printf "##############################################################################\n$1\n" >> $2
  printf "##############################################################################\n" >> $2

}

infoSchema="information_schema"
timeStamp=$(date +%Y%m%d%H%M%S)

read -p 'Maria/MySQL Username: ' userName
read -sp 'Password: ' pass
printf "\n"
read -p 'Maria/MySQL Database: ' dataBase
read -p 'Host (default localhost): ' hostName

#Set some defaults password because I'm tired of typing it.
userName="${userName:-"root"}"
hostName="${hostName:-"localhost"}"
dataBase="${dataBase:-"chr"}"
pass="${pass:-"P@ssw0rdP@ssw0rd"}"
outputFile="$timeStamp""_""$dataBase""_analysis_on_""$hostName"".out"
touch $outputFile

#Test Login credentials.  Exit on error.
printf "Attempting to access $dataBase\n"
errorMessage=$(mysql -u $userName -p$pass -D $dataBase -h $hostName -e exit 2>&1) 
if [[ $? == 1 ]];then
  printf "Failed to access Database. \n$errorMessage\nExiting early..."
  exit 1
else
  printf "Successfully logged in.  Continuing script.\n"
fi

section_print "Beginning of Script" $outputFile

#System Information
section_print "Some Basic DB Info" $outputFile
mysql -u $userName -p$pass -h $hostName -vvv -e "show variables where variable_name like '%version%';" | sed -e '$ d' -e '1,3 d' >> $outputFile

#Other available databases
mysql -u $userName -p$pass -h $hostName -vvv -e "show databases;" | sed -e '$ d' -e '1,3 d' >> $outputFile

#Look at tables and columns
section_print "Show table and columns for $dataBase" $outputFile
mysql -u $userName -p$pass -D $infoSchema -h $hostName -vvv -e "select tables.table_name, tables.create_time, columns.column_name, columns.column_type from \
tables inner join columns on tables.table_name = columns.table_name where tables.table_schema = '$dataBase';" | sed -e '$ d' -e '1,3 d' >> $outputFile

#Foreign Key printout
section_print "Show Foreign Keys for $dataBase" $outputFile
mysql -u $userName -p$pass -D $infoSchema -h $hostName -vvv -e "select TABLE_NAME, 'Foreign Key to', REFERENCED_TABLE_NAME, CONSTRAINT_NAME \
from referential_constraints where CONSTRAINT_SCHEMA = '$dataBase';" | sed -e '$ d' -e '1,3 d' >> $outputFile

#Row Count for database
section_print "Show Row Counts for $dataBase" $outputFile
mysql -u $userName -p$pass -D $infoSchema -h $hostName -vvv -e "select TABLE_NAME, TABLE_ROWS from tables \
where table_schema = '$dataBase';" | sed -e '$ d' -e '1,3 d'>> $outputFile

#User Privileges
section_print "Get All User Privileges that exist on this server" $outputFile
mysql -u $userName -p$pass -D $infoSchema -h $hostName -vvv -e "select * from user_privileges;" | sed -e '$ d' -e '1,3 d' >> $outputFile

#Log File Section
logLookBack=5
sqlLogFile=$(mysql -u $userName -p$pass -D $dataBase -h $hostName -e "show variables where variable_name = 'general_log_file'" 2>&1 |\
    grep general_log_file | sed "s/general_log_file//g" | xargs ) 
section_print "Log File information for this instance of MySQL/MariaDB" $outputFile
printf "The logs are located here: ""$sqlLogFile\n" >> $outputFile
cat $sqlLogFile &> /dev/null 
if [[ $? == 1 ]];then
  printf "Cannot read log file, likely a permission error.\nSQL Queries still ran successfully and are in this directory as $outputFile\n"
  exit 1
else
  printf "Here are the dates for the last few Log Files" >> $outputFile
  ls -lrt $(echo $sqlLogFile | sed "s/\(.*[/]\)\(.*\)/\1*/g")  | tail $logLookBack | awk -F ' +' '{print $6 " " $7 " " $8}' | sed -n '1p;$p' >> $outputFile
  section_print "Show all Deletes from the last $logLookBack log files.  Print the Time, User, Database, and command used" $outputFile
  ls -t $(echo $sqlLogFile | sed "s/\(.*[/]\)\(.*\)/\1*/g") | head -n $logLookBack | xargs -i grep {} -e 'DELETE' | cut -d "," -f 1,3,8,9- >> $outputFile
fi


section_print "End of Script" $outputFile
