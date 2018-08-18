#!/usr/bin/perl

use strict;
use warnings;
use MARC::Batch;

## Based on Example U9 found at
## http://search.cpan.org/~mikery/MARC-Record-2.0.0/lib/MARC/Doc/Tutorial.pod#Updating_subject_subfield_x_to_subfield_v


print "\nEnter name of MARC input file:\n";
my $file = <STDIN>;
chomp $file;
print "\nProcessing File:\nThis may take a few minutes...\n";

open(MARCOUTPUT, "> $file out.mrc") or die $!;


my $batch = MARC::Batch->new('USMARC', $file);
while ( my $record = $batch->next() ) {
  if ( $record->field( '927' ) ) {

    # delete any 852 fields
    my $any852 = $record->field('852');
    $record->delete_field($any852);



    my @Newholdings;

    # count needs to match an array index, 
    # so the first item needs to be zero
    my $i=-1;
    my $barcode;

    # go through all 927 fields in the record.
    foreach my $marcholding ( $record->field( '927' ) ) {

      # if the subfield code is 'a'...
      if ($marcholding->subfield('a')) {

	## Increment the counter
	$i++;

	#Set the barcode
	my $barcode = &trim($record->field('001')->data) . '-' . $i . '-' . int(rand(1000));
	push @{ $Newholdings[$i] }, $barcode;

	#print "Holding Record $i Start:\n";
      }

      if ($marcholding->subfield('c')) {
	#check for location
	if ( ( $marcholding->subfield('c') eq uc $marcholding->subfield('c')) && ($marcholding->subfield('c') !~ m/^\d/) ) {

	    #print "SHELVING LOCATION:",$marcholding->subfield('c'),"\n";
	    my $shelving_location = &convert_location($marcholding->subfield('c'));
	    push @{ $Newholdings[$i] }, $shelving_location;

	#check for enumeration
	} else {

	    #print "ENUMERATION:",$marcholding->subfield('c'),"\n";
	    my $enumeration = $marcholding->subfield('c');
	    push @{ $Newholdings[$i] }, $enumeration;
      }	}


      # delete the unicorn marc holding (927)
      $record->delete_field( $marcholding );
    } # End of foreach 927

    # create the new holdings item record
    for my $a952 ( @Newholdings ) {
      #print "\t [ @$a952 ],\n";


      my $barcode = @$a952[0];
      my $shelving_location = @$a952[1];
      my $serial_enumeration_chronology = @$a952[2];

      # Current location is usually the same as permanent location, but maybe not for your library
      # In Koha, this code must be defined in System Administration -> Libraries, Branches and Groups
      my $permanent_location = 'NASH';
      my $current_location = 'NASH';

      # In Koha, the item type code must be defined in System Administration -> Item types and Circulation Codes
      # By default this is set up to remap some item types to those available in a default Koha install.
      my $item_type = 'CR';

      ## I just set everything to be lend-able and undamaged
      my $not_for_loan = '0';
      my $status_damaged = '0';

      ## Set the call number info
      my $full_call_number = 'SERIAL';
      my $source_of_classification_or_shelving_scheme = 'lcc';

      ## Not really using these, but just in case
      my $copy_number;
      my $date_last_seen;
      my $date_last_borrowed;
      my $status_lost;
      my $total_checkouts;
      my $status_withdrawn;
      my $materials_specified;
      my $use_restrictions;
      my $normalized_classification_for_sort;
      my $source_of_acquisition;
      my $cost_normal_purchase_price;
      my $shelving_control_number;
      my $total_renewals;
      my $total_holds;
      my $checked_out;
      my $uniform_resource_identifier;
      my $cost_replacement_price;
      my $date_price_effective_from;
      my $collection_code;
      my $date_acquired;

      #Create a new holdings object and insert it
      my $koha_holdings = MARC::Field->new('952', '', '', 0=> $status_withdrawn, 1=> $status_lost, 2=> $source_of_classification_or_shelving_scheme, 3=> $materials_specified, 4=> $status_damaged, 5=> $use_restrictions, 6=> $normalized_classification_for_sort, 7=> $not_for_loan, 8=> $collection_code, a=> $permanent_location, b=> $current_location, c=> $shelving_location, d=> $date_acquired, e=> $source_of_acquisition, g=> $cost_normal_purchase_price, h=> $serial_enumeration_chronology, j=> $shelving_control_number, l=> $total_checkouts, m=> $total_renewals, n=> $total_holds, o=> $full_call_number, p=> $barcode, q=> $checked_out, r=> $date_last_seen, s=> $date_last_borrowed, t=> $copy_number, u=> $uniform_resource_identifier, v=> $cost_replacement_price, w=> $date_price_effective_from, y=> $item_type );
      $record->insert_grouped_field($koha_holdings);
    }

    # output the record as MARC.
    print MARCOUTPUT $record->as_usmarc();
} }

close(MARCOUTPUT);

#ROOM 201--,MICROFORM--,CURRENT--,#FOURTH FL.--,LOWITT--,STORAGE--
sub convert_location {
  my $shelving_location = $_[0];
  if (($shelving_location eq 'ROOM 201--    ') || ($shelving_location eq 'MICROFORM--    ') || ($shelving_location eq 'CURRENT--    ')) {
    return 'NASH-201';
  } elsif (($shelving_location eq 'FOURTH FL.--    ') || ($shelving_location eq 'LOWITT--    ')) {  
    return 'GEN';
  } elsif ($shelving_location eq 'STORAGE--    ') {
    return 'STORAGE';
  } elsif ($shelving_location eq 'ARCHIVES--    ') {
    return 'NASH-301';
  } else {
    print "$shelving_location \n";
  }
}

sub trim($)
{
  my $string = shift;
  $string =~ s/^\s+//;
	$string =~ s/\s+$//;
  return $string;
}
