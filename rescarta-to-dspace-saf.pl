#!/usr/bin/perl
use strict;
use warnings;
use File::Copy; 
use File::Find;
use File::Path;
if($^O =~ /mswin32/i){
  use Win32API::File::Time qw{:win}
}
use XML::XPath;
use XML::XPath::XMLParser;

print '
Rescarta to DSpace conversion.

This script implements a straightforward and feature-incomplete batch
conversion of Rescarta items to DSpace items. It was created to meet
the immediate needs of my library, not to meet all needs of all libraries.

Still, if you have tried this script and found it wanting, please email me
Jason Sherman <jsn.sherman@gmail.com>
and let me know.  If you include a description of the issue and attach the
Rescarta metadata that\'s giving you trouble, I\'ll see what I can do.

';
print "\nEnter absolute path of the collection:\n";
print '
 eg.
Windows: C:\Users\Archive\RCDATA01
or 
Linux/Unix: /home/Archive/RCDATA01
';
my $inputpath = <STDIN>;
chomp $inputpath;
print "\nEnter name the destination directory:\n";
my $destdir = <STDIN>;
chomp $destdir;
my $inputmetadata = $inputpath . '/metadata.xml';

my @SAFBatches;

print "\nConverting...\n";
# create an object to parse the file and field XPath queries
my $xpath = XML::XPath->new(filename=>$inputmetadata);

# apply the path from the command line and get back a list matches
my $collectionset = $xpath->find('/mets/structMap[@TYPE="LOGICAL"]/div[@TYPE="collections"]/div[@TYPE="collection"]');

## Each collection will get its own DSpace SAF Batch folder.
my $c = -1;  # Start a collection array counter
foreach my $collection ( $collectionset->get_nodelist ) {
  $c++;     # Not just a language...
  my $collectionID;
  my $titlepath;

  $collectionID = $collection->getAttribute("DMDID");
  $titlepath = '/mets/dmdSec[@ID="'.$collectionID.'"]/mdWrap/xmlData/mods:mods/mods:titleInfo/mods:title';
  my $collectiontitle = $xpath->findvalue($titlepath);
  
  # print each collection node in the list
  my $SAFBatchTitle = $collectiontitle. '_' . $collectionID;
  #print "$SAFBatchTitle\n";
  push @SAFBatches, [$SAFBatchTitle];

  ## Loop through each item in the collection and scoop up metadata
  foreach my $item ($collection->findnodes('div')) {

    my $itemID = $item->getAttribute("DMDID");
    my $itemType = $item->getAttribute("TYPE");
    my $itemPath = '/mets/dmdSec[@ID="'.$itemID.'"]/mdWrap/xmlData/mods:mods';
    my $itemTitle = $xpath->findvalue($itemPath.'/mods:titleInfo[@type!=\'alternative\']/mods:title');
    my $itemAltTitle = $xpath->findvalue($itemPath.'/mods:titleInfo[@type=\'alternative\']/mods:title');
    my $itemAuthor = $xpath->findvalue($itemPath.'/mods:name/mods:role[mods:roleTerm=\'aut\']/../mods:namePart');
    my $itemEditor = $xpath->findvalue($itemPath.'/mods:name/mods:role[mods:roleTerm=\'edt\']/../mods:namePart');
    my $itemPub = $xpath->findvalue($itemPath.'/mods:originInfo/mods:publisher');
    my $itemDate = $xpath->findvalue($itemPath.'/mods:originInfo/mods:dateIssued');
    my $itemExtent = $xpath->findvalue($itemPath.'/mods:physicalDescription/mods:extent');
    my $itemStartPage = $xpath->findvalue($itemPath.'/mods:part/mods:extent/mods:start');
    my $itemEndPage = $xpath->findvalue($itemPath.'/mods:part/mods:extent/mods:end');
    my $itemAbstract = $xpath->getNodeText($itemPath.'/mods:abstract');
    my $itemURL = $xpath->getNodeText($itemPath.'/mods:location/mods:url');
    my @itemSubjectNodes = $xpath->findnodes($itemPath.'/mods:subject/mods:topic');
    my @geoSubjectNodes = $xpath->findnodes($itemPath.'/mods:subject/mods:hierarchicalGeographic/*');
    ## Loop through each subject in the item
    my @itemSubjects;
    foreach my $itemSubjectNode (@itemSubjectNodes){
      my $itemSubject = $itemSubjectNode->findvalue('.');
      ## If it's a hierarchical subject, split it up.
      my @itemSplitSubject;
      if (index($itemSubject,' -- ') ne -1) {
        @itemSplitSubject = split(' -- ',$itemSubject);
        foreach my $itemSplitSubject (@itemSplitSubject) {
          #print "\t$itemSplitSubject\n";
          push @itemSubjects, $itemSplitSubject;
        }
      ## Otherwise, take it as is.
      } else {
        #print "\t$itemSubject\n";
          push @itemSubjects, $itemSubject;
      }
    }
    ## Loop through each hierarchical geographic subject in the item
    my @geoSubjects;
    foreach my $geoSubjectNode (@geoSubjectNodes){
      my $geoSubjectAttr = substr($geoSubjectNode->getName('.'),5);
      my $geoSubjectVal = $geoSubjectNode->findvalue('.');
      if ($geoSubjectVal) {
        my $geoSubject = $geoSubjectVal .' ('. $geoSubjectAttr .')';
        push @geoSubjects, $geoSubject;
      }
    }
    ## Check these data strutures....
    ## maybe the best route is to have a hash for each item, with an array for the subjects key?
    push @{SAFBatches[$c]},[
      [$itemID, $itemType, $itemPath, $itemTitle, $itemAltTitle, $itemAuthor, $itemEditor, $itemPub, $itemDate, $itemExtent, $itemStartPage, $itemEndPage, $itemAbstract, $itemURL],
      [@itemSubjects],
      [@geoSubjects]
    ];
  }
}

