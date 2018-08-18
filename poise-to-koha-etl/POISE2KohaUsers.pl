#!/usr/bin/perl
use strict;
use warnings;

print '
VMS to Koha user import

This program takes in a csv from our old-timey Student information System
and spits out a csv that we can bring into Koha.
';


print "\nEnter name of comma delimited input file:\n";
my $inputfile = <STDIN>;
chomp $inputfile;
print "\nReading File...\n";
open(MYINPUTFILE, $inputfile) || die("Could not open file!");
my(@lines) = <MYINPUTFILE>; 
close(MYINPUTFILE);
#shift(@lines);
my($line);

print "\nProcessing Records...\n";

##Name the output file
my $outputfile = "KohaUserImport" . "\.csv";

##print header to file
open(MYOUTPUTFILE, ">", "$outputfile") || die("Could not open $outputfile!"); 
print MYOUTPUTFILE "cardnumber\,surname\,firstname\,dateofbirth\,address\,city\,zipcode\,email\,emailpro\,phone\,password\,userid\n";
close(MYOUTPUTFILE);

	
##if necessary, make a directory to stick all of these into
#mkdir 'files', unless -d 'files';
foreach $line (@lines)
 {
	chomp $line;	
	## These are all of the fields from the VMS export
	my ($UserBarcode,$UserLastName,$User1stName,$UserMiddleInitial,$UserBDay,$UserStrtAddr,$UserCity,$UserState,$UserZIP,$UserPersonalEmail,$UserUSAOEmail,$UserPhone);

	## Use split() to get the fields. "\," is the comma character.
	($UserBarcode,$UserLastName,$User1stName,$UserMiddleInitial,$UserBDay,$UserStrtAddr,$UserCity,$UserState,$UserZIP,$UserPhone,$UserUSAOEmail,$UserPersonalEmail) = split_string($line);

	## These are all of the fields we have to reformat or combine
	my ($ParsedUserBarcode,$ParsedUser1stName,$ParsedCityState,$ParsedUserZIP,$ParsedUserEmail,$ParsedUserEmailPro,$ParsedUserPhone,$ParsedUserId,$ParsedUserBDay,$ParsedUserPW);

	##Format the User barcode if necessary
	if($UserBarcode){
      $ParsedUserBarcode = $UserBarcode;    
	  if(length($ParsedUserBarcode) > 9) {
        $ParsedUserBarcode =~ s/-//gi;
      }
    }
    
	##Combine separate 1st name and middle initial fields into a single 1stname + mi field
	if($User1stName && $UserMiddleInitial){$ParsedUser1stName = "$User1stName" . " " . "$UserMiddleInitial";}elsif($User1stName){$ParsedUser1stName = $User1stName;}	
	
	##Combine separate City and State fields into a single City/State field
	if($UserCity && $UserState){$ParsedCityState = "$UserCity" . "\," . "$UserState";}elsif($UserCity){$ParsedCityState = $UserCity;}

    ## Get rid of extraneous dash in second position of zip field, eg. 7-0318
	if($UserZIP){
      $ParsedUserZIP = $UserZIP;    
	  if(length($ParsedUserZIP) == 6) {
        $ParsedUserZIP =~ s/-//i;
      }
    }    
    
	##lowercase all email addresses
	if($UserPersonalEmail){$UserPersonalEmail = lc($UserPersonalEmail);}
	if($UserUSAOEmail){$UserUSAOEmail = lc($UserUSAOEmail);}
	
	##If the user has a personal email, put it in the email field and put the usao email
	##in the emailpro field, if the they don't put the usao email address in the email field
	##and leave the emailpro field blank
	$ParsedUserEmailPro = '';
	if($UserPersonalEmail){
	  $ParsedUserEmail = $UserPersonalEmail;
	  if($UserUSAOEmail){
	    $ParsedUserEmailPro = $UserUSAOEmail;
	  }
	}elsif($UserUSAOEmail){
	  $ParsedUserEmail = $UserUSAOEmail;
	}
	
	##Format the the phone numbers to be dot separated
	$ParsedUserPhone = '';
	if($UserPhone){
      ## If it's just 10 digits
	  if(length($UserPhone) == 10) {
	    $ParsedUserPhone = substr($UserPhone,0,3) . '.' . substr($UserPhone,3,3) . '.' . substr($UserPhone,6,4);
      ## If it's (xxx)xxx-xxxx
      }elsif($UserPhone =~ /\((\d{3})\)(\d{3})-(\d{4})/) {
	    $ParsedUserPhone = $1 . '.' . $2 . '.' . $3;        
      }else{
      ## If it's something else, just print it out as-is
	    $ParsedUserPhone = $UserPhone;
	  }
    }
	
	##create the UserId by stripping '@usao.edu' from the USAO email address
	$ParsedUserId = '';
	if($UserUSAOEmail){
	  $ParsedUserId = substr($UserUSAOEmail,0,-9);
	}
	
	##Deal with the UserBDay
	if($UserBDay) {
	  ##Get each component of the birthdate

	  my ($BYear,$BMonth,$Bday);
      ## check for slash formatting month/day/year (example input: (0)2/(0)2/1992)
      if ($UserBDay =~ /(\d{1,2})\/(\d{1,2})\/(\d{4})/) {
	    $BYear = $3;
        ## Pad out to two characters if necessary
	    $BMonth = sprintf("%02s",$1);
	    $Bday = sprintf("%02s",$2);
      } else {
        # in the (m)mddyyyy format(example input: 2021992)  
	    $BYear = substr($UserBDay,-4);
        ## Pad out to two characters if necessary        
	    $BMonth = sprintf("%02s",substr($UserBDay,0,-6));
	    $Bday = substr($UserBDay,-6,2);
	  }	
	  ##Format the birthday for our bday field YYYY-MM-DD (ISO fromat, eg. 1992-02-02)
	  $ParsedUserBDay = "$BYear" . "-" . "$BMonth" . "-" . "$Bday";
	  
	  ##Format the birthday for the user password (mmddyyyy format, eg. 02021992)
	  $ParsedUserPW = $BMonth . $Bday . $BYear;
	}
	
    #Print data to file
    open(MYOUTPUTFILE, ">>", "$outputfile") || die("Could not open $outputfile!");
	print MYOUTPUTFILE "\"$ParsedUserBarcode\"\,\"$UserLastName\"\,\"$ParsedUser1stName\"\,\"$ParsedUserBDay\"\,\"$UserStrtAddr\"\,\"$ParsedCityState\"\,\"$ParsedUserZIP\"\,\"$ParsedUserEmail\"\,\"$ParsedUserEmailPro\"\,\"$ParsedUserPhone\"\,\"$ParsedUserPW\"\,\"$ParsedUserId\"\n";
	close(MYOUTPUTFILE);
 }
print "Processed " . @lines . " records.\n";

sub split_string {
    my $text = shift;
    my @new = ();
    push(@new, $+) while $text =~ m{ \s*(
        # groups the phrase inside double quotes
        "([^\"\\]*(?:\\.[^\"\\]*)*)"\s*,?
        # groups the phrase inside single quotes
        | '([^\'\\]*(?:\\.[^\'\\]*)*)'\s*,?
        # trims leading/trailing space from phrase
        | ([^,\s]+(?:\s+[^,\s]+)*)\s*,?
        # just to grab empty phrases
        | (),
        )\s*}gx;
    push(@new, undef) if $text =~ m/,\s*$/;
	return @new;
	    }