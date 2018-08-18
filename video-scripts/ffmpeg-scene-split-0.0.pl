#!/usr/bin/perl
use strict;
use warnings;

print '
FFmpeg Scene Splitter
System Requirements.

1.	This program relies on FFmpeg, so make sure you have it installed
    and included in PATH or living in the same directory as this script.

Program description.

1.	Calls ffprobe to do scene detection and get timestamps of the keyframes.

2.	Copies out each scene to a new file by demux (rather than transcode).
';

print "\nEnter name of video to be butchered:\n";
my $inputfile = <STDIN>;
chomp $inputfile;
#my @timestamps;


#my $cmdprobe = 'ffprobe -show_frames -of compact=p=0 -f lavfi ' . '"movie=' . $inputfile . ',select=gt(scene\,.8)"' . '2>NUL';
#print "\nProcessing\n";
#print "this will take some time...\n";
#open my $fh, "$cmdprobe |" or die "Can't execute: $!";
#my @ffprobe = <$fh>;
#foreach my $output (@ffprobe) {
#  if ($output =~ s/.*pkt_pts_time=([0-9.]{8,})\|.*/$1/) {
#    print "$1\n";
#	push (@timestamps, $1);
#  }
#}
#close $fh or die "Can't close pipe: $!";

## It's best to start at the beginning...
my $starttime = 0.000000;

my @timestamps = (53.253253,54.320988,413.713714,944.377711,945.145145);
my $i = 0;
foreach my $timestamp (@timestamps) {
  $i++;
  ## The last scene will have a slightly different command...
  if(  $timestamp == @timestamps[-1]  ) {
	my $cmdscene = 'ffmpeg -i ' . $inputfile . ' -ss ' . $starttime . ' -acodec copy -vcodec copy ' . $i . $inputfile;
	print "\nProcessing\n";
	print "this will take some time...\n";
	open my $fh, "$cmdscene |" or die "Can't execute: $!";
  } else {
	my $cmdscene = 'ffmpeg -i ' . $inputfile . ' -ss ' . $starttime . ' -to ' . $timestamp . ' -acodec copy -vcodec copy ' . $i . $inputfile;
	print "\nProcessing\n";
	print "this will take some time...\n";
	open my $fh, "$cmdscene |" or die "Can't execute: $!";
	## Set the next scene to start at the end of this one.
	$starttime = $timestamp;
  }
  print "Scene Start: $starttime\n";
  print "Scene End: $timestamp\n";
}