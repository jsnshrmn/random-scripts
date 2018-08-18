#!/usr/bin/perl

use strict;
use warnings;
use MARC::Batch;
print '
Unicorn to Koha holdings converter

This program will convert MARC holdings from SirsiDynix Unicorn GL 3.1
to something that Koha 3.0 can use.  It may work on other versions of these
two programs (including SirsiDynix Symphony), but it has not been tested.  
To get MARC holdings from Unicorn, use the MARCExport utility with the
"Include 999 holdings tag" option ticked.
The easiest way to use this program is to place your Unicorn MARC
file into the same directory as this program.  The converted filename will
be the same as the input name, but with "_out.mrc" appended.
';


print "\nEnter name of MARC input file:\n";
my $input_marc_file = <STDIN>;
chomp $input_marc_file;
print "\nProcessing File:\nThis may take a few minutes...\n";

##my $output_file = $input_marc_file . '_out.mrc';
##open(MARCOUTPUT, "> $output_file") or die $!;
my $batch = MARC::Batch->new('USMARC',$input_marc_file);
open(MARCOUTPUT, "> $input_marc_file out.mrc") or die $!;
open(MARCDROPPED, "> $input_marc_file dropped.mrc") or die $!;

##  Our records are crap.  GIGO ;-)
$batch->strict_off();

##  We'll print warnings in a more useful way than the default
$batch->warnings_off();

## Define variables to hold the number of records and itemswe have iterated through
my $recordcount;
my $itemcount;
## In case we decide that the record isn't worth importing
my $marc_drop;

while (my $record = $batch->next()) {
	## Increment the record counter
	$recordcount++;

	## We import the record unless we know better
	$marc_drop = 0;



	## Get the record's unicorn holdings.  Unicorn's 999 and Koha's 952 are repeatable, so we are using a list context
	my @unicorn_holdings = $record->field('999');
	foreach my $unicorn_holding (@unicorn_holdings) {


		## Load the holdings information from the proper subfields
		## If you store information in different subfields,
		## this is the place to change it.
		my $full_call_number = $unicorn_holding->subfield('a');
		my $copy_number = $unicorn_holding->subfield('c');
		my $date_last_seen = &convert_date($unicorn_holding->subfield('d'));
		my $date_last_borrowed = &convert_date($unicorn_holding->subfield('e'));
		my $barcode = $unicorn_holding->subfield('i');

		# In Koha, the shelving location code must be defined in Authorized Value category 'LOC' in default installation
		# By default this is set up to remap some locations to those available in a default Koha install.
		# Check out the convert_location subroutine later on to see if you need to make adjustments for your library
		# Otherwise, you can comment out the reference to the subroutine that converts locations
		#my $shelving_location = $unicorn_holding->subfield('l');			# Uncomment this line if you want to leave your locations as they are
		my $shelving_location = &convert_location($unicorn_holding->subfield('k'),$unicorn_holding->subfield('l'));	# Comment this line if you want to leave your locations as they are

		# Check out the convert_status subroutine later on to see if you need to make adjustments for your library
		my $status_lost = &convert_status($unicorn_holding->subfield('l'));
		my $permanent_location = $unicorn_holding->subfield('m');

		# Current location is usually the same as permanent location, but maybe not for your library
		# In Koha, this code must be defined in System Administration -> Libraries, Branches and Groups
		my $current_location = $unicorn_holding->subfield('m');
		my $total_checkouts = $unicorn_holding->subfield('n');

		# In Koha, the item type code must be defined in System Administration -> Item types and Circulation Codes
		# By default this is set up to remap some item types to those available in a default Koha install.
		# Check out the convert_item_type subroutine later on to see if you need to make adjustments for your library
		# Otherwise, you can comment out the reference to the subroutine that converts item types
		#my $item_type = $unicorn_holding->subfield('t');						# Uncomment this line if you want to leave your item types as they are
		#my $item_type = &convert_item_type($unicorn_holding->subfield('t'));				# Uncomment this line if you want to your koha item types to be base soley on Unicorn item types
		my $item_type = &convert_item_type($unicorn_holding->subfield('t'),$unicorn_holding->subfield('x'));	# Uncomment this line if you want your Koha item types to be based on Unicorn item types and Unicorn item category 1

		my $date_acquired = &convert_date($unicorn_holding->subfield('u'));
		my $source_of_classification_or_shelving_scheme = &convert_classification_source($unicorn_holding->subfield('w'));

		## Collection codes are completely optional in Koha, but they are a coded value,
		## meaning they must have a matching Authorized Value category ('CCODE' in default installation))
		## This maps them from Unicorn's 'Item Category 1', but that may not make sense for you.
		my $collection_code;
		$collection_code = $unicorn_holding->subfield('x');	# Comment this line if you don't want to use your Unicorn item categories as collection codes in Koha.

		## I just set everything to be lend-able and undamaged
		my $not_for_loan = '0';
		my $status_damaged = '0';


		my $serial_enumeration_chronology;


		## Stuff that Koha wants that I haven't mapped yet.  Email suggestions to jsherman@usao.edu
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

	
		## Create a new holdings object and insert it before the unicorn holdings field, then
		my $koha_holdings = MARC::Field->new('952', '', '', 0=> $status_withdrawn, 1=> $status_lost, 2=> $source_of_classification_or_shelving_scheme, 3=> $materials_specified, 4=> $status_damaged, 5=> $use_restrictions, 6=> $normalized_classification_for_sort, 7=> $not_for_loan, 8=> $collection_code, a=> $permanent_location, b=> $current_location, c=> $shelving_location, d=> $date_acquired, e=> $source_of_acquisition, g=> $cost_normal_purchase_price, h=> $serial_enumeration_chronology, j=> $shelving_control_number, l=> $total_checkouts, m=> $total_renewals, n=> $total_holds, o=> $full_call_number, p=> $barcode, q=> $checked_out, r=> $date_last_seen, s=> $date_last_borrowed, t=> $copy_number, u=> $uniform_resource_identifier, v=> $cost_replacement_price, w=> $date_price_effective_from, y=> $item_type );
		#$record->insert_fields_before($unicorn_holding,$koha_holdings);
		$record->insert_grouped_field($koha_holdings);
		## Increment the item counter
		$itemcount++;

		## delete the unicorn holdings
		$record->delete_field( $unicorn_holding );

		my @warnings = $batch->warnings();
		if (@warnings) {
			my $warning_title = $record->subfield(245,'a');
			print STDOUT "Record $recordcount \"$warning_title\": $warnings[0]\n";
	}	}

	## Add record to the output files
	if ($marc_drop == 1) {
		print MARCDROPPED $record->as_usmarc();
	} else {
		print MARCOUTPUT $record->as_usmarc();
}	}

