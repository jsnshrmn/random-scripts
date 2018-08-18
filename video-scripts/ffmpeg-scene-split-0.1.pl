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

2.	Calls ffmpeg to copy out each scene to a new file by demux (rather than transcode).

Based on the following online discussions:
Extract Thumbnails of Every Camera Change on a Video File
http://stackoverflow.com/questions/13142541/extract-thumbnails-of-every-camera-change-on-a-video-file

FFmpeg - numerical output?
http://ffmpeg.org/pipermail/ffmpeg-user/2012-November/011101.html

Using ffmpeg to cut up video
http://superuser.com/questions/138331/using-ffmpeg-to-cut-up-video

';

print "\nEnter name of video to be butchered:\n";
my $inputfile = <STDIN>;
chomp $inputfile;
my $inputfilebasename;
my $inputfileext;
## separate the filename and the extension
if ($inputfile =~ /(.+)(\.[^.]+$)/) {
  $inputfilebasename = $1;
  $inputfileext = $2;
}


my @rawtimestamps;
my $cmdprobe = 'ffprobe -show_frames -of compact=p=0 -f lavfi ' . '"movie=' . $inputfile . ',select=gt(scene\,.6)"' . '2>NUL';
print "\nAnalyzing\n";
print "this will take some time...\n";
open my $fh, "$cmdprobe |" or die "Can't execute: $!";
my @ffprobe = <$fh>;
foreach my $output (@ffprobe) {
  if ($output =~ /.+pkt_pts_time=([0-9.]{8,})\|.+scene_score=([0-9.]{8,}).*/) {
    #Just a little debugging
    #print "$1\,$2\n";
    my @tmp = ($1,$2);
	push (@rawtimestamps, [@tmp]);
  }
}
close $fh or die "Can't close pipe: $!";

## This is just to set some known values for USAO-01-.yuv422p.720x480.lossless.mp4 to test the second part of the program
#my @rawtimestamps = ([15.281949,0.700000],[53.253253,1.000000],[53.319987,0.750000],[54.320988,0.810000],[356.623290,0.680000],[413.713714,0.910000],[553.486820,0.740000],[676.776777,0.700000],[717.250584,0.600000],[726.426426,0.740000],[750.550551,0.670000],[944.377711,1.000000],[945.145145,1.000000],);

## We'll take wild guess that the first scene starts immediately...
unshift(@rawtimestamps, [0,1]);

## The edited timestamps array
my @timestamps;
foreach my $i (0 .. $#rawtimestamps) {
  my $scenestart = $rawtimestamps[$i][0];
  my $scenescore = $rawtimestamps[$i][1];
  my $sceneend = $rawtimestamps[$i+1][0];
  # We actually don't have an end time for the last scene
  if (defined $sceneend) {
	## Only keep scenes more than 5 seconds long.
	## Shorter scenes are simply included at the end of the previous scene
	## This is a pretty naive way to handle this.  You could do it better by
	## comparing the scene scores, which I'm pulling out for just that purpose
	## down the road  
    if (($sceneend - $scenestart) > 5.000000) {
	  my @tmp = ($scenestart,$scenescore,$sceneend);
	  push (@timestamps, [@tmp]);
	}
  } else {
	my @tmp = ($scenestart,$scenescore);
	push (@timestamps, [@tmp]);
  }
}

##Just a little debugging
#for my $row ( @timestamps ) {
#    print "@$row\n";
#}


## Copy out each scene using ffmpeg
print "\nDemuxing\n";
print "this will take some time...\n";

## For tracking the last scene
my $lastscenestart = $timestamps[-1][0];

## Just a little counter for filenames
my $i = 0;

foreach my $scene (0 .. $#timestamps) {
  my $scenestart = $timestamps[$scene][0];
  my $scenescore = $timestamps[$scene][1];
  my $sceneend = $timestamps[$scene][2];

  $i++;
  print "Processing Scene $i\n";
  
  ## The last entry in the list has a different command, to process the video through EOF
  if ($timestamps[$scene][0] == $lastscenestart) {
	print "\tStart time: $scenestart\n";
	print "\tEnd time: EOF\n";	  
	my $cmdscene = 'ffmpeg -loglevel fatal -i ' . $inputfile . ' -ss ' . $scenestart . ' -acodec copy -vcodec copy ' . $inputfilebasename . '-scene-' . $i . $inputfileext;
	open my $fh, "$cmdscene |" or die "Can't execute: $!";
	close $fh or die "Can't close pipe: $!";
  } else {
  	print "\tStart time: $scenestart\n"; 
	print "\tEnd time: $sceneend\n";
	my $cmdscene = 'ffmpeg -loglevel fatal -i ' . $inputfile . ' -ss ' . $scenestart . ' -to ' . $sceneend . ' -acodec copy -vcodec copy ' . $inputfilebasename . '-scene-' . $i . $inputfileext;
	open my $fh, "$cmdscene |" or die "Can't execute: $!";
	close $fh or die "Can't close pipe: $!";
  }
    my $sceneconfidence = ($scenescore*100);
	print "\tScene Confidence: $sceneconfidence%\n\n";
}