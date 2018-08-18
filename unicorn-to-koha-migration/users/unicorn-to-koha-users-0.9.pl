#!/usr/bin/perl

use strict;
#use warnings;
print '
Unicorn to Koha holdings converter

This program will convert users records from SirsiDynix Unicorn GL 3.1
to something that Koha 3.0 can use.  It may work on other versions of these
two programs (including SirsiDynix Symphony), but it has not been tested.  
To get records from Unicorn, you will need to run som API commands
The easiest way to use this program is to place your Unicorn user
file into the same directory as this program.  The converted filename will
be the same as the input name, but with "_out.csv" appended.
';

print "\nProcessing File:\nThis may take a few minutes...\n";



### Get Everything started ##
# start timer
my($start) = time();
{
	##open filehandles
	open(MYERRORFILE, '>Z:/error.csv') || die("Could not open error file!");
	open(MYUSERKEYFILE, '+>userkey') || die("Could not open key file!");

	## open output csv and print header to csv
	my $output_file = 'Z:/sirsi_users_out.csv';
	open(MYOUTPUTFILE, "> $output_file") || die("Could not open output file!");
	print MYOUTPUTFILE "borrowernumber,cardnumber,surname,firstname,title,othernames,initials,streetnumber,streettype,address,address2,city,zipcode,email,phone,mobile,fax,emailpro,phonepro,B_streetnumber,B_streettype,B_address,B_city,B_zipcode,B_email,B_phone,dateofbirth,branchcode,categorycode,dateenrolled,dateexpiry,gonenoaddress,lost,debarred,contactname,contactfirstname,contacttitle,guarantorid,borrowernotes,relationship,ethnicity,ethnotes,sex,password,flags,userid,opacnote,contactnote,sort1,sort2,altcontactfirstname,altcontactsurname,altcontactaddress1,altcontactaddress2,altcontactaddress3,altcontactzipcode,altcontactphone,smsalertnumber\n";

	## Define variables to hold the number users we have iterated through
	my $usercount;


		## grab the user keys matched with the user id
		## stick 'em in a file
		my @userkeys = qx(seluser -oKB 2>NUL);
		foreach my $userkey (@userkeys) {
			print MYUSERKEYFILE $userkey;
		}

	{ 
		## Grab the user dump straight from
		## the Sirsi API.  You could also get
		## a file from your admin.
		local $/ = "*** DOCUMENT BOUNDARY ***";
		my(@users) = qx(seluser 2>NUL | dumpflatuser 2>NUL); 
		foreach my $user (@users){
			## Increment the user counter
			$usercount++;

			## Load the user information from the users file
			## If you store information in different fields,
			## this is the place to change it.


			## ID data
			## IMPORTANT: The cardnumber field must include
			## a unique identifier for your import to process correctly.
			my $cardnumber;
			my $borrowernumber;
			if ($user=~ m/^\n\.USER_ID\.\s+\|a([^\n]+)\n/){ #print STDOUT "$1,";
				$cardnumber = $1;}

			## Match the userid from the record to the
			## user key and use that key as the borrower number
			foreach my $userkey (@userkeys) {
				#print STDOUT $userkey;
				if ( $userkey=~ m/(\d+)\|(.+)\|\n/ ){
					#print STDOUT "ID:$2\n KEY:$1\n";
					if ($cardnumber eq $2) {
						$borrowernumber = $1;
			}	}	}



			## Name data
			my $surname;
			my $firstname;
			my $title;
			my $othernames;
			my $initials;

			## compare the supposed first and last names from the user name field
			## to see if there is a match in the usao student email address.  
			## Compare the order.  USAO emails are usually
			## firstname, possible intials, last name
			## sometimes they are
			## lastname, possible initials, two letters from the first name 
			## this is why we are matching against three or more characters.
			##  Not perfect (eg. first name "JO" or "YI" and it only catches
			## students), but hopefully we'll catch the rest later.
			if($user =~ m/\.USER_NAME\.\s+\|a([A-Z]{3,})\,\s+([A-Z]{3,}).+EMAIL.\s+\|astu\2[a-z]*\1\@usao.edu/is){
				$surname = $1;
				$firstname = $2;
			} elsif ($user =~ m/\.USER_NAME\.\s+\|a([A-Z]{3,})\,\s+([A-Z]{3,}).+EMAIL.\s+\|astu\1[a-z]*\2\@usao.edu/is){
				$surname = $2;
				$firstname = $1;

			## this is catching the rest later
			} elsif ($user=~ m/\.USER_NAME\.\s+\|a([^\n]+)/){
				my $fullname = $1;
				if ($fullname=~ m/,/){
					my @fullname = split(/, /,$fullname);
					$surname = $fullname[0];
					$firstname = $fullname[1];
				} else {
					my @fullname = split(' ',$fullname);
					$surname = $fullname[0];
					if ($fullname[2]){ $firstname =  $fullname[1] . ' ' . $fullname[2];} else {$firstname = $fullname[1];}
			}	}
		

			## DB data
			## IMPORTANT: Make sure the 'branchcode' and 'categorycode'
			## are valid entries in your database.
			my $branchcode = "NASH";
			my $categorycode;
			my $dateenrolled;
			my $dateexpiry;
			my $userid;
			my $password;
			my $gonenoaddress = "0";
			my $lost = "0";
			my $debarred = "0";

			##Get user status
			if($user =~ m/\.USER_STATUS\.\s+\|a([A-Z]+)/i){
				if (( $1 eq "BARRED" ) || ( $1 eq "BLOCKED" ) || ( $1 eq "DELINQUENT" )) { 
					$debarred = "1";
			}	}

			if($user =~ m/\.USER_PROFILE\.\s+\|a([A-Z]+)/i){
				if (( $1 eq "ADMIN" ) || ( $1 eq "CIRC" )) { $categorycode = "S"; # Koha Staff
				} elsif (( $1 eq "FACULTY" ) || ( $1 eq "STAFF")) { $categorycode = "T"; # Koha Teacher
				} elsif ( $1 eq "ILL") { $categorycode = "IL"; # Koha Interlibrary Loan
				} elsif ( $1 eq "LIBRARY") { $categorycode = "L"; # Koha Library
				} elsif ( $1 eq "PUBLIC") { $categorycode = "PT"; # Koha Patron
				} elsif ( $1 eq "STUDENT") { $categorycode = "ST"; # Koha Student
				## if they are banned or lost we'll set them as patrons
				## and set their debarred or lost card keys
				} elsif ( $1 eq "LOST" ) {
					$categorycode = "PT"; # Koha Patron
					$lost = "1";
				## These category codes need to be added to koha, because they aren't in the default install
				} elsif ( $1 eq "ALUMNI") { $categorycode = "AL"; # Alumni
				} elsif ( $1 eq "OKSHARE") { $categorycode = "OKS"; # Members of OKSHARE borrower agreement
				} elsif ( $1 eq "BANNED" ) {
					$categorycode = "BN"; # Permanantly forbidden from the library
					$debarred = "1";
				## Categories that don't need to go in koha
				#} elsif (( $1 eq "RESERVES" ) || ( $1 eq "SIRSI" ) || ( $1 eq "TEST" ) || ( $1 eq "WEBSERVER")) { print MYERRORFILE $user;
				} else {
					$categorycode = $1;} # leftovers?
				}

				## convert dates for user registration and expiration from YYYYMMDD to YYYY-MM-DD
			if($user =~ m/\.USER_PRIV_GRANTED\.\s+\|a([0-9]{4})([0-9]{2})([0-9]{2})/i){
				 $dateenrolled = $1 . "-" . $2 . "-" . $3;}

			if($user =~ m/\.USER_PRIV_EXPIRES\.\s+\|a([0-9]{4})([0-9]{2})([0-9]{2})/i){
				 $dateexpiry = $1 . "-" . $2 . "-" . $3;}

			## opac logins.  Right now I'm pulling from the Sirsi .USER_PIN. and ID, but that will change
			$userid = $cardnumber;
			if($user =~ m/\.USER_PIN\.\s+\|a(.+)/){
				 $password = $1;}

			## Address data
			my $streetnumber;
			my $streettype;
			my $address;
			my $address2;
			my $city;
			my $zipcode;
			my $email;
			my $phone;
			my $mobile;
			my $fax;
			my $emailpro;
			my $phonepro;


			## the following section for address 1 and 2 would be way less
			## redundant as a sub, but I was lazy and just copy/pasted
			if ($user =~ m/\.USER_ADDR1_BEGIN\.(.+)\.USER_ADDR1_END\./s){
				my $temp_first_address = $1;
				## capture the city, state info.  This is presented as city, state in the ils, so both should be in there
				## flag the address if it isn't there
				if ($temp_first_address=~ m/\.CITY\/STATE\.\s+\|a([^\n]+)/){
					$city = $1;
				} else { $gonenoaddress = "1"; }

				## capture zip code. flag the address if there is no zip code
				if ($temp_first_address=~ m/\.ZIP\.\s+\|a([^\n]+)/){
					$zipcode = $1;
				} else { $gonenoaddress = "1"; }

				## try to get the street address.  Flag if you can't
				if($temp_first_address =~ m/\.STREET\.\s+\|a(.+)/){
					$address = $1;

					## A street types
					if($address =~ m/\s(ALLEY|ALLEE|ALLY|ALY)(\.|,|\s|\n|$)/){
						$streettype = "ALY";
					} elsif($address =~ m/\s(ANNEX|ANEX|ANNX|ANX)(\.|,|\s|\n|$)/){
						$streettype = "ANX";
					} elsif($address =~ m/\s(ARCADE|ARC)(\.|,|\s|\n|$)/){
						$streettype = "ARC";
					} elsif($address =~ m/\s(AVENUE|AV|AVE|AVEN|AVENU|AVN|AVNUE)(\.|,|\s|\n|$)/){
						$streettype = "AVE";
					## B street types
					} elsif($address =~ m/\s(BAYOO|BAYOU|BYU)(\.|,|\s|\n|$)/){
						$streettype = "BYU";
					} elsif($address =~ m/\s(BEACH|BCH)(\.|,|\s|\n|$)/){
						$streettype = "BCH";
					} elsif($address =~ m/\s(BEND|BND)(\.|,|\s|\n|$)/){
						$streettype = "BND";
					} elsif($address =~ m/\s(BLUFF|BLUF|BLF)(\.|,|\s|\n|$)/){
						$streettype = "BLF";
					} elsif($address =~ m/\s(BLUFFS|BLFS)(\.|,|\s|\n|$)/){
						$streettype = "BLFS";
					} elsif($address =~ m/\s(BOTTOM|BTM)(\.|,|\s|\n|$)/){
						$streettype = "BTM";
					} elsif($address =~ m/\s(BOULEVARD|BLVD|BOUL|BOULV)(\.|,|\s|\n|$)/){
						$streettype = "BLVD";
					} elsif($address =~ m/\s(BRANCH|BR|BRNCH)(\.|,|\s|\n|$)/){
						$streettype = "BR";
					} elsif($address =~ m/\s(BRIDGE|BRDGE|BRG)(\.|,|\s|\n|$)/){
						$streettype = "BRG";
					} elsif($address =~ m/\s(BROOK|BRK)(\.|,|\s|\n|$)/){
						$streettype = "BRK";
					} elsif($address =~ m/\s(BROOKS|BRKS)(\.|,|\s|\n|$)/){
						$streettype = "BRKS";
					} elsif($address =~ m/\s(BURG|BG)(\.|,|\s|\n|$)/){
						$streettype = "BG";
					} elsif($address =~ m/\s(BURGS|BGS)(\.|,|\s|\n|$)/){
						$streettype = "BGS";
					} elsif($address =~ m/\s(BYPASS|BYP|BYPA|BYPAS|BYPS)(\.|,|\s|\n|$)/){
						$streettype = "BYP";
					## C street types
					} elsif($address =~ m/\s(CAMP|CMP|CP)(\.|,|\s|\n|$)/){
						$streettype = "CP";
					} elsif($address =~ m/\s(CANYON|CANYN|CNYN|CYN)(\.|,|\s|\n|$)/){
						$streettype = "CYN";
					} elsif($address =~ m/\s(CAPE|CPE)(\.|,|\s|\n|$)/){
						$streettype = "CPE";
					} elsif($address =~ m/\s(CAUSEWAY|CAUSWAY|CSWY)(\.|,|\s|\n|$)/){
						$streettype = "CSWY";
					} elsif($address =~ m/\s(CENTER|CEN|CENT|CENTR|CTR)(\.|,|\s|\n|$)/){
						$streettype = "CTR";
					} elsif($address =~ m/\s(CENTERS|CTRS)(\.|,|\s|\n|$)/){
						$streettype = "CTRS";
					} elsif($address =~ m/\s(CIRCLE|CIR|CIRC|CIRCL|CRCL|CRCLE|CIR)(\.|,|\s|\n|$)/){
						$streettype = "CIR";
					} elsif($address =~ m/\s(CIRCLES|CIRS)(\.|,|\s|\n|$)/){
						$streettype = "CIRS";
					} elsif($address =~ m/\s(CLIFF|CLF)(\.|,|\s|\n|$)/){
						$streettype = "CLF";
					} elsif($address =~ m/\s(CLIFFS|CLFS)(\.|,|\s|\n|$)/){
						$streettype = "CLFS";
					} elsif($address =~ m/\s(CLUB|CLB)(\.|,|\s|\n|$)/){
						$streettype = "CLB";
					} elsif($address =~ m/\s(COMMON|CMN)(\.|,|\s|\n|$)/){
						$streettype = "CMN";
					} elsif($address =~ m/\s(CORNER|COR)(\.|,|\s|\n|$)/){
						$streettype = "COR";
					} elsif($address =~ m/\s(CORNERS|CORS)(\.|,|\s|\n|$)/){
						$streettype = "CORS";
					} elsif($address =~ m/\s(COURSE|CRSE)(\.|,|\s|\n|$)/){
						$streettype = "CRSE";
					} elsif($address =~ m/\s(COURT|CRT|CT)(\.|,|\s|\n|$)/){
						$streettype = "CT";
					} elsif($address =~ m/\s(COURTS|CTS)(\.|,|\s|\n|$)/){
						$streettype = "CTS";
					} elsif($address =~ m/\s(COVE|CV)(\.|,|\s|\n|$)/){
						$streettype = "CV";
					} elsif($address =~ m/\s(COVES|CVS)(\.|,|\s|\n|$)/){
						$streettype = "CVS";
					} elsif($address =~ m/\s(CREEK|CK|CR|CRK)(\.|,|\s|\n|$)/){
						$streettype = "CRK";
					} elsif($address =~ m/\s(CRESCENT|CRECENT|CRES|CRESENT|CRSCNT|CRES)(\.|,|\s|\n|$)/){
						$streettype = "CRES";
					} elsif($address =~ m/\s(CREST|CRST)(\.|,|\s|\n|$)/){
						$streettype = "CRST";
					} elsif($address =~ m/\s(CROSSING|CRSSING|CRSSNG|XING)(\.|,|\s|\n|$)/){
						$streettype = "XING";
					} elsif($address =~ m/\s(CROSSROAD|XRD)(\.|,|\s|\n|$)/){
						$streettype = "XRD";
					} elsif($address =~ m/\s(CURVE|CURV)(\.|,|\s|\n|$)/){
						$streettype = "CURV";
					## D street types
					} elsif($address =~ m/\s(DALE|DL)(\.|,|\s|\n|$)/){
						$streettype = "DL";
					} elsif($address =~ m/\s(DAM|DM)(\.|,|\s|\n|$)/){
						$streettype = "DM";
					} elsif($address =~ m/\s(DIVIDE|DIV|DV|DVD)(\.|,|\s|\n|$)/){
						$streettype = "DV";
					} elsif($address =~ m/\s(DRIVE|DR|DRIV|DRV)(\.|,|\s|\n|$)/){
						$streettype = "DR";
					} elsif($address =~ m/\s(DRIVES|DRS)(\.|,|\s|\n|$)/){
						$streettype = "DRS";
					## E street types
					} elsif($address =~ m/\s(ESTATE|EST)(\.|,|\s|\n|$)/){
						$streettype = "EST";
					} elsif($address =~ m/\s(ESTATES|ESTS)(\.|,|\s|\n|$)/){
						$streettype = "ESTS";
					} elsif($address =~ m/\s(EXPRESSWAY|EXP|EXPR|EXPRESS|EXPW|EXPY)(\.|,|\s|\n|$)/){
						$streettype = "EXPY";
					} elsif($address =~ m/\s(EXTENSION|EXT|EXTN|EXTNSN)(\.|,|\s|\n|$)/){
						$streettype = "EXT";
					} elsif($address =~ m/\s(EXTENSIONS|EXTS)(\.|,|\s|\n|$)/){
						$streettype = "EXTS";
					## F street types
					} elsif($address =~ m/\s(FALL)(\.|,|\s|\n|$)/){
						$streettype = "FALL";
					} elsif($address =~ m/\s(FALLS|FLS)(\.|,|\s|\n|$)/){
						$streettype = "FLS";
					} elsif($address =~ m/\s(FERRY|FRRY|FRY)(\.|,|\s|\n|$)/){
						$streettype = "FRY";
					} elsif($address =~ m/\s(FIELD|FLD)(\.|,|\s|\n|$)/){
						$streettype = "FLD";
					} elsif($address =~ m/\s(FIELDS|FLDS)(\.|,|\s|\n|$)/){
						$streettype = "FLDS";
					} elsif($address =~ m/\s(FLAT|FLT)(\.|,|\s|\n|$)/){
						$streettype = "FLT";
					} elsif($address =~ m/\s(FLATS|FLTS)(\.|,|\s|\n|$)/){
						$streettype = "FLTS";
					} elsif($address =~ m/\s(FORD|FRD)(\.|,|\s|\n|$)/){
						$streettype = "FRD";
					} elsif($address =~ m/\s(FORDS|FRDS)(\.|,|\s|\n|$)/){
						$streettype = "FRDS";
					} elsif($address =~ m/\s(FOREST|FRST|FORESTS)(\.|,|\s|\n|$)/){
						$streettype = "FRST";
					} elsif($address =~ m/\s(FORGE|FORG|FRG)(\.|,|\s|\n|$)/){
						$streettype = "FRG";
					} elsif($address =~ m/\s(FORGES|FRGS)(\.|,|\s|\n|$)/){
						$streettype = "FRGS";
					} elsif($address =~ m/\s(FORK|FRK)(\.|,|\s|\n|$)/){
						$streettype = "FRK";
					} elsif($address =~ m/\s(FORKS|FRKS)(\.|,|\s|\n|$)/){
						$streettype = "FRKS";
					} elsif($address =~ m/\s(FORT|FRT|FT)(\.|,|\s|\n|$)/){
						$streettype = "FT";
					} elsif($address =~ m/\s(FREEWAY|FREEWY|FRWAY|FRWY|FWY)(\.|,|\s|\n|$)/){
						$streettype = "FWY";
					## G street types
					} elsif($address =~ m/\s(GARDEN|GARDN|GDN|GRDN)(\.|,|\s|\n|$)/){
						$streettype = "GDN";
					} elsif($address =~ m/\s(GARDENS|GDNS|GRDNS)(\.|,|\s|\n|$)/){
						$streettype = "GDNS";
					} elsif($address =~ m/\s(GATEWAY|GATEWY|GATWAY|GTWAY|GTWY)(\.|,|\s|\n|$)/){
						$streettype = "GTWY";
					} elsif($address =~ m/\s(GLEN|GLN)(\.|,|\s|\n|$)/){
						$streettype = "GLN";
					} elsif($address =~ m/\s(GLENS|GLNS)(\.|,|\s|\n|$)/){
						$streettype = "GLNS";
					} elsif($address =~ m/\s(GREEN|GRN)(\.|,|\s|\n|$)/){
						$streettype = "GRN";
					} elsif($address =~ m/\s(GREENS|GRNS)(\.|,|\s|\n|$)/){
						$streettype = "GRNS";
					} elsif($address =~ m/\s(GROVE|GRV)(\.|,|\s|\n|$)/){
						$streettype = "GRV";
					} elsif($address =~ m/\s(GROVES|GRVS)(\.|,|\s|\n|$)/){
						$streettype = "GRVS";
					## H street types
					} elsif($address =~ m/\s(HARBOR|HARB|HARBR|HBRHRBOR)(\.|,|\s|\n|$)/){
						$streettype = "HBR";
					} elsif($address =~ m/\s(HARBORS|HBRS)(\.|,|\s|\n|$)/){
						$streettype = "HBRS";
					} elsif($address =~ m/\s(HAVEN|HAVN|HVN)(\.|,|\s|\n|$)/){
						$streettype = "HVN";
					} elsif($address =~ m/\s(HEIGHTS|HEIGHT|HGTS|HT|HTS)(\.|,|\s|\n|$)/){
						$streettype = "HTS";
					} elsif($address =~ m/\s(HIGHWAY|HIGHWY|HIWAY|HIWY|HWAY|HWY)(\.|,|\s|\n|$)/){
						$streettype = "HWY";
					} elsif($address =~ m/\s(HILL|HL)(\.|,|\s|\n|$)/){
						$streettype = "HL";
					} elsif($address =~ m/\s(HILLS|HLS)(\.|,|\s|\n|$)/){
						$streettype = "HLS";
					} elsif($address =~ m/\s(HOLLOW|HLLW|HOLLOWS|HOLW|HOLWS)(\.|,|\s|\n|$)/){
						$streettype = "HOLW";
					## I street types
					} elsif($address =~ m/\s(INLET|INLT)(\.|,|\s|\n|$)/){
						$streettype = "INLT";
					} elsif($address =~ m/\s(ISLAND|IS|ISLND)(\.|,|\s|\n|$)/){
						$streettype = "IS";
					} elsif($address =~ m/\s(ISLANDS|ISLNDS|ISS)(\.|,|\s|\n|$)/){
						$streettype = "ISS";
					} elsif($address =~ m/\s(ISLE|ISLES)(\.|,|\s|\n|$)/){
						$streettype = "ISLE";
					## J street types
					} elsif($address =~ m/\s(JUNCTION|JCT|JCTION|JCTN|JUNCTN|JUNCTON)(\.|,|\s|\n|$)/){
						$streettype = "JCT";
					} elsif($address =~ m/\s(JUNCTIONS|JCTNS|JCTS)(\.|,|\s|\n|$)/){
						$streettype = "JCTS";
					## K street types
					} elsif($address =~ m/\s(KEY|KY)(\.|,|\s|\n|$)/){
						$streettype = "KY";
					} elsif($address =~ m/\s(KEYS|KYS)(\.|,|\s|\n|$)/){
						$streettype = "KYS";
					} elsif($address =~ m/\s(KNOLL|KNOL|KNL)(\.|,|\s|\n|$)/){
						$streettype = "KNL";
					} elsif($address =~ m/\s(KNOLLS|KNLS)(\.|,|\s|\n|$)/){
						$streettype = "KNLS";
					## L street types
					} elsif($address =~ m/\s(LAKE|LK)(\.|,|\s|\n|$)/){
						$streettype = "LK";
					} elsif($address =~ m/\s(LAKES|LKS)(\.|,|\s|\n|$)/){
						$streettype = "LKS";
					} elsif($address =~ m/\s(LAND)(\.|,|\s|\n|$)/){
						$streettype = "LAND";
					} elsif($address =~ m/\s(LANDING|LNDG|LNDNG)(\.|,|\s|\n|$)/){
						$streettype = "LNDG";
					} elsif($address =~ m/\s(LANE|LA|LANES|LN)(\.|,|\s|\n|$)/){
						$streettype = "LN";
					} elsif($address =~ m/\s(LIGHT|LGT)(\.|,|\s|\n|$)/){
						$streettype = "LGT";
					} elsif($address =~ m/\s(LIGHTS|LGTS)(\.|,|\s|\n|$)/){
						$streettype = "LGTS";
					} elsif($address =~ m/\s(LOAF|LF)(\.|,|\s|\n|$)/){
						$streettype = "LF";
					} elsif($address =~ m/\s(LOCK|LCK)(\.|,|\s|\n|$)/){
						$streettype = "LCK";
					} elsif($address =~ m/\s(LOCKS|LCKS)(\.|,|\s|\n|$)/){
						$streettype = "LCKS";
					} elsif($address =~ m/\s(LODGE|LDG|LODG)(\.|,|\s|\n|$)/){
						$streettype = "LDG";
					} elsif($address =~ m/\s(LOOP|LOOPS)(\.|,|\s|\n|$)/){
						$streettype = "LOOP";
					## M street types
					} elsif($address =~ m/\s(MALL)(\.|,|\s|\n|$)/){
						$streettype = "MALL";
					} elsif($address =~ m/\s(MANOR|MNR)(\.|,|\s|\n|$)/){
						$streettype = "MNR";
					} elsif($address =~ m/\s(MANORS|MNRS)(\.|,|\s|\n|$)/){
						$streettype = "MNRS";
					} elsif($address =~ m/\s(MEADOW|MDW)(\.|,|\s|\n|$)/){
						$streettype = "MDW";
					} elsif($address =~ m/\s(MEADOWS|MDWS|MEDOWS)(\.|,|\s|\n|$)/){
						$streettype = "MDWS";
					} elsif($address =~ m/\s(MEWS)(\.|,|\s|\n|$)/){
						$streettype = "MEWS";
					} elsif($address =~ m/\s(MILL|ML)(\.|,|\s|\n|$)/){
						$streettype = "ML";
					} elsif($address =~ m/\s(MILLS|MLS)(\.|,|\s|\n|$)/){
						$streettype = "MLS";
					} elsif($address =~ m/\s(MISSION|MISSN|MSN|MSSN)(\.|,|\s|\n|$)/){
						$streettype = "MSN";
					} elsif($address =~ m/\s(MOTORWAY|MTWY)(\.|,|\s|\n|$)/){
						$streettype = "MTWY";
					} elsif($address =~ m/\s(MOUNT|MNT|MT)(\.|,|\s|\n|$)/){
						$streettype = "MT";
					} elsif($address =~ m/\s(MOUNTAIN|MNTAIN|MNTN|MOUNTIN|MTIN|MTN)(\.|,|\s|\n|$)/){
						$streettype = "MTN";
					} elsif($address =~ m/\s(MOUNTAINS|MNTNS|MTNS)(\.|,|\s|\n|$)/){
						$streettype = "MTNS";
					## N street types
					} elsif($address =~ m/\s(NECK|NCK)(\.|,|\s|\n|$)/){
						$streettype = "NCK";
					## O street types
					} elsif($address =~ m/\s(ORCHARD|ORCH|ORCHRD)(\.|,|\s|\n|$)/){
						$streettype = "ORCH";
					} elsif($address =~ m/\s(OVAL|OVL)(\.|,|\s|\n|$)/){
						$streettype = "OVL";
					} elsif($address =~ m/\s(OVERPASS|OPAS)(\.|,|\s|\n|$)/){
						$streettype = "OPAS";
					## P street types
					} elsif($address =~ m/\s(PARK|PK|PRK|PARKS)(\.|,|\s|\n|$)/){
						$streettype = "PARK";
					} elsif($address =~ m/\s(PARKWAY|PARKWY|PKWAY|PKWY|PKY|PARKWAYS|PKWYS)(\.|,|\s|\n|$)/){
						$streettype = "PKWY";
					} elsif($address =~ m/\s(PASS)(\.|,|\s|\n|$)/){
						$streettype = "PASS";
					} elsif($address =~ m/\s(PASSAGE|PSGE)(\.|,|\s|\n|$)/){
						$streettype = "PSGE";
					} elsif($address =~ m/\s(PATH|PATHS)(\.|,|\s|\n|$)/){
						$streettype = "PATH";
					} elsif($address =~ m/\s(PIKE|PIKES)(\.|,|\s|\n|$)/){
						$streettype = "PIKE";
					} elsif($address =~ m/\s(PINE|PNE)(\.|,|\s|\n|$)/){
						$streettype = "PNE";
					} elsif($address =~ m/\s(PINES|PNES)(\.|,|\s|\n|$)/){
						$streettype = "PNES";
					} elsif($address =~ m/\s(PLACE|PL)(\.|,|\s|\n|$)/){
						$streettype = "PL";
					} elsif($address =~ m/\s(PLAIN|PLN)(\.|,|\s|\n|$)/){
						$streettype = "PLN";
					} elsif($address =~ m/\s(PLAINS|PLAINES|PLNS)(\.|,|\s|\n|$)/){
						$streettype = "PLNS";
					} elsif($address =~ m/\s(PLAZA|PLZ|PLZA)(\.|,|\s|\n|$)/){
						$streettype = "PLZ";
					} elsif($address =~ m/\s(POINT|PT)(\.|,|\s|\n|$)/){
						$streettype = "PT";
					} elsif($address =~ m/\s(POINTS|PTS)(\.|,|\s|\n|$)/){
						$streettype = "PTS";
					} elsif($address =~ m/\s(PORT|PRT)(\.|,|\s|\n|$)/){
						$streettype = "PRT";
					} elsif($address =~ m/\s(PORTS|PRTS)(\.|,|\s|\n|$)/){
						$streettype = "PRTS";
					} elsif($address =~ m/\s(PRARIE|PR|PRARIE|PRR)(\.|,|\s|\n|$)/){
						$streettype = "PR";
					## R street types
					} elsif($address =~ m/\s(RADIAL|RADIEL|RADL)(\.|,|\s|\n|$)/){
						$streettype = "RADL";
					} elsif($address =~ m/\s(RAMP)(\.|,|\s|\n|$)/){
						$streettype = "RAMP";
					} elsif($address =~ m/\s(RANCH|RANCHES|RNCH|RNCHS)(\.|,|\s|\n|$)/){
						$streettype = "RNCH";
					} elsif($address =~ m/\s(RAPID|RPD)(\.|,|\s|\n|$)/){
						$streettype = "RPD";
					} elsif($address =~ m/\s(RAPIDS|RPDS)(\.|,|\s|\n|$)/){
						$streettype = "RPDS";
					} elsif($address =~ m/\s(REST|RST)(\.|,|\s|\n|$)/){
						$streettype = "RST";
					} elsif($address =~ m/\s(RIDGE|RDG|RDGE)(\.|,|\s|\n|$)/){
						$streettype = "RDG";
					} elsif($address =~ m/\s(RIDGES|RDGS)(\.|,|\s|\n|$)/){
						$streettype = "RDGS";
					} elsif($address =~ m/\s(RIVER|RIV|RIVR|RVR)(\.|,|\s|\n|$)/){
						$streettype = "RIV";
					} elsif($address =~ m/\s(ROAD|RD)(\.|,|\s|\n|$)/){
						$streettype = "RD";
					} elsif($address =~ m/\s(ROADS|RDS)(\.|,|\s|\n|$)/){
						$streettype = "RDS";
					} elsif($address =~ m/\s(ROUTE|RTE)(\.|,|\s|\n|$)/){
						$streettype = "RTE";
					} elsif($address =~ m/\s(ROW)(\.|,|\s|\n|$)/){
						$streettype = "ROW";
					} elsif($address =~ m/\s(RUE)(\.|,|\s|\n|$)/){
						$streettype = "RUE";
					} elsif($address =~ m/\s(RUN)(\.|,|\s|\n|$)/){
						$streettype = "RUN";
					## S street types
					} elsif($address =~ m/\s(SHOAL|SHL)(\.|,|\s|\n|$)/){
						$streettype = "SHL";
					} elsif($address =~ m/\s(SHOALS|SHLS)(\.|,|\s|\n|$)/){
						$streettype = "SHLS";
					} elsif($address =~ m/\s(SHORE|SHOAR|SHR)(\.|,|\s|\n|$)/){
						$streettype = "SHR";
					} elsif($address =~ m/\s(SHORES|SHOARS|SHRS)(\.|,|\s|\n|$)/){
						$streettype = "SHRS";
					} elsif($address =~ m/\s(SKYWAY|SKWY)(\.|,|\s|\n|$)/){
						$streettype = "SKWY";
					} elsif($address =~ m/\s(SPRING|SPG|SPNG|SPRNG)(\.|,|\s|\n|$)/){
						$streettype = "SPG";
					} elsif($address =~ m/\s(SPRINGS|SPGS|SPNGS)(\.|,|\s|\n|$)/){
						$streettype = "SPGS";
					} elsif($address =~ m/\s(SPUR|SPURS)(\.|,|\s|\n|$)/){
						$streettype = "SPUR";
					} elsif($address =~ m/\s(SQUARE|SQ|SQR|SQRE|SQU)(\.|,|\s|\n|$)/){
						$streettype = "SQ";
					} elsif($address =~ m/\s(SQUARES|SQRS|SQS)(\.|,|\s|\n|$)/){
						$streettype = "SQS";
					} elsif($address =~ m/\s(STATION|STA|STATN|STN)(\.|,|\s|\n|$)/){
						$streettype = "STA";
					} elsif($address =~ m/\s(STRAVENUE|STRA|STRAV|STRAVE|STRAVEN|STRAVN|STRVN|STRVNUE)(\.|,|\s|\n|$)/){
						$streettype = "STRA";
					} elsif($address =~ m/\s(STREAM|STRM)(\.|,|\s|\n|$)/){
						$streettype = "STRM";
					} elsif($address =~ m/\s(STREET|ST|STR|STRT)(\.|,|\s|\n|$)/){
						$streettype = "ST";
					} elsif($address =~ m/\s(STREETS|STS)(\.|,|\s|\n|$)/){
						$streettype = "STS";
					} elsif($address =~ m/\s(SUMMIT|SMT|SUMIT|SUMITT)(\.|,|\s|\n|$)/){
						$streettype = "SMT";
					## T road types
					} elsif($address =~ m/\s(TERRACE|TER|TERR)(\.|,|\s|\n|$)/){
						$streettype = "TER";
					} elsif($address =~ m/\s(THROUGHWAY|TRWY)(\.|,|\s|\n|$)/){
						$streettype = "TRWY";
					} elsif($address =~ m/\s(TRACE|TRACES|TRCE)(\.|,|\s|\n|$)/){
						$streettype = "TRCE";
					} elsif($address =~ m/\s(TRACK|TRACKS|TRAK|TRK|TRKS)(\.|,|\s|\n|$)/){
						$streettype = "TRAK";
					} elsif($address =~ m/\s(TRAFFICWAY|TRFY)(\.|,|\s|\n|$)/){
						$streettype = "TRFY";
					} elsif($address =~ m/\s(TRAIL|TR|TRAILS|TRL|TRLS)(\.|,|\s|\n|$)/){
						$streettype = "TRL";
					} elsif($address =~ m/\s(TUNNEL|TUNEL|TUNL|TUNLS|TUNNELS|TUNNL)(\.|,|\s|\n|$)/){
						$streettype = "TUNL";
					} elsif($address =~ m/\s(TURNPIKE|TPK|TPKE|TRNPK|TRPK|TURNPK)(\.|,|\s|\n|$)/){
						$streettype = "TPKE";
					## U road types
					} elsif($address =~ m/\s(UNDERPASS|UPAS)(\.|,|\s|\n|$)/){
						$streettype = "UPAS";
					} elsif($address =~ m/\s(UNION|UN)(\.|,|\s|\n|$)/){
						$streettype = "UN";
					} elsif($address =~ m/\s(UNIONS|UNS)(\.|,|\s|\n|$)/){
						$streettype = "UNS";
					## V road types
					} elsif($address =~ m/\s(VALLEY|VALLY|VLLY|VLY)(\.|,|\s|\n|$)/){
						$streettype = "VLY";
					} elsif($address =~ m/\s(VALLEYS|VLYS)(\.|,|\s|\n|$)/){
						$streettype = "VLYS";
					} elsif($address =~ m/\s(VIADUCT|VDCT|VIA|VIADCT)(\.|,|\s|\n|$)/){
						$streettype = "VIA";
					} elsif($address =~ m/\s(VIEW|VW)(\.|,|\s|\n|$)/){
						$streettype = "VW";
					} elsif($address =~ m/\s(VIEWS|VWS)(\.|,|\s|\n|$)/){
						$streettype = "VWS";
					} elsif($address =~ m/\s(VILLAGE|VILL|VILLAG|VILLG|VILLIAGE|VLG)(\.|,|\s|\n|$)/){
						$streettype = "VLG";
					} elsif($address =~ m/\s(VILLAGES|VLGS)(\.|,|\s|\n|$)/){
						$streettype = "VLGS";
					} elsif($address =~ m/\s(VILLE|VL)(\.|,|\s|\n|$)/){
						$streettype = "VL";
					} elsif($address =~ m/\s(VISTA|VIS|VIST|VST|VSTA)(\.|,|\s|\n|$)/){
						$streettype = "VIS";
					## W road types
					} elsif($address =~ m/\s(WALK|WALKS)(\.|,|\s|\n|$)/){
						$streettype = "WALK";
					} elsif($address =~ m/\s(WALL)(\.|,|\s|\n|$)/){
						$streettype = "WALL";
					} elsif($address =~ m/\s(WAY|WY)(\.|,|\s|\n|$)/){
						$streettype = "WAY";
					} elsif($address =~ m/\s(WAYS)(\.|,|\s|\n|$)/){
						$streettype = "WAYS";
					} elsif($address =~ m/\s(WELL|WL)(\.|,|\s|\n|$)/){
						$streettype = "WL";
					} elsif($address =~ m/\s(WELLS|WLS)(\.|,|\s|\n|$)/){
						$streettype = "WLS";
					}
				} else {
					$gonenoaddress = "1"; 
				}
			}

			## If it's a usao email address, put it in the work
			## email field, otherwise use the regular field
			while ($user =~ m/\.EMAIL\.\s+\|a([^@\n]+)\@([^.\n]+)\.([^.\n]+)\n/g){
				my $name = $1;
				my $domain = $2;
				my $tld = $3;
				if ( $name && ( $domain eq "usao" ) && ( $tld eq "edu" )) {
					$emailpro = $name . '@' . $domain . '.' . $tld;}
				if ( $name && ( $domain ne "usao" ) && ( $tld ne "edu" )) {
					$email =  $name . '@' . $domain . '.' . $tld;
			}	}

			## capture phone numbers.  Sirsi Homephone goes to phone, dayphone goes to work phone (phonepro)
			if ($user=~ m/\.HOMEPHONE\.\s+\|a([^\n]+)/){
				if ($1 ne '**REQUIRED FIELD**') {
					$phone = $1; } }
			if ($user=~ m/\.DAYPHONE\.\s+\|a([^\n]+)/){
				if ($1 ne '**REQUIRED FIELD**') {
					$phonepro = $1; } }
	
			## Additional address data
			my $B_streetnumber;
			my $B_streettype;
			my $B_address;
			my $B_city;
			my $B_zipcode;
			my $B_email;
			my $B_phone;
			my $altcontactfirstname;
			my $altcontactsurname;
			my $altcontactaddress1;
			my $altcontactaddress2;
			my $altcontactaddress3;
			my $altcontactzipcode;
			my $altcontactphone;
			my $smsalertnumber;
			my $contactname;
			my $contactfirstname;
			my $contacttitle;

			## if the zipcode in address 2 is different than one, but it in the B_address fields for koha
			if ($user =~ m/\.USER_ADDR2_BEGIN\.(.+)\.USER_ADDR2_END\./s){
				my $temp_second_address = $1;
				## capture zip code
				if ($temp_second_address=~ m/\.ZIP\.\s+\|a([^\n]+)/){
					if ( $1 ne $zipcode ) {
						$B_zipcode = $1; 

						## capture the city, state info.  This is presented as city, state in the ils, so both should be in there
						if ($temp_second_address=~ m/\.CITY\/STATE\.\s+\|a([^\n]+)/){
							$B_city = $1; }	

						## This is pretty dumb.  It should be in a subroutine since it is
						## nearly identical to what we are doing with address 1
						if($temp_second_address =~ m/\.STREET\.\s+\|a(.+)/){
							$B_address = $1;
							## A street types
							if($B_address =~ m/\s(ALLEY|ALLEE|ALLY|ALY)(\.|,|\s|\n|$)/){
								$B_streettype = "ALY";
							} elsif($B_address =~ m/\s(ANNEX|ANEX|ANNX|ANX)(\.|,|\s|\n|$)/){
								$B_streettype = "ANX";
							} elsif($B_address =~ m/\s(ARCADE|ARC)(\.|,|\s|\n|$)/){
								$B_streettype = "ARC";
							} elsif($B_address =~ m/\s(AVENUE|AV|AVE|AVEN|AVENU|AVN|AVNUE)(\.|,|\s|\n|$)/){
								$B_streettype = "AVE";
							## B street types
							} elsif($B_address =~ m/\s(BAYOO|BAYOU|BYU)(\.|,|\s|\n|$)/){
								$B_streettype = "BYU";
							} elsif($B_address =~ m/\s(BEACH|BCH)(\.|,|\s|\n|$)/){
								$B_streettype = "BCH";
							} elsif($B_address =~ m/\s(BEND|BND)(\.|,|\s|\n|$)/){
								$B_streettype = "BND";
							} elsif($B_address =~ m/\s(BLUFF|BLUF|BLF)(\.|,|\s|\n|$)/){
								$B_streettype = "BLF";
							} elsif($B_address =~ m/\s(BLUFFS|BLFS)(\.|,|\s|\n|$)/){
								$B_streettype = "BLFS";
							} elsif($B_address =~ m/\s(BOTTOM|BTM)(\.|,|\s|\n|$)/){
								$B_streettype = "BTM";
							} elsif($B_address =~ m/\s(BOULEVARD|BLVD|BOUL|BOULV)(\.|,|\s|\n|$)/){
								$B_streettype = "BLVD";
							} elsif($B_address =~ m/\s(BRANCH|BR|BRNCH)(\.|,|\s|\n|$)/){
								$B_streettype = "BR";
							} elsif($B_address =~ m/\s(BRIDGE|BRDGE|BRG)(\.|,|\s|\n|$)/){
								$B_streettype = "BRG";
							} elsif($B_address =~ m/\s(BROOK|BRK)(\.|,|\s|\n|$)/){
								$B_streettype = "BRK";
							} elsif($B_address =~ m/\s(BROOKS|BRKS)(\.|,|\s|\n|$)/){
								$B_streettype = "BRKS";
							} elsif($B_address =~ m/\s(BURG|BG)(\.|,|\s|\n|$)/){
								$B_streettype = "BG";
							} elsif($B_address =~ m/\s(BURGS|BGS)(\.|,|\s|\n|$)/){
								$B_streettype = "BGS";
							} elsif($B_address =~ m/\s(BYPASS|BYP|BYPA|BYPAS|BYPS)(\.|,|\s|\n|$)/){
								$B_streettype = "BYP";
							## C street types
							} elsif($B_address =~ m/\s(CAMP|CMP|CP)(\.|,|\s|\n|$)/){
								$B_streettype = "CP";
							} elsif($B_address =~ m/\s(CANYON|CANYN|CNYN|CYN)(\.|,|\s|\n|$)/){
								$B_streettype = "CYN";
							} elsif($B_address =~ m/\s(CAPE|CPE)(\.|,|\s|\n|$)/){
								$B_streettype = "CPE";
							} elsif($B_address =~ m/\s(CAUSEWAY|CAUSWAY|CSWY)(\.|,|\s|\n|$)/){
								$B_streettype = "CSWY";
							} elsif($B_address =~ m/\s(CENTER|CEN|CENT|CENTR|CTR)(\.|,|\s|\n|$)/){
								$B_streettype = "CTR";
							} elsif($B_address =~ m/\s(CENTERS|CTRS)(\.|,|\s|\n|$)/){
								$B_streettype = "CTRS";
							} elsif($B_address =~ m/\s(CIRCLE|CIR|CIRC|CIRCL|CRCL|CRCLE|CIR)(\.|,|\s|\n|$)/){
								$B_streettype = "CIR";
							} elsif($B_address =~ m/\s(CIRCLES|CIRS)(\.|,|\s|\n|$)/){
								$B_streettype = "CIRS";
							} elsif($B_address =~ m/\s(CLIFF|CLF)(\.|,|\s|\n|$)/){
								$B_streettype = "CLF";
							} elsif($B_address =~ m/\s(CLIFFS|CLFS)(\.|,|\s|\n|$)/){
								$B_streettype = "CLFS";
							} elsif($B_address =~ m/\s(CLUB|CLB)(\.|,|\s|\n|$)/){
								$B_streettype = "CLB";
							} elsif($B_address =~ m/\s(COMMON|CMN)(\.|,|\s|\n|$)/){
								$B_streettype = "CMN";
							} elsif($B_address =~ m/\s(CORNER|COR)(\.|,|\s|\n|$)/){
								$B_streettype = "COR";
							} elsif($B_address =~ m/\s(CORNERS|CORS)(\.|,|\s|\n|$)/){
								$B_streettype = "CORS";
							} elsif($B_address =~ m/\s(COURSE|CRSE)(\.|,|\s|\n|$)/){
								$B_streettype = "CRSE";
							} elsif($B_address =~ m/\s(COURT|CRT|CT)(\.|,|\s|\n|$)/){
								$B_streettype = "CT";
							} elsif($B_address =~ m/\s(COURTS|CTS)(\.|,|\s|\n|$)/){
								$B_streettype = "CTS";
							} elsif($B_address =~ m/\s(COVE|CV)(\.|,|\s|\n|$)/){
								$B_streettype = "CV";
							} elsif($B_address =~ m/\s(COVES|CVS)(\.|,|\s|\n|$)/){
								$B_streettype = "CVS";
							} elsif($B_address =~ m/\s(CREEK|CK|CR|CRK)(\.|,|\s|\n|$)/){
								$B_streettype = "CRK";
							} elsif($B_address =~ m/\s(CRESCENT|CRECENT|CRES|CRESENT|CRSCNT|CRES)(\.|,|\s|\n|$)/){
								$B_streettype = "CRES";
							} elsif($B_address =~ m/\s(CREST|CRST)(\.|,|\s|\n|$)/){
								$B_streettype = "CRST";
							} elsif($B_address =~ m/\s(CROSSING|CRSSING|CRSSNG|XING)(\.|,|\s|\n|$)/){
								$B_streettype = "XING";
							} elsif($B_address =~ m/\s(CROSSROAD|XRD)(\.|,|\s|\n|$)/){
								$B_streettype = "XRD";
							} elsif($B_address =~ m/\s(CURVE|CURV)(\.|,|\s|\n|$)/){
								$B_streettype = "CURV";
							## D street types
							} elsif($B_address =~ m/\s(DALE|DL)(\.|,|\s|\n|$)/){
								$B_streettype = "DL";
							} elsif($B_address =~ m/\s(DAM|DM)(\.|,|\s|\n|$)/){
								$B_streettype = "DM";
							} elsif($B_address =~ m/\s(DIVIDE|DIV|DV|DVD)(\.|,|\s|\n|$)/){
								$B_streettype = "DV";
							} elsif($B_address =~ m/\s(DRIVE|DR|DRIV|DRV)(\.|,|\s|\n|$)/){
								$B_streettype = "DR";
							} elsif($B_address =~ m/\s(DRIVES|DRS)(\.|,|\s|\n|$)/){
								$B_streettype = "DRS";
							## E street types
							} elsif($B_address =~ m/\s(ESTATE|EST)(\.|,|\s|\n|$)/){
								$B_streettype = "EST";
							} elsif($B_address =~ m/\s(ESTATES|ESTS)(\.|,|\s|\n|$)/){
								$B_streettype = "ESTS";
							} elsif($B_address =~ m/\s(EXPRESSWAY|EXP|EXPR|EXPRESS|EXPW|EXPY)(\.|,|\s|\n|$)/){
								$B_streettype = "EXPY";
							} elsif($B_address =~ m/\s(EXTENSION|EXT|EXTN|EXTNSN)(\.|,|\s|\n|$)/){
								$B_streettype = "EXT";
							} elsif($B_address =~ m/\s(EXTENSIONS|EXTS)(\.|,|\s|\n|$)/){
								$B_streettype = "EXTS";
							## F street types
							} elsif($B_address =~ m/\s(FALL)(\.|,|\s|\n|$)/){
								$B_streettype = "FALL";
							} elsif($B_address =~ m/\s(FALLS|FLS)(\.|,|\s|\n|$)/){
								$B_streettype = "FLS";
							} elsif($B_address =~ m/\s(FERRY|FRRY|FRY)(\.|,|\s|\n|$)/){
								$B_streettype = "FRY";
							} elsif($B_address =~ m/\s(FIELD|FLD)(\.|,|\s|\n|$)/){
								$B_streettype = "FLD";
							} elsif($B_address =~ m/\s(FIELDS|FLDS)(\.|,|\s|\n|$)/){
								$B_streettype = "FLDS";
							} elsif($B_address =~ m/\s(FLAT|FLT)(\.|,|\s|\n|$)/){
								$B_streettype = "FLT";
							} elsif($B_address =~ m/\s(FLATS|FLTS)(\.|,|\s|\n|$)/){
								$B_streettype = "FLTS";
							} elsif($B_address =~ m/\s(FORD|FRD)(\.|,|\s|\n|$)/){
								$B_streettype = "FRD";
							} elsif($B_address =~ m/\s(FORDS|FRDS)(\.|,|\s|\n|$)/){
								$B_streettype = "FRDS";
							} elsif($B_address =~ m/\s(FOREST|FRST|FORESTS)(\.|,|\s|\n|$)/){
								$B_streettype = "FRST";
							} elsif($B_address =~ m/\s(FORGE|FORG|FRG)(\.|,|\s|\n|$)/){
								$B_streettype = "FRG";
							} elsif($B_address =~ m/\s(FORGES|FRGS)(\.|,|\s|\n|$)/){
								$B_streettype = "FRGS";
							} elsif($B_address =~ m/\s(FORK|FRK)(\.|,|\s|\n|$)/){
								$B_streettype = "FRK";	
							} elsif($B_address =~ m/\s(FORKS|FRKS)(\.|,|\s|\n|$)/){
								$B_streettype = "FRKS";
							} elsif($B_address =~ m/\s(FORT|FRT|FT)(\.|,|\s|\n|$)/){
								$B_streettype = "FT";
							} elsif($B_address =~ m/\s(FREEWAY|FREEWY|FRWAY|FRWY|FWY)(\.|,|\s|\n|$)/){
								$B_streettype = "FWY";
							## G street types
							} elsif($B_address =~ m/\s(GARDEN|GARDN|GDN|GRDN)(\.|,|\s|\n|$)/){
								$B_streettype = "GDN";
							} elsif($B_address =~ m/\s(GARDENS|GDNS|GRDNS)(\.|,|\s|\n|$)/){
								$B_streettype = "GDNS";
							} elsif($B_address =~ m/\s(GATEWAY|GATEWY|GATWAY|GTWAY|GTWY)(\.|,|\s|\n|$)/){
								$B_streettype = "GTWY";
							} elsif($B_address =~ m/\s(GLEN|GLN)(\.|,|\s|\n|$)/){
								$B_streettype = "GLN";
							} elsif($B_address =~ m/\s(GLENS|GLNS)(\.|,|\s|\n|$)/){
								$B_streettype = "GLNS";
							} elsif($B_address =~ m/\s(GREEN|GRN)(\.|,|\s|\n|$)/){
								$B_streettype = "GRN";
							} elsif($B_address =~ m/\s(GREENS|GRNS)(\.|,|\s|\n|$)/){
								$B_streettype = "GRNS";
							} elsif($B_address =~ m/\s(GROVE|GRV)(\.|,|\s|\n|$)/){
								$B_streettype = "GRV";
							} elsif($B_address =~ m/\s(GROVES|GRVS)(\.|,|\s|\n|$)/){
								$B_streettype = "GRVS";
							## H street types
							} elsif($B_address =~ m/\s(HARBOR|HARB|HARBR|HBRHRBOR)(\.|,|\s|\n|$)/){
								$B_streettype = "HBR";
							} elsif($B_address =~ m/\s(HARBORS|HBRS)(\.|,|\s|\n|$)/){
								$B_streettype = "HBRS";
							} elsif($B_address =~ m/\s(HAVEN|HAVN|HVN)(\.|,|\s|\n|$)/){
								$B_streettype = "HVN";
							} elsif($B_address =~ m/\s(HEIGHTS|HEIGHT|HGTS|HT|HTS)(\.|,|\s|\n|$)/){
								$B_streettype = "HTS";
							} elsif($B_address =~ m/\s(HIGHWAY|HIGHWY|HIWAY|HIWY|HWAY|HWY)(\.|,|\s|\n|$)/){
								$B_streettype = "HWY";
							} elsif($B_address =~ m/\s(HILL|HL)(\.|,|\s|\n|$)/){
								$B_streettype = "HL";
							} elsif($B_address =~ m/\s(HILLS|HLS)(\.|,|\s|\n|$)/){
								$B_streettype = "HLS";
							} elsif($B_address =~ m/\s(HOLLOW|HLLW|HOLLOWS|HOLW|HOLWS)(\.|,|\s|\n|$)/){
								$B_streettype = "HOLW";
							## I street types
							} elsif($B_address =~ m/\s(INLET|INLT)(\.|,|\s|\n|$)/){
								$B_streettype = "INLT";
							} elsif($B_address =~ m/\s(ISLAND|IS|ISLND)(\.|,|\s|\n|$)/){
								$B_streettype = "IS";
							} elsif($B_address =~ m/\s(ISLANDS|ISLNDS|ISS)(\.|,|\s|\n|$)/){
								$B_streettype = "ISS";
							} elsif($B_address =~ m/\s(ISLE|ISLES)(\.|,|\s|\n|$)/){
								$B_streettype = "ISLE";
							## J street types
							} elsif($B_address =~ m/\s(JUNCTION|JCT|JCTION|JCTN|JUNCTN|JUNCTON)(\.|,|\s|\n|$)/){
								$B_streettype = "JCT";
							} elsif($B_address =~ m/\s(JUNCTIONS|JCTNS|JCTS)(\.|,|\s|\n|$)/){
								$B_streettype = "JCTS";
							## K street types
							} elsif($B_address =~ m/\s(KEY|KY)(\.|,|\s|\n|$)/){
								$B_streettype = "KY";
							} elsif($B_address =~ m/\s(KEYS|KYS)(\.|,|\s|\n|$)/){
								$B_streettype = "KYS";
							} elsif($B_address =~ m/\s(KNOLL|KNOL|KNL)(\.|,|\s|\n|$)/){
								$B_streettype = "KNL";
							} elsif($B_address =~ m/\s(KNOLLS|KNLS)(\.|,|\s|\n|$)/){
								$B_streettype = "KNLS";
							## L street types
							} elsif($B_address =~ m/\s(LAKE|LK)(\.|,|\s|\n|$)/){
								$B_streettype = "LK";
							} elsif($B_address =~ m/\s(LAKES|LKS)(\.|,|\s|\n|$)/){
								$B_streettype = "LKS";
							} elsif($B_address =~ m/\s(LAND)(\.|,|\s|\n|$)/){
								$B_streettype = "LAND";
							} elsif($B_address =~ m/\s(LANDING|LNDG|LNDNG)(\.|,|\s|\n|$)/){
								$B_streettype = "LNDG";
							} elsif($B_address =~ m/\s(LANE|LA|LANES|LN)(\.|,|\s|\n|$)/){
								$B_streettype = "LN";
							} elsif($B_address =~ m/\s(LIGHT|LGT)(\.|,|\s|\n|$)/){
								$B_streettype = "LGT";
							} elsif($B_address =~ m/\s(LIGHTS|LGTS)(\.|,|\s|\n|$)/){
								$B_streettype = "LGTS";
							} elsif($B_address =~ m/\s(LOAF|LF)(\.|,|\s|\n|$)/){
								$B_streettype = "LF";
							} elsif($B_address =~ m/\s(LOCK|LCK)(\.|,|\s|\n|$)/){
								$B_streettype = "LCK";
							} elsif($B_address =~ m/\s(LOCKS|LCKS)(\.|,|\s|\n|$)/){
								$B_streettype = "LCKS";
							} elsif($B_address =~ m/\s(LODGE|LDG|LODG)(\.|,|\s|\n|$)/){
								$B_streettype = "LDG";
							} elsif($B_address =~ m/\s(LOOP|LOOPS)(\.|,|\s|\n|$)/){
								$B_streettype = "LOOP";
							## M street types
							} elsif($B_address =~ m/\s(MALL)(\.|,|\s|\n|$)/){
								$B_streettype = "MALL";
							} elsif($B_address =~ m/\s(MANOR|MNR)(\.|,|\s|\n|$)/){
								$B_streettype = "MNR";
							} elsif($B_address =~ m/\s(MANORS|MNRS)(\.|,|\s|\n|$)/){
								$B_streettype = "MNRS";
							} elsif($B_address =~ m/\s(MEADOW|MDW)(\.|,|\s|\n|$)/){
								$B_streettype = "MDW";
							} elsif($B_address =~ m/\s(MEADOWS|MDWS|MEDOWS)(\.|,|\s|\n|$)/){
								$B_streettype = "MDWS";
							} elsif($B_address =~ m/\s(MEWS)(\.|,|\s|\n|$)/){
								$B_streettype = "MEWS";
							} elsif($B_address =~ m/\s(MILL|ML)(\.|,|\s|\n|$)/){
								$B_streettype = "ML";
							} elsif($B_address =~ m/\s(MILLS|MLS)(\.|,|\s|\n|$)/){
								$B_streettype = "MLS";
							} elsif($B_address =~ m/\s(MISSION|MISSN|MSN|MSSN)(\.|,|\s|\n|$)/){
								$B_streettype = "MSN";
							} elsif($B_address =~ m/\s(MOTORWAY|MTWY)(\.|,|\s|\n|$)/){
								$B_streettype = "MTWY";
							} elsif($B_address =~ m/\s(MOUNT|MNT|MT)(\.|,|\s|\n|$)/){
								$B_streettype = "MT";
							} elsif($B_address =~ m/\s(MOUNTAIN|MNTAIN|MNTN|MOUNTIN|MTIN|MTN)(\.|,|\s|\n|$)/){
								$B_streettype = "MTN";
							} elsif($B_address =~ m/\s(MOUNTAINS|MNTNS|MTNS)(\.|,|\s|\n|$)/){
								$B_streettype = "MTNS";
							## N street types
							} elsif($B_address =~ m/\s(NECK|NCK)(\.|,|\s|\n|$)/){
								$B_streettype = "NCK";
							## O street types
							} elsif($B_address =~ m/\s(ORCHARD|ORCH|ORCHRD)(\.|,|\s|\n|$)/){
								$B_streettype = "ORCH";
							} elsif($B_address =~ m/\s(OVAL|OVL)(\.|,|\s|\n|$)/){
								$B_streettype = "OVL";
							} elsif($B_address =~ m/\s(OVERPASS|OPAS)(\.|,|\s|\n|$)/){
								$B_streettype = "OPAS";
							## P street types
							} elsif($B_address =~ m/\s(PARK|PK|PRK|PARKS)(\.|,|\s|\n|$)/){
								$B_streettype = "PARK";
							} elsif($B_address =~ m/\s(PARKWAY|PARKWY|PKWAY|PKWY|PKY|PARKWAYS|PKWYS)(\.|,|\s|\n|$)/){
								$B_streettype = "PKWY";
							} elsif($B_address =~ m/\s(PASS)(\.|,|\s|\n|$)/){
								$B_streettype = "PASS";
							} elsif($B_address =~ m/\s(PASSAGE|PSGE)(\.|,|\s|\n|$)/){
								$B_streettype = "PSGE";
							} elsif($B_address =~ m/\s(PATH|PATHS)(\.|,|\s|\n|$)/){
								$B_streettype = "PATH";
							} elsif($B_address =~ m/\s(PIKE|PIKES)(\.|,|\s|\n|$)/){
								$B_streettype = "PIKE";
							} elsif($B_address =~ m/\s(PINE|PNE)(\.|,|\s|\n|$)/){
								$B_streettype = "PNE";
							} elsif($B_address =~ m/\s(PINES|PNES)(\.|,|\s|\n|$)/){
								$B_streettype = "PNES";
							} elsif($B_address =~ m/\s(PLACE|PL)(\.|,|\s|\n|$)/){
								$B_streettype = "PL";
							} elsif($B_address =~ m/\s(PLAIN|PLN)(\.|,|\s|\n|$)/){
								$B_streettype = "PLN";
							} elsif($B_address =~ m/\s(PLAINS|PLAINES|PLNS)(\.|,|\s|\n|$)/){
								$B_streettype = "PLNS";
							} elsif($B_address =~ m/\s(PLAZA|PLZ|PLZA)(\.|,|\s|\n|$)/){
								$B_streettype = "PLZ";
							} elsif($B_address =~ m/\s(POINT|PT)(\.|,|\s|\n|$)/){
								$B_streettype = "PT";
							} elsif($B_address =~ m/\s(POINTS|PTS)(\.|,|\s|\n|$)/){
								$B_streettype = "PTS";
							} elsif($B_address =~ m/\s(PORT|PRT)(\.|,|\s|\n|$)/){
								$B_streettype = "PRT";
							} elsif($B_address =~ m/\s(PORTS|PRTS)(\.|,|\s|\n|$)/){
								$B_streettype = "PRTS";
							} elsif($B_address =~ m/\s(PRARIE|PR|PRARIE|PRR)(\.|,|\s|\n|$)/){
								$B_streettype = "PR";
							## R street types
							} elsif($B_address =~ m/\s(RADIAL|RADIEL|RADL)(\.|,|\s|\n|$)/){
								$B_streettype = "RADL";
							} elsif($B_address =~ m/\s(RAMP)(\.|,|\s|\n|$)/){
								$B_streettype = "RAMP";
							} elsif($B_address =~ m/\s(RANCH|RANCHES|RNCH|RNCHS)(\.|,|\s|\n|$)/){
								$B_streettype = "RNCH";
							} elsif($B_address =~ m/\s(RAPID|RPD)(\.|,|\s|\n|$)/){
								$B_streettype = "RPD";
							} elsif($B_address =~ m/\s(RAPIDS|RPDS)(\.|,|\s|\n|$)/){
								$B_streettype = "RPDS";
							} elsif($B_address =~ m/\s(REST|RST)(\.|,|\s|\n|$)/){
								$B_streettype = "RST";
							} elsif($B_address =~ m/\s(RIDGE|RDG|RDGE)(\.|,|\s|\n|$)/){
								$B_streettype = "RDG";
							} elsif($B_address =~ m/\s(RIDGES|RDGS)(\.|,|\s|\n|$)/){
								$B_streettype = "RDGS";
							} elsif($B_address =~ m/\s(RIVER|RIV|RIVR|RVR)(\.|,|\s|\n|$)/){
								$B_streettype = "RIV";
							} elsif($B_address =~ m/\s(ROAD|RD)(\.|,|\s|\n|$)/){
								$B_streettype = "RD";
							} elsif($B_address =~ m/\s(ROADS|RDS)(\.|,|\s|\n|$)/){
								$B_streettype = "RDS";
							} elsif($B_address =~ m/\s(ROUTE|RTE)(\.|,|\s|\n|$)/){
								$B_streettype = "RTE";
							} elsif($B_address =~ m/\s(ROW)(\.|,|\s|\n|$)/){
								$B_streettype = "ROW";
							} elsif($B_address =~ m/\s(RUE)(\.|,|\s|\n|$)/){
								$B_streettype = "RUE";
							} elsif($B_address =~ m/\s(RUN)(\.|,|\s|\n|$)/){
								$B_streettype = "RUN";
							## S street types
							} elsif($B_address =~ m/\s(SHOAL|SHL)(\.|,|\s|\n|$)/){
								$B_streettype = "SHL";
							} elsif($B_address =~ m/\s(SHOALS|SHLS)(\.|,|\s|\n|$)/){
								$B_streettype = "SHLS";
							} elsif($B_address =~ m/\s(SHORE|SHOAR|SHR)(\.|,|\s|\n|$)/){
								$B_streettype = "SHR";
							} elsif($B_address =~ m/\s(SHORES|SHOARS|SHRS)(\.|,|\s|\n|$)/){
								$B_streettype = "SHRS";
							} elsif($B_address =~ m/\s(SKYWAY|SKWY)(\.|,|\s|\n|$)/){
								$B_streettype = "SKWY";
							} elsif($B_address =~ m/\s(SPRING|SPG|SPNG|SPRNG)(\.|,|\s|\n|$)/){
								$B_streettype = "SPG";
							} elsif($B_address =~ m/\s(SPRINGS|SPGS|SPNGS)(\.|,|\s|\n|$)/){
								$B_streettype = "SPGS";
							} elsif($B_address =~ m/\s(SPUR|SPURS)(\.|,|\s|\n|$)/){
								$B_streettype = "SPUR";
							} elsif($B_address =~ m/\s(SQUARE|SQ|SQR|SQRE|SQU)(\.|,|\s|\n|$)/){
								$B_streettype = "SQ";
							} elsif($B_address =~ m/\s(SQUARES|SQRS|SQS)(\.|,|\s|\n|$)/){
								$B_streettype = "SQS";
							} elsif($B_address =~ m/\s(STATION|STA|STATN|STN)(\.|,|\s|\n|$)/){
								$B_streettype = "STA";
							} elsif($B_address =~ m/\s(STRAVENUE|STRA|STRAV|STRAVE|STRAVEN|STRAVN|STRVN|STRVNUE)(\.|,|\s|\n|$)/){
								$B_streettype = "STRA";
							} elsif($B_address =~ m/\s(STREAM|STRM)(\.|,|\s|\n|$)/){
								$B_streettype = "STRM";
							} elsif($B_address =~ m/\s(STREET|ST|STR|STRT)(\.|,|\s|\n|$)/){
								$B_streettype = "ST";
							} elsif($B_address =~ m/\s(STREETS|STS)(\.|,|\s|\n|$)/){
								$B_streettype = "STS";
							} elsif($B_address =~ m/\s(SUMMIT|SMT|SUMIT|SUMITT)(\.|,|\s|\n|$)/){
								$B_streettype = "SMT";
							## T road types
							} elsif($B_address =~ m/\s(TERRACE|TER|TERR)(\.|,|\s|\n|$)/){
								$B_streettype = "TER";
							} elsif($B_address =~ m/\s(THROUGHWAY|TRWY)(\.|,|\s|\n|$)/){
								$B_streettype = "TRWY";
							} elsif($B_address =~ m/\s(TRACE|TRACES|TRCE)(\.|,|\s|\n|$)/){
								$B_streettype = "TRCE";
							} elsif($B_address =~ m/\s(TRACK|TRACKS|TRAK|TRK|TRKS)(\.|,|\s|\n|$)/){
								$B_streettype = "TRAK";
							} elsif($B_address =~ m/\s(TRAFFICWAY|TRFY)(\.|,|\s|\n|$)/){
								$B_streettype = "TRFY";
							} elsif($B_address =~ m/\s(TRAIL|TR|TRAILS|TRL|TRLS)(\.|,|\s|\n|$)/){
								$B_streettype = "TRL";
							} elsif($B_address =~ m/\s(TUNNEL|TUNEL|TUNL|TUNLS|TUNNELS|TUNNL)(\.|,|\s|\n|$)/){
								$B_streettype = "TUNL";
							} elsif($B_address =~ m/\s(TURNPIKE|TPK|TPKE|TRNPK|TRPK|TURNPK)(\.|,|\s|\n|$)/){
								$B_streettype = "TPKE";
							## U road types
							} elsif($B_address =~ m/\s(UNDERPASS|UPAS)(\.|,|\s|\n|$)/){
								$B_streettype = "UPAS";
							} elsif($B_address =~ m/\s(UNION|UN)(\.|,|\s|\n|$)/){
								$B_streettype = "UN";
							} elsif($B_address =~ m/\s(UNIONS|UNS)(\.|,|\s|\n|$)/){
								$B_streettype = "UNS";
							## V road types
							} elsif($B_address =~ m/\s(VALLEY|VALLY|VLLY|VLY)(\.|,|\s|\n|$)/){
								$B_streettype = "VLY";
							} elsif($B_address =~ m/\s(VALLEYS|VLYS)(\.|,|\s|\n|$)/){
								$B_streettype = "VLYS";
							} elsif($B_address =~ m/\s(VIADUCT|VDCT|VIA|VIADCT)(\.|,|\s|\n|$)/){
								$B_streettype = "VIA";
							} elsif($B_address =~ m/\s(VIEW|VW)(\.|,|\s|\n|$)/){
								$B_streettype = "VW";
							} elsif($B_address =~ m/\s(VIEWS|VWS)(\.|,|\s|\n|$)/){
								$B_streettype = "VWS";
							} elsif($B_address =~ m/\s(VILLAGE|VILL|VILLAG|VILLG|VILLIAGE|VLG)(\.|,|\s|\n|$)/){
								$B_streettype = "VLG";
							} elsif($B_address =~ m/\s(VILLAGES|VLGS)(\.|,|\s|\n|$)/){
								$B_streettype = "VLGS";
							} elsif($B_address =~ m/\s(VILLE|VL)(\.|,|\s|\n|$)/){
								$B_streettype = "VL";
							} elsif($B_address =~ m/\s(VISTA|VIS|VIST|VST|VSTA)(\.|,|\s|\n|$)/){
								$B_streettype = "VIS";
							## W road types
							} elsif($B_address =~ m/\s(WALK|WALKS)(\.|,|\s|\n|$)/){
								$B_streettype = "WALK";
							} elsif($B_address =~ m/\s(WALL)(\.|,|\s|\n|$)/){
								$B_streettype = "WALL";
							} elsif($B_address =~ m/\s(WAY|WY)(\.|,|\s|\n|$)/){
								$B_streettype = "WAY";
							} elsif($B_address =~ m/\s(WAYS)(\.|,|\s|\n|$)/){
								$B_streettype = "WAYS";
							} elsif($B_address =~ m/\s(WELL|WL)(\.|,|\s|\n|$)/){
								$B_streettype = "WL";
							} elsif($B_address =~ m/\s(WELLS|WLS)(\.|,|\s|\n|$)/){
								$B_streettype = "WLS";
			}	}	}	}	}


			## Notes data
			my $opacnote;
			my $contactnote;
			my $borrowernotes;

			## pulling Sirsi notes into the borrowernotes field
			if($user =~ m/\.NOTE\.\s+\|a(.+)/){
				 $borrowernotes = $1;}

			## Demographic data, not doing anything with these
			my $dateofbirth;
			my $relationship;
			my $ethnicity;
			my $ethnotes;
			my $sex;


			## No clue...
			my $flags;
			my $sort1;
			my $sort2;
			my $guarantorid;

			## print to csv output if
			## the borrowernumber is > 17 (these are system users for us)
			if (($borrowernumber > 17) && ($categorycode) && (( $categorycode ne "RESERVES" ) && ( $categorycode ne "SIRSI" ) && ( $categorycode ne "TEST" )  && ( $categorycode ne "WEBSERVER")) && ($surname)) {
				my @row = ($borrowernumber,$cardnumber,$surname,$firstname,$title,$othernames,$initials,$streetnumber,$streettype,$address,$address2,$city,$zipcode,$email,$phone,$mobile,$fax,$emailpro,$phonepro,$B_streetnumber,$B_streettype,$B_address,$B_city,$B_zipcode,$B_email,$B_phone,$dateofbirth,$branchcode,$categorycode,$dateenrolled,$dateexpiry,$gonenoaddress,$lost,$debarred,$contactname,$contactfirstname,$contacttitle,$guarantorid,$borrowernotes,$relationship,$ethnicity,$ethnotes,$sex,$password,$flags,$userid,$opacnote,$contactnote,$sort1,$sort2,$altcontactfirstname,$altcontactsurname,$altcontactaddress1,$altcontactaddress2,$altcontactaddress3,$altcontactzipcode,$altcontactphone,$smsalertnumber);
				foreach my $column (@row) {
					$column =~ s/"//g; 
					print MYOUTPUTFILE "\"$column\",";
				}
				print MYOUTPUTFILE "\n";
			} else {
				my @row = ($borrowernumber,$cardnumber,$surname,$firstname,$title,$othernames,$initials,$streetnumber,$streettype,$address,$address2,$city,$zipcode,$email,$phone,$mobile,$fax,$emailpro,$phonepro,$B_streetnumber,$B_streettype,$B_address,$B_city,$B_zipcode,$B_email,$B_phone,$dateofbirth,$branchcode,$categorycode,$dateenrolled,$dateexpiry,$gonenoaddress,$lost,$debarred,$contactname,$contactfirstname,$contacttitle,$guarantorid,$borrowernotes,$relationship,$ethnicity,$ethnotes,$sex,$password,$flags,$userid,$opacnote,$contactnote,$sort1,$sort2,$altcontactfirstname,$altcontactsurname,$altcontactaddress1,$altcontactaddress2,$altcontactaddress3,$altcontactzipcode,$altcontactphone,$smsalertnumber);
				foreach my $column (@row) {
					$column =~ s/"//g; 
					print MYERRORFILE "\"$column\",";
				}
				print MYERRORFILE "\n";
	}	}	}

	close(MYERRORFILE);
	close(MYOUTPUTFILE);
	close(MYUSERKEYFILE);
	unlink 'userkey';

	## Tell us how many users processed
	print "\n$usercount users processed\n";
}

### Cleaning up ##

# end timer
my($end) = time();

# report and close
print "Time taken was " ,($end - $start), " seconds\n";
exit;