close(MARCDROPPED);
close(MARCOUTPUT);

## Tell us how many records and items processed
print "\n$recordcount records processed\n$itemcount items processed\n";

## Subroutines that clean up the subfields that are formatted differently between the two systems

## convert dates from M/D/YYYY to YYYY-MM-DD
sub convert_date {
	my $date = $_[0];
	if (defined $date){
		if ($date =~ /([^\/]+)\/([^\/]+)\/([^\/]+)/) {
			my $month = $1;
			my $day = $2;
			$month = sprintf("%2d", $month);
			$month=~ tr/ /0/;
			$day = sprintf("%2d", $day);
			$day=~ tr/ /0/;
 			return "$3-$month-$day";
}	}	}

## Convert status from location field string in unicorn to an integer in koha
## You might need to customize status to your library.
## The values we need to get for a default koha install are:
## 0 = Available, 1 = Lost, 2= Long Overdue (Lost), 3 = Lost and Paid For, 4 = Missing in Inventory, 5 = Missing in Hold Queue
sub convert_status {
	my $location = $_[0];
	if (($location eq 'LOST') || ($location eq 'LOST-CLAIM') || ($location eq 'MATHER LAB')) {
	return '1'; } elsif ($location eq 'LOST-ASSUM') { ## ask kelly or rhonda about LOST-ASSUM
	return '2'; } elsif ($location eq 'LOST-PAID') {  
	return '3'; } elsif ($location eq 'MISSING') {
	return '4'; } else {
	return '0'; }
}

## Convert some shelving location field strings in unicorn to Koha defaults
## Since I have no way of knowing your shelving locations, you either need to customize this for your library or
## define shelving location codes in Authorized Value category 'LOC' in your Koha installation
## The values we need to get for a default koha install are:
## AV  = Audio Visual, CHILD = Children's Area, DISPLAY = On Display, FIC = Fiction, 
## GEN = General Stacks, NEW = New Materials Shelf, REF = Reference, STAFF = Staff Office


## ANNA LEWIS|ARCHIVES|BACKLOG|BINDERY|CATALOGING|CHECKEDOUT|CIRC DESK|CURRENT|DIRECTOR|DISCARD|DRAMA|EBOOK|EDUROOM-C|EDUROOM-J|EDUROOM-L|ELECTRONIC|FOURTH FL.|HOLDS|ILL|INPROCESS|INTERNET|INTRANSIT|LOST|LOST-ASSUM|LOST-CLAIM|LOST-PAID|LOWITT|MATHER LAB|MICROFORM|MISSING|ON-EXHIBIT|ON-ORDER|OVERSIZE|PERIODICAL|REF-AV|REFERENCE|REPAIR|RESERVES|RESHELVING|REVIEW|ROOM 201|SCI DEPT|SECOND FL|SPARKS|SRVCLRNG|STACKS|STORAGE|SYSTEMSLIB|TECSERVICE|THOMAS LAB|UNKNOWN

