use strict;
#use warnings;
#use diagnostics;

### Get Everything started ##
# start timer
my($start) = time();
{
local $/ = "*** DOCUMENT BOUNDARY ***";

##address 1
open(MYINPUTFILE, 'usersafter1974.flat') || die("Could not open file!");
open(MYERRORFILE, '>error.flat') || die("Could not open file!");
open(MYTEMP1FILE, '>temp1.flat') || die("Could not open file!");
while(<MYINPUTFILE>)
{ 
my(@records) = <MYINPUTFILE>; 
my($record);
foreach $record (@records){
## if the separate city and state fields and the combined city/state field exist, put the data from the separate fields into the comibined fields
    if ($record=~ m/^((\n|.)*)\.USER_ADDR1_BEGIN\.((\n|.)*)\.CITY\/STATE\.(\s+)\|a([^\n]+)((\n|.)*)\.CITY\.(\s+)\|a([^\n]+)((\n|.)*)\.STATE\.(\s+)\|a([^\n]+)((\n|.)*)\.USER_ADDR1_END\.((\n|.)*)$/){
    print MYTEMP1FILE "$1\.USER_ADDR1_BEGIN\.$7\.CITY\/STATE\. \|a$10, $14\n\.USER_ADDR1_END\.$17";

## if the separate city and state fields are there, but there is no city/state field, create the field and put the separate data in it
    } elsif ($record=~ m/^((\n|.)*)\.USER_ADDR1_BEGIN\.((\n|.)*)\.CITY\.(\s+)\|a([^\n]+)((\n|.)*)\.STATE\.(\s+)\|a([^\n]+)((\n|.)*)\.USER_ADDR1_END\.((\n|.)*)$/){
    print MYTEMP1FILE "$1\.USER_ADDR1_BEGIN\.$3\.CITY\/STATE\. \|a$6, $10$11\.USER_ADDR1_END\.$13";

## if the separate city and state fields and the combined city/state field exist, but state comes before city, put the data from the separate fields into the comibined fields
   } elsif ($record=~ m/^((\n|.)*)\.USER_ADDR1_BEGIN\.((\n|.)*)\.CITY\/STATE\.(\s+)\|a([^\n]+)((\n|.)*)\.STATE\.(\s+)\|a([^\n]+)((\n|.)*)\.CITY\.(\s+)\|a([^\n]+)((\n|.)*)\n\.USER_ADDR1_END\.((\n|.)*)$/){
    print MYTEMP1FILE "$1\.USER_ADDR1_BEGIN\.$11\.CITY\/STATE\. \|a$14, $10\n\.USER_ADDR1_END\.$17";

    } else {
    print MYERRORFILE "$record";
    }
  }
print "$. records proccessed\n";	
 }
close(MYINPUTFILE) if eof;
close(MYERRORFILE);
close(MYTEMP1FILE);


##address 2
open(MYTEMP1FILE, 'temp1.flat') || die("Could not open file!");
open(MYTEMP2FILE, '>temp2.flat') || die("Could not open file!");
while(<MYTEMP1FILE>)
  { 
  my(@records) = <MYTEMP1FILE>; 
  my($record);
  foreach $record (@records){

    if ($record=~ m/^((\n|.)*)\.USER_ADDR2_BEGIN\.((\n|.)*)\.CITY\/STATE\.(\s+)\|a([^\n]+)((\n|.)*)\.CITY\.(\s+)\|a([^\n]+)((\n|.)*)\.STATE\.(\s+)\|a([^\n]+)((\n|.)*)\.USER_ADDR2_END\.((\n|.)*)$/){
    print MYTEMP2FILE "$1\.USER_ADDR2_BEGIN\.$7\.CITY\/STATE\. \|a$10, $14\.USER_ADDR2_END\.$17";
    } elsif ($record=~ m/^((\n|.)*)\.USER_ADDR2_BEGIN\.((\n|.)*)\.CITY\.(\s+)\|a([^\n]+)((\n|.)*)\.STATE\.(\s+)\|a([^\n]+)((\n|.)*)\.USER_ADDR2_END\.((\n|.)*)$/){
    print MYTEMP2FILE "$1\.USER_ADDR2_BEGIN\.$3\.CITY\/STATE\. \|a$6, $10$11\.USER_ADDR2_END\.$13";
   } elsif ($record=~ m/^((\n|.)*)\.USER_ADDR2_BEGIN\.((\n|.)*)\.CITY\/STATE\.(\s+)\|a([^\n]+)((\n|.)*)\.STATE\.(\s+)\|a([^\n]+)((\n|.)*)\.CITY\.(\s+)\|a([^\n]+)((\n|.)*)\n\.USER_ADDR2_END\.((\n|.)*)$/){
    print MYTEMP2FILE "$1\.USER_ADDR2_BEGIN\.$11\.CITY\/STATE\. \|a$14, $10\n\.USER_ADDR2_END\.$17";
    } else {
    print MYTEMP2FILE "$record";
    }
  }
close(MYTEMP1FILE) if eof;
close(MYTEMP2FILE);

##address 3
open(MYTEMP2FILE, 'temp2.flat') || die("Could not open file!");
open(MYOUTPUTFILE, '>output.flat') || die("Could not open file!");
while(<MYTEMP2FILE>)
  { 
  my(@records) = <MYTEMP2FILE>; 
  my($record);
  foreach $record (@records){
    if ($record=~ m/^((\n|.)*)\.USER_ADDR3_BEGIN\.((\n|.)*)\.CITY\/STATE\.(\s+)\|a([^\n]+)((\n|.)*)\.CITY\.(\s+)\|a([^\n]+)((\n|.)*)\.STATE\.(\s+)\|a([^\n]+)((\n|.)*)\.USER_ADDR3_END\.((\n|.)*)$/){
    print MYOUTPUTFILE "$1\.USER_ADDR3_BEGIN\.$7\.CITY\/STATE\. \|a$10, $14\.USER_ADDR3_END\.$17";
    } elsif ($record=~ m/^((\n|.)*)\.USER_ADDR3_BEGIN\.((\n|.)*)\.CITY\.(\s+)\|a([^\n]+)((\n|.)*)\.STATE\.(\s+)\|a([^\n]+)((\n|.)*)\.USER_ADDR3_END\.((\n|.)*)$/){
    print MYOUTPUTFILE "$1\.USER_ADDR3_BEGIN\.$3\.CITY\/STATE\. \|a$6, $10$11\.USER_ADDR3_END\.$13";
   } elsif ($record=~ m/^((\n|.)*)\.USER_ADDR3_BEGIN\.((\n|.)*)\.CITY\/STATE\.(\s+)\|a([^\n]+)((\n|.)*)\.STATE\.(\s+)\|a([^\n]+)((\n|.)*)\.CITY\.(\s+)\|a([^\n]+)((\n|.)*)\n\.USER_ADDR3_END\.((\n|.)*)$/){
    print MYOUTPUTFILE "$1\.USER_ADDR3_BEGIN\.$11\.CITY\/STATE\. \|a$14, $10\n\.USER_ADDR3_END\.$17";
    } else {
    print MYOUTPUTFILE "$record";
    }
  }
close(MYTEMP2FILE) if eof;
close(MYOUTPUTFILE);


}
}
}
### Cleaning up ##

# end timer
my($end) = time();

# report
print "Time taken was ", ($end - $start), " seconds\n";

exit;