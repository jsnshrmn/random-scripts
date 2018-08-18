#!/usr/bin/perl
use strict;
use warnings;
use Text::CSV;

print '
VMS to Koha user import

This program takes in a csv from our old-timey Student information System
STUDENTID,LASTNAME,FIRSTNAME,MIDDLEINIT,LOCSTREET,LOCSTREET2,LOCCITYLOCSTATE,
LOCZIP,EMAIL,LOCPHONE,TELEPHONE,USAOEMAIL,WORKPHONE,BIRTHDATE,BIRTHDATE,
ENTRYDATE,LASTCHGDATE
and spits out a csv that we can bring into Koha.
';


#print "\nEnter name of comma delimited input file:\n";
#my $inputfile = <STDIN>;
#chomp $inputfile;
#print "\nReading File...\n";
#open(MYINPUTFILE, $inputfile) || die("Could not open file!");
#my(@lines) = <MYINPUTFILE>; 
#close(MYINPUTFILE);

##Name the output file
my $outputfile = "KohaUserImport" . "\.csv";

##print header to file
open(MYOUTPUTFILE, ">", "$outputfile") || die("Could not open $outputfile!"); 
print MYOUTPUTFILE "cardnumber\,surname\,firstname\,dateofbirth\,address\,address2\,city\,zipcode\,email\,emailpro\,phone\,phonepro\,password\,userid\n";
close(MYOUTPUTFILE);

my $csv = Text::CSV->new({ binary => 1, auto_diag => 1, sep_char => ',' });
my $file = $ARGV[0] or die "Need to get CSV file on the command line\n";
open my $io, '<', $file or die "Could not open '$file' $!\n";
## Actually, the included header contains dupes, which is a no-no.
#my $header = $csv->getline($io);
#$csv->column_names(@$header);
## skip included header
#$csv->getline ($io);
## Make our own column names.  Lowercase ones are basically ready for koha,
## Capitalized ones need a bit more work.
$csv->column_names (qw( cardnumber surname FIRSTNAME MIDDLEINIT address address2 LOCCITY LOCSTATE zipcode EMAIL LOCPHONE TELEPHONE USAOEMAIL WORKPHONE dateofbirth password ENTRYDATE LASTCHGDATE ));
print "\nProcessing Records...\n";
while (my $row = $csv->getline ($io)) {
  if ($csv->parse($row)) {
    ## Use those column names we created earlier.
    my $hr = $csv->getline_hr ($io);

    ## This whole process is predicated on having a cardnumber to match on,
    ## so if we don't have that for some reason, there's no point.
    if ($hr->{cardnumber}) {
      ## These are the fields we have create
      my ($firstname,$city,$email,$emailpro,$phone,$phonepro,$userid);
      
      ##Clean up the common junk that seems to make its way into fields
      $hr->{cardnumber} =~ s/-//gi;
      $hr->{address} =~ s/\.//gi;
      $hr->{address2} =~ s/\.//gi;
      
      ## ALL CAP some stuff as well.
      uc($hr->{surname});
      uc($hr->{address});
      uc($hr->{address2});
      
      ## Combine separate 1st name and middle initial fields
      ## into a single 1stname + mi field and ALL CAP it.
      if ($hr->{FIRSTNAME} && $hr->{MIDDLEINIT}) {
        $firstname = $hr->{FIRSTNAME}.' '.$hr->{MIDDLEINIT};
      } elsif ($hr->{FIRSTNAME}) {
        $firstname = $hr->{FIRSTNAME};
      }
      uc($firstname);
      
      ## Combine separate City and State fields into a single City/State field
      ## and ALL CAP it.
      if ($hr->{LOCCITY} && $hr->{LOCSTATE}) {
        $city = $hr->{LOCCITY}.', '.$hr->{LOCSTATE};
      }
      uc($city);
      
      ## Create the userid by stripping '@usao.edu' from the USAO email address.
      if($hr->{USAOEMAIL}){
        $userid = substr($hr->{USAOEMAIL},0,-9);
        lc($userid);
      }
      
      ## If the user has a personal & USAO email, put it in the email field and
      ## put the usao email in the emailpro field, if the they don't have a
      ## personal email, put the usao email address in the email field and 
      ## leave the emailpro field blank. Lowercase it all.
      if ($hr->{EMAIL} && $hr->{USAOEMAIL}) {
        $email = $hr->{EMAIL};
        $emailpro = $hr->{USAOEMAIL};
      } elsif ($hr->{USAOEMAIL}) {
        $email = $hr->{USAOEMAIL};
      }
      lc($email);
      lc($emailpro);
      
      ##Format the the phone numbers to be dot separated
      if ($hr->{TELEPHONE} > 0) {
        $phone = &parsePhone($hr->{TELEPHONE});
      }
      if ($hr->{WORKPHONE} > 0) {
        $phonepro = &parsePhone($hr->{WORKPHONE});
      }

      #Print data to file
      open(MYOUTPUTFILE, ">>", "$outputfile") || die("Could not open $outputfile!");
      print MYOUTPUTFILE "\"$hr->{cardnumber}\"\,\"$hr->{surname}\"\,\"$firstname\"\,\"$hr->{dateofbirth}\"\,\"$hr->{address}\"\,\"$hr->{address2}\"\,\"$city\"\,\"$hr->{zipcode}\"\,\"$email\"\,\"$emailpro\"\,\"$phone\"\,\"$phonepro\"\,\"$hr->{password}\"\,\"$userid\"\n";
      close(MYOUTPUTFILE);
    }
  } else {
    warn "Record could not be parsed: $row\n";
  }
}

sub parsePhone {
  my $phonenumber = $_[0];
  my $parsedPhonenumber;
  ## If it's just 10 digits
  if(length($phonenumber) == 10) {
    $parsedPhonenumber = substr($phonenumber,0,3) . '.' . substr($phonenumber,3,3) . '.' . substr($phonenumber,6,4);
  ## If it's (xxx)xxx-xxxx
  }elsif($phonenumber =~ /\((\d{3})\)(\d{3})-(\d{4})/) {
    $parsedPhonenumber = $1 . '.' . $2 . '.' . $3;        
  ## If it's something else, just print it out as-is
  }else{
    $parsedPhonenumber = $phonenumber;
  }
  return $parsedPhonenumber;
}