#other nash locations
#EBOOK,ELECTRONIC,|INTERNET
#|STORAGE|BACKLOG|BINDERY|CIRC DESK|
#|OVERSIZE|PERIODICAL|MICROFORM|ANNA LEWIS|ARCHIVES|CURRENT|LOWITT
#|DISCARD|DRAMA|
#|EDUROOM-C|EDUROOM-J|EDUROOM-L
#|HOLDS|ILL|INTRANSIT
#|ON-ORDER|
#|REPAIR|RESERVES|
#RESHELVING|REVIEW|
#|SCI DEPT|SPARKS|SRVCLRNG|THOMAS LAB|MATHER LAB
#|UNKNOWN|CHECKEDOUT





sub convert_location {
	my $current_location = $_[0];
	my $home_location = $_[1];
	
	## FYI, anything in MATHER LAB is lost.  handled in convert_status

	## The items with the following current locations aren't going in
	## ANNA LEWIS, BACKLOG, CIRC 
	## DESK, CURRENT, DISCARD, EBOOK, ELECTRONIC, FOURTH FL., HOLDS, INTERNET, LOWITT, 
	## PERIODICAL, REVIEW, SCI DEPT, SECOND FL, SRVCLRNG, TECSERVICE, or UNKNOWN

	if (($current_location eq 'ANNA LEWIS') || ($current_location eq 'BACKLOG') || ($current_location eq 'CIRC DESK') || ($current_location eq 'CURRENT') || ($current_location eq 'DISCARD') || ($current_location eq 'EBOOK') || ($current_location eq 'ELECTRONIC') || ($current_location eq 'HOLDS') || ($current_location eq 'INTERNET') || ($current_location eq 'LOWITT') || ($current_location eq 'REVIEW') || ($current_location eq 'SECOND FL') || ($current_location eq 'TECSERVICE') || ($current_location eq 'UNKNOWN') || ($current_location eq 'FOURTH FL.') || ($current_location eq 'PERIODICAL') || ($current_location eq 'SCI DEPT') || ($current_location eq 'SRVCLRNG')) {
		$marc_drop = 1;
	} elsif ($current_location eq 'THOMAS LAB') {
		return 'AUSTIN-???';
	} elsif ($current_location eq 'BINDERY') {
		return 'BINDERY';
	} elsif ($current_location eq 'ON-EXHIBIT') {  
		return 'DISPLAY';
	} elsif ($current_location eq 'DRAMA') {
		return 'DAVIS-106C';
	} elsif ($current_location eq 'EDUROOM-C') {  
		return 'NASH-305C';
	} elsif ($current_location eq 'EDUROOM-J') {  
		return 'NASH-305J';
	} elsif ($current_location eq 'EDUROOM-L') {  
		return 'NASH-305L';
	} elsif ($current_location eq 'STACKS') {  
		return 'GEN';
	} elsif (($current_location eq 'ROOM 201') || ($current_location eq 'MICROFORM')) {
		return 'NASH-201';
	} elsif ($current_location eq 'DIRECTOR') {  
		return 'NASH-202';
	} elsif (($current_location eq 'REF-AV') || ($current_location eq 'REFERENCE')) {
		return 'NASH-203';
	} elsif ($current_location eq 'ARCHIVES') {
		return 'NASH-301';
	} elsif ($current_location eq 'SYSTEMSLIB') {
		return 'NASH-303';
	} elsif ($current_location eq 'ON-ORDER') {
		return 'ON-ORDER';
	} elsif ($current_location eq 'OVERSIZE') {
		return 'OVERSIZE';
	} elsif ($current_location eq 'RESERVES') {
		return 'NASH-203-RES';
	} elsif ($current_location eq 'SPARKS') {
		return 'SPARKS';
	} elsif ($current_location eq 'STORAGE') {
		return 'STORAGE';

	## The items with the following current locations are going in by home location
	## CATALOGING, CHECKEDOUT, ILL, INPROCESS, INTRANSIT, REPAIR, RESHELVING
	} elsif (($current_location eq 'CATALOGING') || ($current_location eq 'CHECKEDOUT') || ($current_location eq 'ILL') || ($current_location eq 'INPROCESS') || ($current_location eq 'INTRANSIT') || ($current_location eq 'REPAIR') || ($current_location eq 'RESHELVING')) {
		if ($home_location eq 'THOMAS LAB') {
			return 'AUSTIN-???';
		} elsif ($home_location eq 'BINDERY') {
			return 'BINDERY';
		} elsif ($home_location eq 'ON-EXHIBIT') {  
			return 'DISPLAY';
		} elsif ($home_location eq 'DRAMA') {
			return 'DAVIS-106C';
		} elsif ($home_location eq 'EDUROOM-C') {  
			return 'NASH-305C';
		} elsif ($home_location eq 'EDUROOM-J') {  
			return 'NASH-305J';
		} elsif ($home_location eq 'EDUROOM-L') {  
			return 'NASH-305L';
		} elsif ($home_location eq 'STACKS') {  
			return 'GEN';
		} elsif (($home_location eq 'ROOM 201') || ($home_location eq 'MICROFORM')) {
			return 'NASH-201';
		} elsif ($home_location eq 'DIRECTOR') {  
			return 'NASH-202';
		} elsif (($current_location eq 'REF-AV') || ($current_location eq 'REFERENCE')) {
			return 'NASH-203';
		} elsif ($home_location eq 'ARCHIVES') {
			return 'NASH-301';
		} elsif ($home_location eq 'SYSTEMSLIB') {
			return 'NASH-303';
		} elsif ($home_location eq 'ON-ORDER') {
			return 'ON-ORDER';
		} elsif ($home_location eq 'OVERSIZE') {
			return 'OVERSIZE';
		} elsif ($home_location eq 'RESERVES') {
			return 'NASH-203-RES';
		} elsif ($home_location eq 'SPARKS') {
			return 'SPARKS';
		} elsif ($home_location eq 'STORAGE') {
			return 'STORAGE';
		}	}	}


