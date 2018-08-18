use strict;
#use warnings;
#use diagnostics;

### Get Everything started ##
# start timer
my($start) = time();
my $debug = 'OFF';  ##set to "ON" for per user debugging

{
	##Set the multiline records to start at the record boundary line
	local $/ = "*** DOCUMENT BOUNDARY ***";

	##open up the source unicorn dump, and the destination file
	open(MYUNICORNFILE, 'users.flat') || die("Could not open file!");
	open(MYMERGEFILE, '>users-fixed.flat') || die("Could not open file!");

	#slurp the unicorn records up without messing with our special document delimiter
	my $unicornfile;
	while (<MYUNICORNFILE>){
		$unicornfile .= $_;
	}
	close(MYUNICORNFILE);
	my @unicornfile = split(/\*\*\* DOCUMENT BOUNDARY \*\*\*/, $unicornfile);
	my($unicornrecord);
	my $i=0;
	##check the entire unicorn file for name to see if the first and last names are backwards
	foreach $unicornrecord (@unicornfile){

		if($unicornrecord =~ m/.USER_NAME.\s{3}\|a([A-Z]+),\s{1}([A-Z]+)\n.USER_PROFILE.\s{3}\|aSTUDENT\n.USER_STATUS.\s{3}\|aOK\n.USER_ADDR1_BEGIN.\n.EMAIL.\s{3}\|astu\1([a-z]*)\2\@usao.edu/i){
		##compare the supposed first and last names from the user name field to see if there is a match in the usao email address.  Compare the order.  USAO emails are firstname possible intials last name
			$unicornrecord =~ s/.USER_NAME.\s{3}\|a([A-Z]+),\s{1}([A-Z]+)\n.USER_PROFILE.\s{3}\|aSTUDENT\n.USER_STATUS.\s{3}\|aOK\n.USER_ADDR1_BEGIN.\n.EMAIL.\s{3}\|astu\1([a-z]*)\2\@usao.edu/.USER_NAME.   \|a\2, \1\n.USER_PROFILE.   \|aSTUDENT\n.USER_STATUS.   \|aOK\n.USER_ADDR1_BEGIN.\n.EMAIL.   \|astu\1\3\2\@usao.edu/i;
			$i++;
			#print "$1 " . "$2\n";
			#print "$namecat\n";
			#print "$unicornrecord";
			#print 'start' . "\n" . "$unicornrecord" . "\n" . 'end' . "\n";
			print MYMERGEFILE "$unicornrecord";
			}
		}
		print "$i users found.\n";		
	}

	close(MYMERGEFILE);

	##very dirty cleanup output
	open(MYMERGEFILE, 'users-fixed.flat') || die("Could not open file!");
	my $mergefile;
	my $count;
	while (<MYMERGEFILE>){
		$mergefile .= $_;
	}
	close(MYMERGEFILE);

	print STDOUT "cleaning up the final output...\n";
	open(MYMERGEFILE, '>users-fixed.flat') || die("Could not open file!");
	print MYMERGEFILE "\*\*\* DOCUMENT BOUNDARY \*\*\*";
	##fix the records that are missing the document boundary
	$mergefile =~ s/\n\n\.USER_ID\./\n\*\*\* DOCUMENT BOUNDARY \*\*\*\n\.USER_ID\./sg;
	##make sure all name and address info is upper case
	$mergefile =~ s/\.USER_NAME\.\s+\|a(.+)/\.USER_NAME\.   \|a\U$1\E/g;
	$mergefile =~ s/\.CITY\/STATE\.\s+\|a(.+)/\.CITY\/STATE\.   \|a\U$1\E/g;
	$mergefile =~ s/\.STREET\.\s+\|a(.+)/\.STREET\.   \|a\U$1\E/g;
	#but email should be lowercase!
	$mergefile =~ s/\.EMAIL\.\s+\|a(.+)/\.EMAIL\.   \|a\L$1\E/g;
	print MYMERGEFILE "$mergefile";
	close(MYMERGEFILE);
	while ($mergefile =~ /\*\*\* DOCUMENT BOUNDARY \*\*\*/g) { $count++ }
    	print "$count merged records were produced.\n";




### Cleaning up ##

# end timer
my($end) = time();

# report
print "Time taken was ", ($end - $start), " seconds\n";

exit;