for my $SAFBatch (@SAFBatches) {
  my $batchDir = $SAFBatch->[0];
  print "$batchDir\n";
  for my $i ( 1 .. @{$SAFBatch}) { # iterate over each item in the batch. Index 0 refers to the batch id, so start with 1
    ## General item info lives at [0]; Subjects live at [1]; geoSubjects live at [2];
    if (@$SAFBatch->[$i]) { 
      my $item = @$SAFBatch->[$i][0];
      my @subjectAoA = @$SAFBatch->[$i][1];
      my @geoSubjectAoA = @$SAFBatch->[$i][2];  
      my $itemID = &normalizeTitle($item->[0]);
      my $itemType = &normalizeTitle($item->[1]);
      my $itemPath = $item->[2];
      my $itemTitle = &normalizeTitle($item->[3]);
      my $itemAltTitle = &normalizeTitle($item->[4]);
      ## All of the contributors should probably be broken out into an array in case there are multiples of the same type.
      my $itemAuthor = &normalizeTitle($item->[5]);
      my $itemEditor = &normalizeTitle($item->[6]);
      my $itemPub = &normalizeTitle($item->[7]);
      my $itemDate = $item->[8];
      my $itemExtent = $item->[9];
      my $itemStartPage = $item->[10];
      my $itemEndPage = $item->[11];
      my $itemAbstract = &normalizeTitle($item->[12]);
      my $itemURL = $item->[13];
      ## setup for the various directories and filenames
      my $itemdir = $destdir . '/' . $batchDir . '/' . "item_" . $i . '/';
      my $contentsfile = $itemdir.'/contents';
      my $dublincorefile = $itemdir.'/dublin_core.xml';
      my $perItemMetadata = $inputpath . '/' . $itemURL . '/metadata.xml';
      ## create the item directories if they aren't there already
      if (! -e $itemdir){
        mkpath($itemdir) or die "mkdir Failed.";
      }
      
      ## Each Rescarta item has its own metadata file with the bitstreams listed in the desired order
      ## We'll check them for each item, and then print them to the contents file
      my @contents = &attachBitstreams($perItemMetadata);
      my $cmd;
      #We'll see if we can send off any images to be put together by ABBY Reader
      if($^O =~ /mswin32/i){
        chdir($inputpath . '/' . $itemURL . '/') or die "$!";
        ## On Windows, we use ABBYY FineReader to create OCRed PDF/A documents for each item.  This just saves a step.
        $cmd = "\"C:/Program Files (x86)/ABBYY FineReader 11/FineCmd.exe\"";
      }
      open (CNTNTS, ">$contentsfile");
      foreach my $bitstream (@contents) {
        print CNTNTS "$bitstream\n";
        my $oldbitstreampath = $inputpath . '/' . $itemURL . '/' . $bitstream;
        my $newbitstreampath = $itemdir . '/' . $bitstream;
        copy($oldbitstreampath,$newbitstreampath) or die "Copy of $oldbitstreampath to $itemdir Failed.";
        ## Copy over original mac times if possible.
        if($^O =~ /mswin32/i){
          (my $atime,my $mtime,my $ctime) = GetFileTime($oldbitstreampath);
          SetFileTime ($newbitstreampath,$atime,$mtime,$ctime);
          unless($bitstream eq 'metadata.xml'){
            $cmd .= " $bitstream";
          }
        }
      }
      close CNTNTS;

      ## Uncomment the lines below if you actually want to send the items to ABBYYFineReader
      ## You'll have to manually save each PDF and add it to the DSpace item.
      #print "Calling ABBYY FineReader 11...\n";
      #system($cmd);
      
      ## write a bare-bones metadata file
      ## I should really be writing this out with one of the many excellent XML modules available for perl,
      ## but it's just so dang simple.
      open (DBLNCRXML, ">$dublincorefile");
      print DBLNCRXML "<dublin_core>\n";
      print DBLNCRXML '<dcvalue qualifier="none" element="title">'.$itemTitle."</dcvalue>\n";
      print DBLNCRXML '<dcvalue qualifier="alternative" element="title">'.$itemAltTitle."</dcvalue>\n";
      print DBLNCRXML '<dcvalue qualifier="author" element="contributor">'.$itemAuthor."</dcvalue>\n";
      print DBLNCRXML '<dcvalue qualifier="editor" element="contributor">'.$itemEditor."</dcvalue>\n";
      print DBLNCRXML '<dcvalue qualifier="issued" element="date">'.$itemDate."</dcvalue>\n";
      print DBLNCRXML '<dcvalue qualifier="none" element="publisher">'.$itemPub."</dcvalue>\n";
      if ($itemType =~ /Serial|Monograph/i) {
        print DBLNCRXML '<dcvalue qualifier="none" element="type">Text</dcvalue>'."\n";
      }
      print DBLNCRXML '<dcvalue qualifier="none" element="type">'.$itemType."</dcvalue>\n";
      print DBLNCRXML '<dcvalue qualifier="extent" element="format">'.$itemExtent."</dcvalue>\n";
      print DBLNCRXML '<dcvalue qualifier="extent" element="format">Pages: '. "$itemStartPage-$itemEndPage</dcvalue>\n";
      print DBLNCRXML '<dcvalue qualifier="abstract" element="description">'.$itemAbstract."</dcvalue>\n";
      ## If we have any Geo subjects, add them to the file.
      if (scalar @geoSubjectAoA > 0) {
        ## Again we're de-duping here.
        my %geosubseen = ();
        foreach my $geoSubjectArray (@geoSubjectAoA) {
          foreach my $geoSubject (@{$geoSubjectArray}) {
            print DBLNCRXML '<dcvalue qualifier="spatial" element="coverage">'.$geoSubject."</dcvalue>\n" unless $geosubseen{$geoSubject}++;
          }
        }
      }      
      ## If we have any regular subjects, add them to the file.
      if (scalar @subjectAoA > 0) {
        ## Again we're de-duping here.
        my %subseen = ();
        foreach my $subjectArray (@subjectAoA) {
          foreach my $subject (@{$subjectArray}) {
            $subject = &normalizeTitle($subject);
            print DBLNCRXML '<dcvalue qualifier="none" element="subject">'.$subject."</dcvalue>\n" unless $subseen{$subject}++;
          }
        }
      }
      print DBLNCRXML '</dublin_core>';
      close DBLNCRXML;
      print "Item $i complete\n";   
    }
  }
}

