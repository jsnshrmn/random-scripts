$/ ="\n\n";

open (REPORT, '<view_dfgt20601.txt');
open (LIST, '>list.txt');
open (LSTACKS, '>l-in-the-stacks.txt');

while ($record = <REPORT>) {
   if (($record =~ m/id:(\d+\-)/) && ($record !~ m/(EBOOK)/) && ($record !~ m/(E\-BOOK)/) && ($record !~ m/(electronic resource)/) && ($record !~ m/(Serial)/)) {
#   print  LIST"$1,";
    print LIST"$record";
   } elsif ($record =~ m/^    L/) {
    print LSTACKS"$record";
   }
}
close(LSTACKS);
close(LIST);
close(REPORT);