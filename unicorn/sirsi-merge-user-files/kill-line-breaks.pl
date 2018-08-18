open (INPUT, '<vax-users.flat');
open (OUTPUT, '>output.flat');

while ($record = <INPUT>) {
   if ($record =~ m/^[\*\.]/){
   print  OUTPUT"$record";
   }
}
close(OUTPUT);
close(INPUT);