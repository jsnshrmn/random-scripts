#!/usr/bin/perl
use strict;
use warnings;
use Sort::Naturally;
use File::Copy; 
use File::Find;
use File::Path;
if($^O =~ /mswin32/i){
  use Win32API::File::Time qw{:win}
}

print '
Compile directories full of files and subdirectories into a dspace SAF package.
This has a bunch of USAO-specific stuff hardcoded into it.
';
print "\nEnter name of the directory to search:\n";
my $searchdir = <STDIN>;
chomp $searchdir;
print "\nEnter name the destination directory:\n";
my $destdir = <STDIN>;
chomp $destdir;

## start timer & counter
my $start = time();
my $i = 0;  # any valid file
my $ii = 0; # date identified
my $io = 0; # nodate
my $ib;     # files making it into the import "bitstreams" in dspace parlance
my $id;     # items making it into the import, which can contain multiple bitstreams

## Containers for the items
my %seen = ();
my @unmergeditems;
my @mergeditems = ();

# Search the specified directory
find (\&eachFile, $searchdir);


# Looking for duplicates.  Pretty much straight out of the Perl Cookbook.
# In this case @unmergeditems is a 2d array.  Each row contains:
#       $title, $filename, $fullpath, $date 
# We're matching on title, which also contains the date
foreach my $unmergeditem (@unmergeditems){
  if ($seen{@$unmergeditem[0]}) {
    # if we get here, we've seen the title before
      &addBitstreamToItem(@$unmergeditem[0],@$unmergeditem[1],@$unmergeditem[2],);
  } else {
    # if we get here, we haven't seen it before
    $seen{@$unmergeditem[0]}++;
    ## See what we're doing here with @$item[0] & @$item[1]? We've actually got a 3D array, so that we can attach multiple bitstreams to a single title.
      push @mergeditems, [@$unmergeditem[0],[@$unmergeditem[1]],[@$unmergeditem[2]],@$unmergeditem[3],];
  }
}

foreach my $dspaceitem (@mergeditems){
  $id++; # count up for each dspace item
  my $title = @$dspaceitem[0];
  my @bitstreamfilenames = @{$dspaceitem->[1]};
  my @bitstreampaths = @{$dspaceitem->[2]};
  my $date = @$dspaceitem[3];

  ## setup for the various directories and filenames
  my $itemdir = $destdir . "\\" . "item_" . $id . '\\';
  my $contentsfile = $itemdir."\\contents";
  my @contents;
 
  
  ## create the item directories if they aren't there already
  if (! -e $itemdir){
    mkpath($itemdir) or die "mkdir Failed.";
  }

  ## Loop through each bitstream in the dspace item
  ## we'll be copying files, assigning subjects based on the original path, etc.
  my @subjects;
  my $idib = -1; # index reference for bitstreams within this item
  foreach my $bitstreampath (@bitstreampaths) {
    if (defined $date) { $ii++; } # count up for each dated bitstream
    $ib++; # count up for each item bitstream
    $idib++;
    my $filename = $bitstreamfilenames[$idib];
    my $newbitstreampath = $itemdir.$filename;
    copy($bitstreampath,$newbitstreampath) or die "Copy of $bitstreampath to $itemdir Failed.";
    ## Copy over original mac times if possible.
    if($^O =~ /mswin32/i){
      (my $atime,my $mtime,my $ctime) = GetFileTime($bitstreampath);
      SetFileTime ($newbitstreampath,$atime,$mtime,$ctime);
    }
    push @contents,$filename;
    push @subjects,&parseSubjects($bitstreampath,$date);
  }
    
  
  ## write a bare-bones metadata file
  my $dublincorefile = $itemdir."\\dublin_core.xml";
  open (DBLNCRXML, ">$dublincorefile");
  print DBLNCRXML "<dublin_core>\n";
  print DBLNCRXML '<dcvalue qualifier="none" element="title">'.$title."</dcvalue>\n";
  if (defined $date) { 
    print DBLNCRXML '<dcvalue qualifier="issued" element="date">'.$date."</dcvalue>\n";
  }
  ## If we have any subjects, add them to the file.
  if (scalar @subjects > 0) {
    ## Again we're de-duping here.
    my %subseen = ();
    foreach my $subject (@subjects) {
        print DBLNCRXML '<dcvalue qualifier="none" element="subject">'.$subject."</dcvalue>\n" unless $subseen{$subject}++;
    }
  }
  print DBLNCRXML '</dublin_core>';
  close DBLNCRXML;

  # "Naturally" sort the contents and then output the contents manifest files.
  my @sortedcontents = nsort @contents;
 
  open (CNTNTS, ">$contentsfile");
  foreach my $entry (@sortedcontents) {
    print CNTNTS "$entry\n";
  }
  close CNTNTS;  
}

print $i . "\tfiles located\n";
print $ii . "\tdated files\n";
print $io . "\tundated files\n";
print $id . "\titems getting imported with\n";
print $ib . "\tbitstreams\n";
## end timer and report
my $end = time();
my $xtime = $end-$start;
printf "Executed in %d days, %d hours, %d minutes and %d seconds.\n",(gmtime $xtime)[7,2,1,0];

sub eachFile {
  my $filename = $_;
  my $fullpath = $File::Find::name;
  return unless ((-e $filename) && (-f $fullpath));   # Don't return directories or non-existent files
  &parseFile($filename,$fullpath);
}