sub attachBitstreams {
  my @contents;
  my $perItemMetadata = $_[0];
  ## Look into each item's metadata.xml file to get the correct order of files.
  ## Create an object to parse the file and field XPath queries
  my $itemXpath = XML::XPath->new(filename=>$perItemMetadata);
  ## Each filegroup will contain a set of files.  
  my $fileGrp = $itemXpath->find('/mets:mets/mets:fileSec/mets:fileGrp/mets:file/mets:FLocat');
  foreach my $fileNode ( $fileGrp->get_nodelist ) { ## Loop through those
    my $xlinkHref = $fileNode->getAttribute('xlink:href'); ## Get the attribute with the path
    my $bitstream;
    if ($xlinkHref =~ /([^\/]+)$/) { $bitstream = $1; } ## Cut it down to just the filename
      push @contents, $bitstream;
    }
  ## We'll even throw in the per-item metadata file into the SAF in case it's useful later.
  push @contents, 'metadata.xml';
  return @contents;
}

## I pulled this straight out of another script I wrote for scraping fileshares.
## I left out some of the stuff that was grossly inappropriate for this use,
## but it may need to be changed to suit your purpose.
sub normalizeTitle {
  # create a natural language title based off the filename
  my $title =  $_[0];
  $title =~ s/&/and/g;                 # replace ampersand with "and".
  $title =~ s/^[ _\.]+|[ _\.]+$//g;    # strip leading and trailing underscores, dots, & spaces
  $title =~ s/( )(?= *?\1)//g;         # collapse double spaces

  
  ## Some Capitalization normalization
  $title =~ s/^([A-Z ]*)$/\F$1/;                                             # If the title is ALL CAPS, Convert It To Capitalized  
  $title =~ s/(?<![A-Za-z])(At|In|As|And|Or|The|Towards|To|For|From|On|Of)(?![A-Za-z])/\L$1/g;# De-capitalize any article
  $title =~ s/\'([A-Z])/\L\'$1/g;                                            # De-capitalize any letter after an apostrophe  
  $title =~ s/^([a-z])/\U$1/;                                                # Capitalize anything at the start
  $title =~ s/\b(usao|ocla|ocw|oiic)\b/\U$1/gi;                              # Capitalize our institution abbreviations
 
  return $title;
}