## Convert some unicorn item type strings in unicorn to Koha defaults
## Since I have no way of knowing your item types, you either need to customize this for your library or
## define item type codes in Item Types Administration in your Koha installation
## For our library, it made sense to use a combination of item types and item categories (mapped to $collection_code)
## The values we need to get for a default koha install are:
## BK  = Books, CF = Computer Files, CR = Continuing Resources, MP = Maps, 
## MU = Music, MX = Mixed Materials, REF = Reference, VM = Visual Materials

## other Nash item categories
##|INDEX|KIT|MICROFICHE|MICROFILM|UNKNOWN

sub convert_item_type {
	my $type = $_[0];
	my $unicorn_item_category_1 = $_[1];
	if (($type eq 'BOOK') || ($type eq 'ILL-BOOK') || ($type eq 'INDEX') || ($type eq 'JUVAWARDBK') || ($type eq 'NEW-BOOK')) {
	return 'BK'; } elsif (($type eq 'COMPU-FILE') || ($type eq 'ELECTRONIC') || ($type eq 'INTERNET')) {
	return 'CF'; } elsif (($type eq 'MAGAZINE') || ($type eq 'MICROFORM') || ($type eq 'NEWSPAPER')) {  
	return 'CR'; } elsif (($type eq 'PERSONAL') || ($type eq 'PERSONL-AV') || ($type eq 'PERSONL-BK')) { ## Must be defined in koha 
	return 'PERSONAL'; } elsif (($type eq 'KIT') || ($type eq 'GUIDE') || ((defined $unicorn_item_category_1) && ($unicorn_item_category_1 eq 'KIT'))) {  
	return 'MX'; } elsif (($type eq 'REF-BOOK') || ($type eq 'RESERVE') || ($type eq 'XEROXCOPY')) {  
	return 'REF'; } elsif ((defined $unicorn_item_category_1) && (($type eq 'AV') || ($type eq 'AV-EQUIP'))) {  
	if (($unicorn_item_category_1 eq 'CASSETTE') || ($unicorn_item_category_1 eq 'CD') || ($unicorn_item_category_1 eq 'PHONOGRAPH') || ($unicorn_item_category_1 eq 'SCORE')) {
		return 'MU'; } 
		elsif (($unicorn_item_category_1 eq 'DVD') || ($unicorn_item_category_1 eq 'FILMSTRIP') || ($unicorn_item_category_1 eq 'SLIDE') || ($unicorn_item_category_1 eq 'VIDEO')) {
		return 'VM'; } 
	} else {
	return $type; }
}

sub convert_classification_source {
	my $source = $_[0];
	if ($source eq 'LC') {
	return 'lcc'; } elsif ($source eq 'DEWEY') {
	return 'ddc'; } elsif ($source eq 'AUTO') {
	return ''; } else { 
	## we didn't have anything using 'anscr', 'sudocs', 'udc', or 'z', so I don't know how unicorn encodes them.  Email suggestions to jsherman@usao.edu
	return $source;
}	}



sub convert_serial_holdings {
	my $unsplit_362 = $_[0];
	#my @split =  split(/;/,$unsplit_362);
	my @split;
	##koha seems to have an 80 character limit on the h subfield of 952
	push @split, substr($unsplit_362, 0, 79, "") while length($unsplit_362);
	return (@split);
}