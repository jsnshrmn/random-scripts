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

	##open up the 2 files we will compare, a current unicorn dump, and a current vax dump
	open(MYUNICORNFILE, 'unicorn-users.flat') || die("Could not open file!");
	open(MYVAXFILE, 'vax-users.flat') || die("Could not open file!");
	open(MYMERGEFILE, '>merge.flat') || die("Could not open file!");

	#slurp the unicorn records up without messing with our special document delimiter
	my $unicornfile;
	while (<MYUNICORNFILE>){
		$unicornfile .= $_;
	}
	close(MYUNICORNFILE);
	my @unicornfile = split(/\*\*\* DOCUMENT BOUNDARY \*\*\*/, $unicornfile);
	my($unicornrecord);
	
	#array for storing the user ids from the vax file
	my @vaxuserids;
	
	##compare the two files and merge records
	while(<MYVAXFILE>){ 
		my(@vaxrecords) = <MYVAXFILE>; 
		my($vaxrecord);
		foreach $vaxrecord (@vaxrecords){
			##extract the user ids from the vax file
			$vaxrecord =~ s/\n\n/\n/sg;
			if ($vaxrecord =~ m/\.USER_ID\.\s{3}\|a(\d+)\n/){
				my $vaxuserid = $1;
				chomp($vaxuserid);
				#add the user id to the array for later use
				push(@vaxuserids, $vaxuserid);
				##match on user id
				##if an id from the vax file matches on already in the unicorn file, update the addresses and print the record to the merge file
				## otherwise, it is a new record, and is printed to the merge file as is
				if($unicornfile =~ m/$vaxuserid/){
					#if ($debug == "ON") {print STDOUT "$vaxuserid is an existing user with new information\n";}
					##check the entire unicorn file for each id --this is poorly written
					foreach $unicornrecord (@unicornfile){
						if($unicornrecord =~ m/$vaxuserid/){
							##if we find a match we want to replace any empty address 2 or 3 fields with data from the vax address 1 or 2 fields
							## we set these address strings to line breaks by default, so if they are empty in the vax, we preserve the existing line break in the unicorn record		
							my $vaxrecordaddress1 = "\n";
							my $vaxrecordaddress2 = "\n";	
							if ($vaxrecord =~ m/\.USER_ADDR1_BEGIN\.(.*)\.USER_ADDR1_END\./s){
								$vaxrecordaddress1 = $1;
							}
							if ($vaxrecord =~ m/\.USER_ADDR2_BEGIN\.(.*)\.USER_ADDR2_END\./s){
								$vaxrecordaddress2 = $1;
							}	
							##do the actual address swaps -- this is also not pretty
							if($unicornrecord =~ m/\.USER_ADDR2_BEGIN\.\n\.USER_ADDR2_END\.\n\.USER_ADDR3_BEGIN\.\n\.USER_ADDR3_END\./){
								$unicornrecord =~ s/\.USER_ADDR2_BEGIN\.\n\.USER_ADDR2_END\./\.USER_ADDR2_BEGIN\.$vaxrecordaddress1\.USER_ADDR2_END\./;
								$unicornrecord =~ s/\.USER_ADDR3_BEGIN\.\n\.USER_ADDR3_END\./\.USER_ADDR3_BEGIN\.$vaxrecordaddress2\.USER_ADDR3_END\./;
							}elsif($unicornrecord =~ m/\.USER_ADDR2_BEGIN\.\n\.USER_ADDR2_END\./){
								$unicornrecord =~ s/\.USER_ADDR2_BEGIN\.\n\.USER_ADDR2_END\./\.USER_ADDR2_BEGIN\.$vaxrecordaddress1\.USER_ADDR2_END\./;
							}elsif($unicornrecord =~ m/\.USER_ADDR3_BEGIN\.\n\.USER_ADDR3_END\./){
								$unicornrecord =~ s/\.USER_ADDR3_BEGIN\.\n\.USER_ADDR3_END\./\.USER_ADDR3_BEGIN\.$vaxrecordaddress1\.USER_ADDR3_END\./;
							}
							print MYMERGEFILE "$unicornrecord";
						}
					}
				} else{
					#if ($debug == "ON") {print STDOUT "$vaxuserid is a new user\n";}
					print MYMERGEFILE  $vaxrecord;
				}
			}
		}
		print "$. vax records proccessed\n";	
	}
	close(MYVAXFILE) if eof;

	##convert that array of vax ids over to a hash for fast searching...
	my %is_vaxuserid;
	for (@vaxuserids) { $is_vaxuserid{$_} = 1; }
	foreach $unicornrecord (@unicornfile){
		#if the user id is not one we messed with earlier, it is an existing user with no new address info -- we should print this to the merge file as-is
		if ($unicornrecord=~ m/\.USER_ID\.\s{3}\|a(.+)\n/){
			my $unicornuserid = $1;
			chomp($unicornuserid);
			unless ($is_vaxuserid{$unicornuserid}){
			#if ($debug == "ON") {print STDOUT "$unicornuserid is an existing user with no new information\n";}
			print MYMERGEFILE "$unicornrecord";	
			}
		}
	}
	print  scalar(@unicornfile)." unicorn records examined\n";	
	close(MYMERGEFILE);
}

	##very dirty cleanup output
	open(MYMERGEFILE, 'merge.flat') || die("Could not open file!");
	my $mergefile;
	my $count;
	while (<MYMERGEFILE>){
		$mergefile .= $_;
	}
	close(MYMERGEFILE);

	print STDOUT "cleaning up the final output...\n";
	open(MYMERGEFILE, '>merge.flat') || die("Could not open file!");
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