sub parseFile {
  $i++; # count up for each valid file
  my $filename = $_[0];
  my $fullpath = $_[1];
  my $title;
  my $date;
  my $nondate;
  my $yyyy;
  my $yyyyrange;
  my $mm;
  my $month;
  my $dd;
  

  # the first bit identifies two 4-digit years separated with a hyphen;
  if ($filename =~ /^(.*?)(((?<!\d)(18|19|20)(\d){2})-(18|19|20)(\d){2}(?!\d))(.*)$/) {
      $yyyy = $3;
      $date = $yyyy;
      $yyyyrange = $2;
      $nondate =$1.'_'.$8;
  # matches a 4 digit followed by a hypen, then a two digit year if that two digit year is n+1.
  # pretty common notation for an academic year.        
  } elsif ($filename =~ /^(.*?)(((?<!\d)(18|19|20)((\d){2}))-((\d){2})(?!\d))(.*)$/) {
      my $yy1 = $5;
      my $yy2 = $7;  
      if ($yy2 == ($yy1+1)) {
        $yyyyrange = $3.'-'.$4.$7;
      }
      $yyyy = $3;
      $date = $yyyy;
      $nondate =$1.'_'.$9;
      #print "$nondate\t$yyyyrange\t$yyyy\n";
  # matches a 4 digit number starting with 18,19,20 that is neither preceded nor followed by a digit.         
  } elsif ($filename =~ /^(.*?)(((?<!\d)(18|19|20)(\d){2})(?!\d))(.*)$/) {
      $yyyy = $3;
      $date = $yyyy;
      $nondate =$1.'_'.$6;
      #print "$nondate\t$yyyy\n";
  }
  
  ## Once we have the four digit year, get Month and day where the month is named, not a digit
  if (defined $yyyy) {
  my @parsedMonthandDay = &parseMonthandDay($date,$nondate);
  $date = $parsedMonthandDay[0];
  $nondate = $parsedMonthandDay[1];
  $mm = $parsedMonthandDay[2];
  $dd = $parsedMonthandDay[3];
  }

  ## If we don't have the four digit year, search for month, day, and year in mm-dd-yy format.  
  if (!defined $yyyy) {
    my @parsedMMDDYY = &parseMMDDYY($filename);
    $date = $parsedMMDDYY[0];
    $nondate = $parsedMMDDYY[1];
    $yyyy = $parsedMMDDYY[2];
    $mm = $parsedMMDDYY[3];
    $dd = $parsedMMDDYY[4];
  }
  
  ## If we still don't have a year, search for the year and month in Monthyy format
  if (!defined $yyyy) {
    my @parsedMonthYY = &parseMonthYY($filename);
    $date = $parsedMonthYY[0];
    $nondate = $parsedMonthYY[1];
    $yyyy = $parsedMonthYY[2];
    $mm = $parsedMonthYY[3];
  }
  
  if (defined $yyyy) {
  # Once we have extracted any date information, create a natural language title based off the filename  
  $title = &normalizeTitle($nondate);
  # add year or year range to beginning of title
  if (defined $yyyyrange) {
    $title = $yyyyrange.' '.$title;
   } else {
    $title .= ', '.$yyyy;   
   }

  # Send off any completed stuff to the items array
  my @item = [
    $title,  
    $filename,    
    $fullpath,
    $date,    
  ];
  push @unmergeditems, ( @item );
  } else {
    # send any un-IDed stuff to the directory parser
    &parseDir($filename,$fullpath);
  }
}

