#!/usr/bin/perl
use strict;
#use warnings;
use Text::CSV;
use File::Basename;
use File::Spec;

my $csv = Text::CSV->new({ binary => 1, auto_diag => 1, sep_char => ',' });
my $file;
my $categorycode = 'ST';
my $branchcode = 'NASH';
if ($ARGV[0]) {
  $file = $ARGV[0] or die 'unable to open POISE CSV!';
  if ($ARGV[1] =~/\w/) {
    $categorycode = $ARGV[1];
  }
  if ($ARGV[2] =~/\w/) {
    $branchcode = $ARGV[2];
  }
} else {
  print 'POISE to Koha user import.
This program takes in a student file from POISE and spits out Koha user data.
It accepts the path of a POISE CSV optionally followed by category and branch
codes. It outputs two files:
1)  KohaImportPatronsIgnoreMatch.csv
    Is the first file you should import into Koha, using the
    "Ignore this one, keep the existing one" rule.
2)  KohaImportPatronsOverwriteMatch.csv
    Is the second file you should import into Koha, using theS
    "Overwrite the existing one with this" rule.

Examples: "C:\Users\You\Downloads\POISE.CSV"
Sets all users as students with Nash Library as their home branch.

"C:\Users\You\Downloads\POISE.CSV" AL DIGITAL
Sets all users as alumni with Nash Digital as their home branch.

In Koha,  see Administration > Libraries and groups
          and Administration > Patron categories
for more information.  

Enter the absolute filename of the POISE CSV then press enter:
';
  $file = <STDIN>;
  chomp $file;
  if ($file =~ m/^("(.+)"|[^\s]+)\s?(\w+)?\s?(\w+)?$/) {
    $file = $1;
    if ($3) {
      $categorycode = $3;
      if ($4) {
        $branchcode = $4;
      }
    }
  }
}

my ($filename, $filedir, $filesuffix) = fileparse($file);

open my $io, '<', $file or die "Could not open '$file' $!\n";
## The included header contains dupes, which is a no-no. Skip it.
$csv->getline ($io);
## Make our own column names.  Lowercase ones are basically ready for koha,
## Capitalized ones need a bit more work.
$csv->column_names (qw( cardnumber surname FIRSTNAME MIDDLEINIT MAILPREF PERMADDR HOPESTREET2 HOPECITY HOPESTATE HOPEZIP COUNTRY LOCSTREET LOCSTREET2 LOCCITY LOCSTATE LOCZIP EMAIL LOCPHONE TELEPHONE USAOEMAIL WORKPHONE dateofbirth password ENTRYDATE LASTCHGDATE ));
print "\nProcessing Records...\n";

## Name the output files
## The ingore match file contains all the info needed to create a new user account.
## The overwrite match file skips the username and password fields, so that we
## don't overwrite passwords that users have updated or custom usernames
## set by our staff.
my $ignr_mtch_out = File::Spec->catfile($filedir,"KohaImportPatronsIgnoreMatch.csv");
my $ovrwrt_mtch_out = File::Spec->catfile($filedir,"KohaImportPatronsOverwriteMatch.csv");

## print header to files
open(IGNRMTCHOUT, ">", "$ignr_mtch_out") || die("Could not open $ignr_mtch_out!"); 
print IGNRMTCHOUT "cardnumber\,surname\,firstname\,dateofbirth\,branchcode\,categorycode\,address\,address2\,city\,zipcode\,country\,email\,emailpro\,phone\,phonepro\,B_address\,B_address2\,B_city\,B_zipcode\,B_country\,password\,userid\n";
close(IGNRMTCHOUT);

## take out fields
open(OWMTCHOUT, ">", "$ovrwrt_mtch_out") || die("Could not open $ovrwrt_mtch_out!"); 
print OWMTCHOUT "cardnumber\,surname\,firstname\,dateofbirth\,branchcode\,categorycode\,address\,address2\,city\,zipcode\,country\,email\,emailpro\,phone\,phonepro\,B_address\,B_address2\,B_city\,B_zipcode\,B_country\n";
close(OWMTCHOUT);

