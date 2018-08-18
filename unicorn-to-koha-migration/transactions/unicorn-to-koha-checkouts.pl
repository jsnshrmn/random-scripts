#!/usr/bin/perl
use strict;
#use warnings;

## open filehandles
open(MYKOHASQLFILE, '>Z:/kohaissues.sql') || die("Could not open output file!");
print MYKOHASQLFILE "use koha;\n";


## Gets checkouts in this format:
## USERID|DATE DUE(yyyymmddhhss)|DATE RENEWED (yyyymmddhhss|NEVER)|DATE CHECKED OUT (yyyymmddhhss)|ITEMID   |
##  and loads this data into an array

my @checkouts = qx(selcharge -oIUdec 2>NUL | selitem -iK -oSB 2>NUL | seluser -iK -oBS 2>NUL);
foreach my $i (@checkouts) {
	## split the pipe delimited 
	## data into an array so we can
	## assign it and format it
	#print "$i";
	my @i = split(/\|/, $i);
	my $userid = @i[0];
	my $date_due = &convert_date(@i[1]);
	my $lastrenewdate = &convert_date(@i[2]);
	my $timestamp = @i[3];
	my $itemid = @i[4];
	$itemid =~ s/^\s+//;
  	$itemid =~ s/\s+$//;



	#print "\nUser ID:	$userid\n";
	#print "Due Date:	$date_due\n";
	#print "Renewed:	$lastrenewdate\n";
	#print "Timestamp:	$timestamp\n";
	#print "Item ID:	$itemid\n";

	print MYKOHASQLFILE 'INSERT INTO issues (borrowernumber,itemnumber,date_due,branchcode,returndate,lastrenewdate,timestamp) VALUES((select borrowernumber.borrowers WHERE cardnumber.borrowers = \'' . $userid .'\' ),(select itemnumber.items WHERE barcode.items = \''. $itemid .'\' ),' . $date_due . ',NASH,' . $lastrenewdate . ',' . $timestamp . ');' . "\n";

## This is the format we need for koha
## borrowernumber,itemnumber,date_due (YYYY-MM-DD),branchcode(NASH),issuingbranch,returndate,lastreneweddate (YYYY-MM-DD),return,renewals,timestamp (YYYY-MM-DD HH:MM:SS),issuedate (YYYY-MM-DD)

#update borrowtemp, items set borrowtemp.itemnumber = 
#items.itemnumber where borrowtemp.barcode = items.barcode;

#Finally, the issues table can be populated with the borrowed books:

#mysql> insert into issues (borrowernumber, itemnumber, date_due, 
#branchcode) select borrowtemp.borrowernumber, borrowtemp.itemnumber, 
#date_add(CURDATE(), interval 8 month) as date_due, 'RIM' as branchcode 
#from borrowtemp;

}


## convert dates from yyyymmddhhss to YYYY-MM-DD
sub convert_date {
	my $date = $_[0];
	if (defined $date){
		if ($date eq 'NEVER') {
			return 'NULL'
		} else {
#($date =~ /^([\d]{4})([\d]{2})([\d]{2})([\d]{2})([\d]{2})$/)
			#0123 45 67
			my $year = substr($date,0,4);
			my $month = substr($date,4,2);
			my $day = substr($date,6,2);
			return "$year-$month-$day";
}	}	}

print MYKOHASQLFILE "exit;\n";
close(MYKOHASQLFILE);
exit;