## Try scraping a directory as a single dspace item with multiple bitstreams.  Used for files that couldn't be IDed on their own
sub parseDir {
  my $filename = $_[0];
  my $fullpath = $_[1];
  my $mask = length($searchdir);
  my $shortpath = substr($fullpath,$mask);
  my $title;
  my $date;
  my $nondate;
  my $yyyy;
  my $yyyyrange;
  my $mm;
  my $month;
  my $dd;

  if ($shortpath =~ /\/([^\/]+)\/([^\/]+)$/) { $shortpath = $1; }

  
# the first bit identifies two 4-digit years separated with a hyphen;
  if ($shortpath =~ /^(.*?)(((?<!\d)(18|19|20)(\d){2})-(18|19|20)(\d){2}(?!\d))(.*)$/) {
      $yyyy = $3;
      $date = $yyyy;
      $yyyyrange = $2;
      $nondate =$1.'_'.$8;
  # matches a 4 digit followed by a hypen, then a two digit year if that two digit year is n+1.
  # pretty common notation for an academic year.        
  } elsif ($shortpath =~ /^(.*?)(((?<!\d)(18|19|20)((\d){2}))-((\d){2})(?!\d))(.*)$/) {
      my $yy1 = $5;
      my $yy2 = $7;  
      if ($yy2 == ($yy1+1)) {
        $yyyyrange = $3.'-'.$4.$7;
      }
      $yyyy = $3;
      $date = $yyyy;
      $nondate =$1.'_'.$9;
      #print "$nondate\t$yyyyrange\t$yyyy\n";
  # matches a 4 digit number starting with 18,19,20 that is neither preceded nor followed by a digit.         
  } elsif ($shortpath =~ /^(.*?)(((?<!\d)(18|19|20)(\d){2})(?!\d))(.*)$/) {
      $yyyy = $3;
      $date = $yyyy;
      $nondate =$1.'_'.$6;
      #print "$nondate\t$yyyy\n";
  }

  if (defined $yyyy) {
  ## If we got the four digit year on the first try, get Month and day where the month is named, not a digit
  my @parsedMonthandDay = &parseMonthandDay($date,$nondate);
  $date = $parsedMonthandDay[0];
  $nondate = $parsedMonthandDay[1];
  $mm = $parsedMonthandDay[2];
  $dd = $parsedMonthandDay[3];
  }

  if (!defined $yyyy) {
    ## If we don't have the four digit year, search for month, day, and year in mm-dd-yy format.
    my @parsedMMDDYY = &parseMMDDYY($shortpath);
    $date = $parsedMMDDYY[0];
    $nondate = $parsedMMDDYY[1];
    $yyyy = $parsedMMDDYY[2];
    $mm = $parsedMMDDYY[3];
    $dd = $parsedMMDDYY[4];
  }
  
  ## If we still don't have a year, search for the year and month in Monthyy format
  if (!defined $yyyy) {
    my @parsedMonthYY = &parseMonthYY($shortpath);
    $date = $parsedMonthYY[0];
    $nondate = $parsedMonthYY[1];
    $yyyy = $parsedMonthYY[2];      
    $mm = $parsedMonthYY[3];
  }  

  if (defined $yyyy) {
    # Once we have extracted any date information, create a natural language title based off the filename
    $title = &normalizeTitle($nondate);
    $title .= ', '.$yyyy;
    # Send off any completed stuff to the items array
    my @item = [
      $title, 
      $filename,    
      $fullpath,   
      $date,    
    ];
    push @unmergeditems, ( @item );
  } else {
    # send any un-IDed stuff to the undated parser
    &parseUndated($filename,$fullpath);
  }
}
## Report on undated items
sub parseUndated {
  my $filename = $_[0];
  my $fullpath = $_[1];
  #my $title = &normalizeTitle($filename);
  $io++;
  ## Get the path down to just the lowest-depth folder name.
  my $mask = length($searchdir);
  my $shortpath = substr($fullpath,$mask);
  if ($shortpath =~ /\/([^\/]+)\/([^\/]+)$/) { $shortpath = $1; }
  $shortpath = &normalizeTitle($shortpath);
  #print "$shortpath\t$title\n";
  my $title = $shortpath;
  my @item = [
    $title,  
    $filename,    
    $fullpath,  
  ];
  push @unmergeditems, ( @item );
}


# Should only be called if you already have a four digit year.
sub parseMonthandDay {
  my $date = $_[0];
  my $nondate = $_[1];
  my $mm;
  my $dd;
  # Matches
  # $1: any stuff
  # $2: Month name not preceded by letters
  # $5 (optional): a 0-39 number preceded by an _ and not followed by a number
  # $8: any stuff 
  if ($nondate =~ /(.*)(?<![A-Za-z])(Jan(uary)?)(?![A-Za-z])((_+)(([0-3]?\d)(?!\d)))?(.*)/i) {
    $mm = '01';
    $date .= '-'.$mm;
    $nondate =$1.'_'.$8;
    if (defined $6) {
      $dd = sprintf '%02s', $6;        
      $date .= '-'.$dd;
    }
  } elsif ($nondate =~ /(.*)(?<![A-Za-z])(Feb(r?ur?ary)?)(?![A-Za-z])((_+)(([0-3]?\d)(?!\d)))?(.*)/i) {
    $mm = '02';
    $date .= '-'.$mm;
    $nondate =$1.'_'.$8;
    if (defined $6) {
      $dd = sprintf '%02s', $6;        
      $date .= '-'.$dd;
    }
  } elsif ($nondate =~ /(.*)(?<![A-Za-z])(Mar(ch)?)(?![A-Za-z])((_+)(([0-3]?\d)(?!\d)))?(.*)/i) {
    $mm = '03';
    $date .= '-'.$mm;
    $nondate =$1.'_'.$8;
    if (defined $6) {
      $dd = sprintf '%02s', $6;        
      $date .= '-'.$dd;
    }
  } elsif ($nondate =~ /(.*)(?<![A-Za-z])(Apri?l?)(?![A-Za-z])((_+)(([0-3]?\d)(?!\d)))?(.*)/i) {
    $mm = '04';
    $date .= '-'.$mm;
    $nondate =$1.'_'.$7;
    if (defined $5) {
      $dd = sprintf '%02s', $5;        
      $date .= '-'.$dd;
    }
  } elsif ($nondate =~ /(.*)(?<![A-Za-z])(May)(?![A-Za-z])((_+)(([0-3]?\d)(?!\d)))?(.*)/i) {
    $mm = '05';
    $date .= '-'.$mm;
    $nondate =$1.'_'.$7;
    if (defined $5) {
      $dd = sprintf '%02s', $5;        
      $date .= '-'.$dd;
    }
  } elsif ($nondate =~ /(.*)(?<![A-Za-z])(June)(?![A-Za-z])((_+)(([0-3]?\d)(?!\d)))?(.*)/i) {
    $mm = '06';
    $date .= '-'.$mm;
    $nondate =$1.'_'.$7;
    if (defined $5) {
      $dd = sprintf '%02s', $5;        
      $date .= '-'.$dd;
    }
  } elsif ($nondate =~ /(.*)(?<![A-Za-z])(July)(?![A-Za-z])((_+)(([0-3]?\d)(?!\d)))?(.*)/i) {
    $mm = '07';
    $date .= '-'.$mm;
    $nondate =$1.'_'.$7;
    if (defined $5) {
      $dd = sprintf '%02s', $5;        
      $date .= '-'.$dd;
    }
  } elsif ($nondate =~ /(.*)(?<![A-Za-z])(Aug(ust)?)(?![A-Za-z])((_+)(([0-3]?\d)(?!\d)))?(.*)/i) {
    $mm = '08';
    $date .= '-'.$mm;
    $nondate =$1.'_'.$8;
    if (defined $6) {
      $dd = sprintf '%02s', $6;        
      $date .= '-'.$dd;
    }
  } elsif ($nondate =~ /(.*)(?<![A-Za-z])(Sept(ember)?)(?![A-Za-z])((_+)(([0-3]?\d)(?!\d)))?(.*)/i) {
    $mm = '09';
    $date .= '-'.$mm;
    $nondate =$1.'_'.$8;
    if (defined $6) {
      $dd = sprintf '%02s', $6;        
      $date .= '-'.$dd;
    }
  } elsif ($nondate =~ /(.*)(?<![A-Za-z])(Oct(ober)?)(?![A-Za-z])((_+)(([0-3]?\d)(?!\d)))?(.*)/i) {
    $mm = '10';
    $date .= '-'.$mm;
    $nondate =$1.'_'.$8;
    if (defined $6) {
      $dd = sprintf '%02s', $6;        
      $date .= '-'.$dd;
    }
  } elsif ($nondate =~ /(.*)(?<![A-Za-z])(Nov(ember)?)(?![A-Za-z])((_+)(([0-3]?\d)(?!\d)))?(.*)/i) {
    $mm = '11';
    $date .= '-'.$mm;
    $nondate =$1.'_'.$8;
    if (defined $6) {
      $dd = sprintf '%02s', $6;
      $date .= '-'.$dd;
    }
  } elsif ($nondate =~ /(.*)(?<![A-Za-z])(Dec(ember)?)(?![A-Za-z])((_+)(([0-3]?\d)(?!\d)))?(.*)/i) {
    $mm = '12';
    $date .= '-'.$mm;
    $nondate =$1.'_'.$8;
    if (defined $6) {
      $dd = sprintf '%02s', $6;        
      $date .= '-'.$dd;
    }
  }
  return ($date,$nondate,$mm,$dd);
}

