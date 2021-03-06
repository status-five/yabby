# blast_info.pl

use yabby_sys;
use yabby_blast;

$USAGE = "
 Prints the information about the BLAST search previously
 generated by the 'blast' command. 

 Usage:
 	blast_info OBJ_NAME
";

# options
# initialization
@argl = sys_init( @ARGV );
check_call( @argl, [ 1 ] );
$obj_name = $argl[0];

# requirements
requirements( $obj_name, $BLAST );

$xmldoc = load_ip_xml( $obj_name, $BLAST );

# body
print_blast_info( $xmldoc );

