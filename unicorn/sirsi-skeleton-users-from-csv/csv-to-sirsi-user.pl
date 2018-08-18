use strict;
use warnings;
#use diagnostics;
use Text::CSV;

### Get Everything started ##
# start timer
my($start) = time();
my $file = 'ALLmemberList1-6-10_2.txt';
open(MYUNICORNFILE, '>unicorn-users.flat') || die("Could not open file!");


    my $csv = Text::CSV->new({'sep_char'    => "\t"});

    open (CSV, "<", $file) or die $!;

    while (<CSV>) {
        next if ($. == 1);
        if ($csv->parse($_)) {
            my @columns = $csv->fields();
            print MYUNICORNFILE "\*\*\* DOCUMENT BOUNDARY \*\*\*\n\.USER_ID\.   |a$columns[2] \n";
		my $name="$columns[1], $columns[0]";
		$name = uc($name);
		print MYUNICORNFILE "\.USER_NAME\.   |a $name\n";

		print MYUNICORNFILE "\.USER_LIBRARY.   |aNASH\n";
		print MYUNICORNFILE "\.USER_PROFILE.   |aALUMNI\n";
		print MYUNICORNFILE "\.USER_STATUS.   |aBLOCKED\n";

		print MYUNICORNFILE "\.USER_PRIV_GRANTED\.   |a20090112\n";

		if ($columns[3] eq "None"){ print MYUNICORNFILE "\.USER_PRIV_EXPIRES\.   |aNEVER\n";
		}elsif  ($columns[3] =~ m/(\d+)\/(\d+)\/(\d+)/){ print MYUNICORNFILE "\.USER_PRIV_EXPIRES\.   \|a"."$3"."0$1$2\n";}

		print MYUNICORNFILE "\.USER_XINFO_BEGIN\.\n";
		print MYUNICORNFILE "\.NOTE\. |a$columns[4] alumni membership. Alumni may access computers, but we need contact information before checkouts may be made.\n";
		print MYUNICORNFILE "\.USER_XINFO_END\.\n";
        } else {
            my $err = $csv->error_input;
            print MYUNICORNFILE "Failed to parse line: $err";
        }
    }
    close CSV;


### Cleaning up ##

# end timer
my($end) = time();

# report
print "Time taken was ", ($end - $start), " seconds\n";
close(MYUNICORNFILE);
exit;