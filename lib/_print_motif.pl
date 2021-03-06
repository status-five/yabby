# _print_motif.pl

use yabby_sys;
use yabby_seq;

use Getopt::Std;

# options
getopt('f');

if ( defined($opt_f) ) {
  $opt_f_flag = 1;
  $file_name = $opt_f;
} else {
  $opt_f_flag = 0;
}

# initialization
@argl = sys_init( @ARGV );
check_call( @argl, [1] );
$obj_name = $argl[0];
requirements( $obj_name, $MOTIF );
$xmldoc = load_ip_xml( $obj_name, $MOTIF );
$seq_hash = xml2seq( $xmldoc );

# body
if ( $opt_f_flag ) {
  $fp = open_for_writing( $file_name );
} else {
  $fp = *STDOUT;
}

$keys = get_seq_keys( $seq_hash );

for $key ( @$keys ) {
  $seq_item = $seq_hash->{$key};
  $sequence = $seq_item->{$DBA_SEQUENCE};
  print_seq_fasta( $fp, $seq_item, $PRINT_WIDTH );
}

if ( $opt_f_flag ) {
  close_file( $fp );
  print " '$obj_name.$MOTIF' written to the file '$file_name'\n";
}

