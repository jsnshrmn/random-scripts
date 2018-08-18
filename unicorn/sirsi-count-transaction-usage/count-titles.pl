use strict;
use warnings;

open FILE, '<', 'eduroom-c-usage.txt';

my $count;
while ( <FILE> ) {
    print if /^   NASH:([1-999])/;
    $count++ if /^   NASH:([1-999])/;
}
print "Matched $count times\n";