while (my $row = $csv->getline_hr ($io)) {
  if ($csv->parse($row)) {

    ## This whole process is predicated on having a cardnumber to match on,
    ## so if we don't have that for some reason, there's no point.
    if ($row->{cardnumber}) {
      ## These are the fields we have create
      my ($firstname,$address,$address2,$city,$zipcode,$country,$B_address,$B_address2,$B_city,$B_zipcode,$B_country,$email,$emailpro,$phone,$phonepro,$userid);
      
      ##Clean up the dashes that seem to make their way into the cardnumbers
      $row->{cardnumber} =~ s/-//gi;
      
      ## Combine separate 1st name and middle initial fields
      ## into a single 1stname + mi field and ALL CAP the whole name.
      if ($row->{FIRSTNAME} && $row->{MIDDLEINIT}) {
        $firstname = $row->{FIRSTNAME}.' '.$row->{MIDDLEINIT};
        uc($firstname);
      } elsif ($row->{FIRSTNAME}) {
        $firstname = $row->{FIRSTNAME};
        uc($firstname);
      }
      if ($row->{surname}) {
        uc($row->{surname});
      }
      
      ## Address stuff.  This is a little bit of a mess in the SIS. Also, our
      ## needs seem to be a little different then everybody else's. As a rule,
      ## we want a permanent mailing address as the primary address. That seems
      ## to get the best response for overdue notices.  We don't really need or
      ## want to do this for students from out of the country, however.

      ## COUNTRY is blank for most students, but we'll use it if we can.
      ## HOPESTATE field is pretty consistently coded as ZZ for non-US students
      ## so we can go by that if COUNTRY is blank. If it looks like the student
      ## is from the US, put the permanent address as the primary.
      if (($row->{COUNTRY} eq 'US') || ($row->{HOPESTATE} ne 'ZZ')) {
        if ($row->{PERMADDR}) {
          $address = &nrmlizeAddrLine($row->{PERMADDR});
        }
        if ($row->{HOPESTREET2}) {
          $address2 = &nrmlizeAddrLine($row->{HOPESTREET2});
        }
        ## Concat City and State fields into a single field and ALL CAP it.
        if ($row->{HOPECITY} && $row->{HOPESTATE}) {
          $city = &concatCityState($row->{HOPECITY},$row->{HOPESTATE});
        }
        ## Add the fancy little dash to the zipcode.
        if ($row->{HOPEZIP}) {
          $zipcode = &nrmlizeZIP($row->{HOPEZIP});
        }
        $country = 'US';
        
        ## Naturally, that means that we count whatever is in the local address
        ## as our alternative address. Probably on-campus or Chickasha rental.
        if ($row->{LOCSTREET}) {
          $B_address = &nrmlizeAddrLine($row->{LOCSTREET});
        }
        if ($row->{LOCSTREET2}) {
          $B_address2 = &nrmlizeAddrLine($row->{LOCSTREET2});
        }
        ## Concat City and State fields into a single field and ALL CAP it.
        if ($row->{LOCCITY} && $row->{LOCSTATE}) {
          $B_city = &concatCityState($row->{LOCCITY},$row->{LOCSTATE});
        }
        ## Add the fancy little dash to the zipcode.
        if ($row->{LOCZIP}) {
          $B_zipcode = &nrmlizeZIP($row->{LOCZIP});
        }
        ## Go ahead and set "B_country as well"
        if ($row->{LOCSTATE} ne 'ZZ') {
          $B_country = 'US';
        }
      } else {
      ## If the student is from another country, set the local
      ## address as primary.  Again, most likely on-campus or a rental.
        if ($row->{LOCSTREET}) {
          $address = &nrmlizeAddrLine($row->{LOCSTREET});
        }
        if ($row->{LOCSTREET2}) {
          $address2 = &nrmlizeAddrLine($row->{LOCSTREET2});
        }
        ## Concat City and State fields into a single field and ALL CAP it.
        if ($row->{LOCCITY} && $row->{LOCSTATE}) {
          $city = &concatCityState($row->{LOCCITY},$row->{LOCSTATE});
        }
        ## Add the fancy little dash to the zipcode.
        if ($row->{LOCZIP}) {
          $zipcode = &nrmlizeZIP($row->{LOCZIP});
        }
        ## Go ahead and set country as well
        if ($row->{LOCSTATE} ne 'ZZ') {
          $country = 'US';
        }
        ## Naturally, that means that we count whatever is in the home address
        ## as our alternative address. This should be some other country.
        if ($row->{PERMADDR}) {
          $B_address = &nrmlizeAddrLine($row->{PERMADDR});
        }
        if ($row->{HOPESTREET2}) {
          $B_address2 = &nrmlizeAddrLine($row->{HOPESTREET2});
        }
        ## Concat City and State fields into a single field and ALL CAP it.
        if ($row->{HOPECITY} && $row->{HOPESTATE}) {
          $B_city = &concatCityState($row->{HOPECITY},$row->{HOPESTATE});
        }
        ## Add the fancy little dash to the zipcode.
        if ($row->{HOPEZIP}) {
          $B_zipcode = &nrmlizeZIP($row->{HOPEZIP});
        }
        ## Go ahead and set "B_country as well"
        if ($row->{COUNTRY} ne 'US') {
          $B_country = $row->{COUNTRY};
        }
      }

      ## Create the userid by stripping '@usao.edu' from the USAO email address.
      if($row->{USAOEMAIL}){
        $userid = substr($row->{USAOEMAIL},0,-9);
        lc($userid);
      }
      
      ## If the user has a personal & USAO email, put it in the email field and
      ## put the usao email in the emailpro field, if the they don't have a
      ## personal email, put the usao email address in the email field and 
      ## leave the emailpro field blank. Lowercase it all.
      if ($row->{EMAIL} && $row->{USAOEMAIL}) {
        $email = $row->{EMAIL};
        $emailpro = $row->{USAOEMAIL};
        lc($email);
        lc($emailpro);
      } elsif ($row->{USAOEMAIL}) {
        $email = $row->{USAOEMAIL};
        lc($email);
      }

      
      ##Format the the phone numbers as dot separated. In our SIS 0 is empty.
      if ($row->{TELEPHONE} > 0) {
        $phone = &parsePhone($row->{TELEPHONE});
      }
      if ($row->{WORKPHONE} > 0) {
        $phonepro = &parsePhone($row->{WORKPHONE});
      }

      #Print data to files
      # The ignore match file includes everything since it be used to add new users.
      open(IGNRMTCHOUT, ">>", "$ignr_mtch_out") || die("Could not open $ignr_mtch_out!");
      print IGNRMTCHOUT "\"$row->{cardnumber}\"\,\"$row->{surname}\"\,\"$firstname\"\,\"$row->{dateofbirth}\"\,\"$branchcode\"\,\"$categorycode\"\,\"$address\"\,\"$address2\"\,\"$city\"\,\"$zipcode\"\,\"$country\"\,\"$email\"\,\"$emailpro\"\,\"$phone\"\,\"$phonepro\"\,\"$B_address\"\,\"$B_address2\"\,\"$B_city\"\,\"$B_zipcode\"\,\"$B_country\"\,\"$row->{password}\"\,\"$userid\"\n";
      close(IGNRMTCHOUT);
      
      # The overwrite match file skips the userid and password fields so that we don't change an existing persons login info on every update.
      open(OWMTCHOUT, ">>", "$ovrwrt_mtch_out") || die("Could not open $ovrwrt_mtch_out!");
      print OWMTCHOUT "\"$row->{cardnumber}\"\,\"$row->{surname}\"\,\"$firstname\"\,\"$row->{dateofbirth}\"\,\"$branchcode\"\,\"$categorycode\"\,\"$address\"\,\"$address2\"\,\"$city\"\,\"$zipcode\"\,\"$country\"\,\"$email\"\,\"$emailpro\"\,\"$phone\"\,\"$phonepro\"\,\"$B_address\"\,\"$B_address2\"\,\"$B_city\"\,\"$B_zipcode\"\,\"$B_country\"\n";
      close(OWMTCHOUT);
    }
  } else {
    warn "Record could not be parsed: $row\n";
  }
}

sub nrmlizeAddrLine {
  my $addrLine = $_[0];
  $addrLine =~ s/\.//gi;  ## Get rid of dots.
  uc($addrLine);    ## ALL CAP it.
  return $addrLine;
}

sub concatCityState {
  my $city = $_[0];
  my $state = $_[1];
  my $cityState;
  $cityState = $city.', '.$state;
  uc($cityState);
  return $cityState;
}

sub nrmlizeZIP {
  my $zip = $_[0];
  my $parsedZip;
  if(length($zip) == 9) {
    $parsedZip = substr($zip,0,5) . '-' . substr($zip,5,4);
  } else {
    $parsedZip = $zip;
  }
  return $parsedZip;
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