# Should only be called if can't get a four digit year.
# it's a little more questionable.
sub parseMMDDYY {
  my $pathorname = $_[0];
  my $date;
  my $nondate;
  my $mm;
  my $dd;
  my $yy;
  my $yyyy;

  if ($pathorname =~ /(.*)((?<!\d)(\d{1,2})-(\d{1,2})-(\d{2})(?!\d))(.*)/) {
      # sort out the non-date stuff
      if ((defined $1)&&(defined $6)) {
       $nondate = $1.'_'.$6;
      } elsif ((defined $1)&&(!defined $6)) {
       $nondate = $1;
      } elsif ((!defined $1)&&(defined $6)) {
       $nondate = $6;
      }
      $mm = sprintf '%02s', $3;
      $dd = sprintf '%02s', $4;   
      $yy = $5;

      # take an educated guess as to the century and put together the iso date
      if ($yy =~ /^0/) {$yyyy = '20'.$yy;} else {$yyyy = '19'.$yy;}
      $date = $yyyy;
      $date .= '-'.$mm;
      $date .= '-'.$dd;
 
      #print "$date\t$nondate\n";
      return ($date,$nondate,$yyyy,$mm,$dd);  
  }
}

# Should only be called if can't get a four digit year, or a mm-dd-yy date.
# it's even more questionable.
sub parseMonthYY {
  my $pathorname = $_[0];
  my $date;
  my $nondate;
  my $mm;
  my $yy;
  my $yyyy;
  if ($pathorname =~ /(.*)(?<![A-Za-z])(Jan(uary)?)(?![A-Za-z])((_+)?((\d{2})(?!\d)))(.*)/i) {
    if ((defined $1)&&(defined $8)) {
     $nondate = $1.'_'.$8;
    } elsif ((defined $1)&&(!defined $8)) {
     $nondate = $8;
    } elsif ((!defined $1)&&(defined $8)) {
     $nondate = $8;
    }
    $yy = $6;
    if ($yy =~ /^0/) {$yyyy = '20'.$yy;} else {$yyyy = '19'.$yy;}
    $date = $yyyy;    
    $mm = '01';
    $date .= '-'.$mm;
  } elsif ($pathorname =~ /(.*)(?<![A-Za-z])(Feb(r?ur?ary)?)(?![A-Za-z])((_+)?((\d{2})(?!\d)))(.*)/i) {
    if ((defined $1)&&(defined $8)) {
     $nondate = $1.'_'.$8;
    } elsif ((defined $1)&&(!defined $8)) {
     $nondate = $8;
    } elsif ((!defined $1)&&(defined $8)) {
     $nondate = $8;
    }
    $yy = $6;
    if ($yy =~ /^0/) {$yyyy = '20'.$yy;} else {$yyyy = '19'.$yy;}
    $date = $yyyy;    
    $mm = '02';
    $date .= '-'.$mm;
  } elsif ($pathorname =~ /(.*)(?<![A-Za-z])(Mar(ch)?)(?![A-Za-z])((_+)?((\d{2})(?!\d)))(.*)/i) {
    if ((defined $1)&&(defined $8)) {
     $nondate = $1.'_'.$8;
    } elsif ((defined $1)&&(!defined $8)) {
     $nondate = $8;
    } elsif ((!defined $1)&&(defined $8)) {
     $nondate = $8;
    }
    $yy = $6;
    if ($yy =~ /^0/) {$yyyy = '20'.$yy;} else {$yyyy = '19'.$yy;}
    $date = $yyyy;    
    $mm = '03';
    $date .= '-'.$mm;
  } elsif ($pathorname =~ /(.*)(?<![A-Za-z])(Apri?l?)(?![A-Za-z])((_+)?((\d{2})(?!\d)))(.*)/i) {
    if ((defined $1)&&(defined $7)) {
     $nondate = $1.'_'.$7;
    } elsif ((defined $1)&&(!defined $7)) {
     $nondate = $7;
    } elsif ((!defined $1)&&(defined $7)) {
     $nondate = $7;
    }
    $yy = $5;
    if ($yy =~ /^0/) {$yyyy = '20'.$yy;} else {$yyyy = '19'.$yy;}
    $date = $yyyy;
    $mm = '04';
    $date .= '-'.$mm;
  } elsif ($pathorname =~ /^(.*)(?<![A-Za-z])(May)(?![A-Za-z])((_+)?((\d{2})(?!\d)))(.*)$/i) {
    if ((defined $1)&&(defined $7)) {
     $nondate = $1.'_'.$7;
    } elsif ((defined $1)&&(!defined $7)) {
     $nondate = $7;
    } elsif ((!defined $1)&&(defined $7)) {
     $nondate = $7;
    }
    $yy = $5;
    if ($yy =~ /^0/) {$yyyy = '20'.$yy;} else {$yyyy = '19'.$yy;}
    $date = $yyyy;
    $mm = '05';
    $date .= '-'.$mm;  
  } elsif ($pathorname =~ /(.*)(?<![A-Za-z])(June)(?![A-Za-z])((_+)?((\d{2})(?!\d)))(.*)/i) {
    if ((defined $1)&&(defined $7)) {
     $nondate = $1.'_'.$7;
    } elsif ((defined $1)&&(!defined $7)) {
     $nondate = $7;
    } elsif ((!defined $1)&&(defined $7)) {
     $nondate = $7;
    }
    $yy = $5;
    if ($yy =~ /^0/) {$yyyy = '20'.$yy;} else {$yyyy = '19'.$yy;}
    $date = $yyyy;
    $mm = '06';
    $date .= '-'.$mm;
  } elsif ($pathorname =~ /(.*)(?<![A-Za-z])(July)(?![A-Za-z])((_+)?((\d{2})(?!\d)))(.*)/i) {
    if ((defined $1)&&(defined $7)) {
     $nondate = $1.'_'.$7;
    } elsif ((defined $1)&&(!defined $7)) {
     $nondate = $7;
    } elsif ((!defined $1)&&(defined $7)) {
     $nondate = $7;
    }
    $yy = $5;
    if ($yy =~ /^0/) {$yyyy = '20'.$yy;} else {$yyyy = '19'.$yy;}
    $date = $yyyy;
    $mm = '07';
    $date .= '-'.$mm;
  } elsif ($pathorname =~ /(.*)(?<![A-Za-z])(Aug(ust)?)(?![A-Za-z])((_+)?((\d{2})(?!\d)))(.*)/i) {
    if ((defined $1)&&(defined $8)) {
     $nondate = $1.'_'.$8;
    } elsif ((defined $1)&&(!defined $8)) {
     $nondate = $8;
    } elsif ((!defined $1)&&(defined $8)) {
     $nondate = $8;
    }
    $yy = $6;
    if ($yy =~ /^0/) {$yyyy = '20'.$yy;} else {$yyyy = '19'.$yy;}
    $date = $yyyy;    
    $mm = '08';
    $date .= '-'.$mm;
  } elsif ($pathorname =~ /(.*)(?<![A-Za-z])(Sept(ember)?)(?![A-Za-z])((_+)?((\d{2})(?!\d)))(.*)/i) {
    if ((defined $1)&&(defined $8)) {
     $nondate = $1.'_'.$8;
    } elsif ((defined $1)&&(!defined $8)) {
     $nondate = $8;
    } elsif ((!defined $1)&&(defined $8)) {
     $nondate = $8;
    }
    $yy = $6;
    if ($yy =~ /^0/) {$yyyy = '20'.$yy;} else {$yyyy = '19'.$yy;}
    $date = $yyyy;    
    $mm = '09';
    $date .= '-'.$mm;
  } elsif ($pathorname =~ /(.*)(?<![A-Za-z])(Oct(ober)?)(?![A-Za-z])((_+)?((\d{2})(?!\d)))(.*)/i) {
    if ((defined $1)&&(defined $8)) {
     $nondate = $1.'_'.$8;
    } elsif ((defined $1)&&(!defined $8)) {
     $nondate = $8;
    } elsif ((!defined $1)&&(defined $8)) {
     $nondate = $8;
    }
    $yy = $6;
    if ($yy =~ /^0/) {$yyyy = '20'.$yy;} else {$yyyy = '19'.$yy;}
    $date = $yyyy;    
    $mm = '10';
    $date .= '-'.$mm;
  } elsif ($pathorname =~ /(.*)(?<![A-Za-z])(Nov(ember)?)(?![A-Za-z])((_+)?((\d{2})(?!\d)))(.*)/i) {
    if ((defined $1)&&(defined $8)) {
     $nondate = $1.'_'.$8;
    } elsif ((defined $1)&&(!defined $8)) {
     $nondate = $8;
    } elsif ((!defined $1)&&(defined $8)) {
     $nondate = $8;
    }
    $yy = $6;
    if ($yy =~ /^0/) {$yyyy = '20'.$yy;} else {$yyyy = '19'.$yy;}
    $date = $yyyy;    
    $mm = '11';
    $date .= '-'.$mm;
  } elsif ($pathorname =~ /(.*)(?<![A-Za-z])(Dec(ember)?)(?![A-Za-z])((_+)?((\d{2})(?!\d)))(.*)/i) {
    if ((defined $1)&&(defined $8)) {
     $nondate = $1.'_'.$8;
    } elsif ((defined $1)&&(!defined $8)) {
     $nondate = $8;
    } elsif ((!defined $1)&&(defined $8)) {
     $nondate = $8;
    }
    $yy = $6;
    if ($yy =~ /^0/) {$yyyy = '20'.$yy;} else {$yyyy = '19'.$yy;}
    $date = $yyyy;
    $mm = '12';
    $date .= '-'.$mm;
  }
  return ($date,$nondate,$yyyy,$mm);
}

## Assign subjects based on the year or file path
## Should be run after the items are merged and should be run on each bitstream.
## Check with Kelly about the institution change dates.
sub parseSubjects {
  my $fullpath = $_[0];
  my $date = $_[1];
  my $yyyy;
  if (defined $date) {
    $yyyy = substr($date,0,4);
  }
  my @subjects;
  ## Start with date-dependent subjects.
  ## For institution subjects, note that we're allowing overlap on the
  ## year of the name change; the conditions are not exclusive
  if (defined $yyyy) {
    ## OIIC officially lasted until 1916...
    if (($yyyy >= 1908)&&($yyyy <= 1916)) {
      push(@subjects,'Oklahoma Industrial Institute and College for Girls');
    }
    ## ...but unofficially, OCW started on July 22, 1912.
    if (($yyyy >= 1912)&&($yyyy <= 1965)) {
      push(@subjects,'Oklahoma College for Women');
    }
    ## Change to OCLA: August 1, 1965.
    if (($yyyy >= 1965)&&($yyyy <= 1974)) {
      push(@subjects,'Oklahoma College of Liberal Arts');
    }
  ## Change to USAO: June 1, 1974
    if ($yyyy >= 1974) {
      push(@subjects,'University of Science and Arts of Oklahoma');
    }
  ## If we don't have a year, try to get the appropriate institution from the file or folder name.
  ## We're being conservative here, so the conditions are exclusive.
  } else {
    if ($fullpath =~ /(OIIC)/i) {
      push(@subjects,'Oklahoma Industrial Institute and College for Girls');
    } elsif ($fullpath =~ /(OCW)/i) {
      push(@subjects,'Oklahoma College for Women');
    } elsif ($fullpath =~ /(OCLA)/i) {
      push(@subjects,'Oklahoma College of Liberal Arts');
    } elsif ($fullpath =~ /(USAO)/i) {
      push(@subjects,'University of Science and Arts of Oklahoma');
    }
  }
  ## Non-date related subjects
  ## People.
  if ($fullpath =~ /(Anna[^A-Za-z]?Lewis|Lewis[^A-Za-z]?Anna)/i) {
      push(@subjects,'Lewis, Anna');
  }  
  
  ## Campus groups
  if ($fullpath =~ /(Be[^A-Za-z]?Si[^A-Za-z]?Ta)/i) {
      push(@subjects,'Societies and clubs');
      push(@subjects,'Be Si Ta');
  }
  if ($fullpath =~ /(Chi[^A-Za-z]?Delta[^A-Za-z]?Phi)/i) {
      push(@subjects,'Societies and clubs');
      push(@subjects,'Chi Delta Phi');
  }
  if ($fullpath =~ /(De[^A-Za-z]?Gamma[^A-Za-z]?Ve)/i) {
      push(@subjects,'Societies and clubs');
      push(@subjects,'De Gamma Ve');
  }
  if ($fullpath =~ /(Eche[^A-Za-z]?Sa)/i) {
      push(@subjects,'Societies and clubs');
      push(@subjects,'Eche Sa');
  }
  if ($fullpath =~ /(Em[^A-Za-z]?Hi)/i) {
      push(@subjects,'Societies and clubs');
      push(@subjects,'Em Hi');
  }
  if ($fullpath =~ /(Phi[^A-Za-z]?Psi)/i) {
      push(@subjects,'Societies and clubs');
      push(@subjects,'Phi Psi');
  }
  if ($fullpath =~ /(Sigma[^A-Za-z]?Delta)/i) {
      push(@subjects,'Societies and clubs');
      push(@subjects,'Sigma Delta');
  }
  if ($fullpath =~ /(Tri[^A-Za-z]?D)/i) {
      push(@subjects,'Societies and clubs');
      push(@subjects,'Tri D');
  }
  if ($fullpath =~ /(French[^A-Za-z]?Club)/i) {
      push(@subjects,'Societies and clubs');
      push(@subjects,'French Club');
  }
  if ($fullpath =~ /(German[^A-Za-z]?Club)/i) {
      push(@subjects,'Societies and clubs');
      push(@subjects,'German Club');
  }
  if ($fullpath =~ /(Q[^A-Za-z]?Club)/i) {
      push(@subjects,'Societies and clubs');
      push(@subjects,'Q Club');
  }
  if ($fullpath =~ /(Student[^A-Za-z]?Government|SGA)/i) {
      push(@subjects,'Societies and clubs');
      push(@subjects,'Student Government Association');
  }

  ## Sports
  if ($fullpath =~ /Sports/i) {
      push(@subjects,'Sports');
  }
  if ($fullpath =~ /Archery?/i) {
      push(@subjects,'Archery');
      push(@subjects,'Sports');
  }
  if ($fullpath =~ /Base[^A-Za-z]?ball/i) {
      push(@subjects,'Baseball');
      push(@subjects,'Sports');
  }
  if ($fullpath =~ /Basket[^A-Za-z]?ball/i) {
      push(@subjects,'Basketball');
      push(@subjects,'Sports');
  }
  if ($fullpath =~ /Bowling/i) {
      push(@subjects,'Bowling');
      push(@subjects,'Sports');
  }
  if ($fullpath =~ /(Field[^A-Za-z]?Hockey|Hockey[^A-Za-z]?Field)/i) {
      push(@subjects,'Field Hockey');
      push(@subjects,'Sports');
  }
  if ($fullpath =~ /Foot[^A-Za-z]?ball/i) {
      push(@subjects,'Football');
      push(@subjects,'Sports');
  }
  if ($fullpath =~ /Golf/i) {
      push(@subjects,'Golf');
      push(@subjects,'Sports');
  }
  if ($fullpath =~ /(Horse(back)?[^A-Za-z]?Riding)/i) {
      push(@subjects,'Horseback Riding');
      push(@subjects,'Sports');
  }
  if ($fullpath =~ /Soft[^A-Za-z]?ball/i) {
      push(@subjects,'Softball');
      push(@subjects,'Sports');
  }
  if ($fullpath =~ /Tennis/i) {
      push(@subjects,'Tennis');
      push(@subjects,'Sports');
  }
  if ($fullpath =~ /(Track[^A-Za-z]?(and|&)?[^A-Za-z]?Field)/i) {
      push(@subjects,'Track and Field');
      push(@subjects,'Sports');
  }
  if ($fullpath =~ /(Volley([^A-Za-z])?ball)/i) {
      push(@subjects,'Volleyball');
      push(@subjects,'Sports');
  }

  ## Other activities.
  ## Swimming isn't under sports since we have a lot of non-sporting swimming content.
  ## If sports is in the path, it will get added on its own.
  if ($fullpath =~ /Swim/i) {
      push(@subjects,'Swimming');
  }

  ## Events.
  if ($fullpath =~ /(Montmartre)/i) {
      push(@subjects,'Events');
      push(@subjects,'Festival');
      push(@subjects,'Spring Triad');
      push(@subjects,'Montmartre');
  }
  if ($fullpath =~ /(Drover[^A-Za-z]?stock)/i) {
      push(@subjects,'Events');
      push(@subjects,'Festival');
      push(@subjects,'Spring Triad');
      push(@subjects,'Droverstock');
  }
  if ($fullpath =~ /(Scholastic([^A-Za-z])?Meet)/i) {
      push(@subjects,'Events');
      push(@subjects,'Spring Triad');
      push(@subjects,'Scholastic Meet');
  }

  ## Campus features and buildings.
  ## Classification can be a bit tricky since buildings were re-purposed over the years.
  ## Find out the dates that various buildings served various purposes.
  if ($fullpath =~ /Oval/i) {
      push(@subjects,'College Campuses');
  }
  if ($fullpath =~ /Student[^A-Za-z]?Union/i) {
      push(@subjects,'College Campuses');
      push(@subjects,'Buildings');
      push(@subjects,'Student Unions');
  }
  ## It's the Sparks Hall Dorm if it has Nellie Sparks or Sparks Hall in the name.
  ## There is almost no information about Nellie Sparks the individual,
  ## so there's only a small chance of mis-classification.
  if ($fullpath =~ /Sparks[^A-Za-z]?Hall|Nellie[^A-Za-z]?Sparks/i) {
    push(@subjects,'College Campuses');
    push(@subjects,'Buildings');
    push(@subjects,'Dormitories');
    push(@subjects,'Sparks Hall');
  }
  ## Addams Hall, another dorm.  Check years.
  if ($fullpath =~ /Addams/i) {
    push(@subjects,'College Campuses');
    push(@subjects,'Buildings');
    push(@subjects,'Dormitories');
    push(@subjects,'Addams Hall');
  }
  ## Willard Hall, another dorm.  Check years.
  if ($fullpath =~ /Willard/i) {
    push(@subjects,'College Campuses');
    push(@subjects,'Buildings');
    push(@subjects,'Dormitories');
    push(@subjects,'Willard Hall');
  }
  ## Lawson Hall/Court, another dorm.  Later an an apartment complex. Check years.
  if ($fullpath =~ /Lawson/i) {
    push(@subjects,'College Campuses');
    push(@subjects,'Buildings');
    push(@subjects,'Dormitories');
    push(@subjects,'Lawson Hall');
  }
  ## If it at least has dorm in the name, we know it's probably some kind of dormitory
  if ($fullpath =~ /Dorm/i) {
    push(@subjects,'College Campuses');
    push(@subjects,'Buildings');
    push(@subjects,'Dormitories');
  }
  return @subjects;
}

sub getMonthfromMM {
  my $mm = $_[0];
  my $month;
  if ($mm == '01') {
    $month = 'January';
  } elsif ($mm == '02') {
    $month = 'February';
  } elsif ($mm == '03') {
    $month = 'March';
  } elsif ($mm == '04') {
    $month = 'April';
  } elsif ($mm == '05') {
    $month = 'May';
  } elsif ($mm == '06') {
    $month = 'June';
  } elsif ($mm == '07') {
    $month = 'July';
  } elsif ($mm == '08') {
    $month = 'August';
  } elsif ($mm == '09') {
    $month = 'September';
  } elsif ($mm == '10') {
    $month = 'October';
  } elsif ( $mm == '11') {
    $month = 'November';
  } elsif ( $mm == '12') {
    $month = 'December';
  }
  return $month;
}

sub normalizeTitle {
  # create a natural language title based off the filename
  my $title =  $_[0];
  $title =~ s/&/and/g;             # replace ampersand with "and".
  $title =~ s/[-\\\/]/_/g;             # replace any hyphens or slashes with underscores.
  $title =~ s/(_)(?=_*?\1)//g;         # collapse double underscores
  $title =~ s/^[ _\.]+|[ _\.]+$//g;    # strip leading and trailing underscores, dots, & spaces
  $title =~ s/[_]s([_\.])/\'s_$1/g;    # fix up apostrophe s situations
  $title =~ s/[_]/ /g;                 # replace underscores with spaces
  $title =~ s/( )(?= *?\1)//g;         # collapse double spaces  
  $title =~ s/(.+)(\.[A-Za-z]{3})$/$1/;# drop file extension
  
  ## Get rid of any numbering for files in the same series
  $title =~ s/(.+)(( ?)(Part )|(Page )|(Side ))((\d+)|([IXVM]+))$/$1/i; # drop appended file numbering
  $title =~ s/(.+)(?<!\d)\d+$/$1/i;                                     # drop remaining appended file numbering  
  $title =~ s/( )$//;                                                   # drop any newly created trailing space
  
  ## Some by-hand fixes
  $title =~ s/ Old Scanner//i;
  $title =~ s/ 1200 ?DPI//i;
  $title =~ s/\bOCW(?=[^ ])(.+)/OCW $1/ig;
  $title =~ s/Courts/Court/i;
  $title =~ s/Gardens/Garden/i;
  $title =~ s/^BEST AERIALS$|^Lawson Aerial$/Aerial Photographs of Campus/i;
  $title =~ s/^The Argus$/Argus/i;
  $title =~ s/DiningRoom/Dining Room/ig;
  $title =~ s/AnnaLewis/Anna Lewis/ig;
  $title =~ s/BeSiTa/Be Si Ta/ig;
  $title =~ s/CAMPUS/Campus/ig;
  $title =~ s/TROUTTs/Troutt's/ig;
  
  ## Un-abbreviate some things
  $title =~ s/\bADMINI\b/Administration/i;
  $title =~ s/HPER/Health and Physical Education Center/ig;
  $title =~ s/Bldg/Building/ig;
  $title =~ s/Xmas/Christmas/ig;
  
  ## Some Capitalization normalization
  $title =~ s/^([A-Z ]*)$/\F$1/;                                             # If the title is ALL CAPS, Convert It To Capitalized  
  $title =~ s/\b([a-z])/\U$1/g;                                              # Capitalize the start of any word
  $title =~ s/(?<![A-Za-z])(At|In|As|And|Or|The|Towards|To|For|From|On|Of)(?![A-Za-z])/\L$1/g;# De-capitalize any article
  $title =~ s/\'([A-Z])/\L\'$1/g;                                            # De-capitalize any letter after an apostrophe  
  $title =~ s/^([a-z])/\U$1/;                                                # Capitalize anything at the start
  $title =~ s/\b(usao|ocla|ocw|oiic)\b/\U$1/gi;                              # Capitalize our institution abbreviations
 
  return $title;
}

# Called if a duplicate item has been found.
sub addBitstreamToItem {
  my $title = $_[0];  
  my $filename = $_[1];
  my $fullpath = $_[2];
  # It searches the merged item list for a match and then adds the bitstream from the duplicate title.
  # So a single record can contain multiple bitstreams.
  foreach my $mergeditem (@mergeditems){
    if (@$mergeditem[0] eq $title) {
     push @$mergeditem[1],$filename;    
     push @$mergeditem[2],$fullpath;
    }
  }
}
