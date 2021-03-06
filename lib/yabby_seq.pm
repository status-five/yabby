# yabby_seq.pm

use XML::DOM;

$SEQUENCE = "seq";
$MOTIF = "motif";
$SEQID = "seqid";

# amino acid single letter alphabet
$AA_ALPHABET = "AVLIPFWMGSTCYNQDEKRH";

# hash for single-to-three letter amino acid conversion
%AA_HASH = (
"G" => [ "GLY" ],
"A" => [ "ALA" ],
"V" => [ "VAL" ],
"L" => [ "LEU" ],
"I" => [ "ILE" ],
"F" => [ "PHE" ],
"Y" => [ "TYR" ],
"W" => [ "TRP" ],
"M" => [ "MET" ],
"C" => [ "CYS" ],
"S" => [ "SER" ],
"T" => [ "THR" ],
"R" => [ "ARG" ],
"K" => [ "LYS" ],
"H" => [ "HIS", "HSD", "HSP" ],
"P" => [ "PRO" ],
"E" => [ "GLU" ],
"D" => [ "ASP" ],
"Q" => [ "GLN" ],
"N" => [ "ASN" ] );

# keys to sequence hash
$DBA_COMMENT = "dba_comment";
$DBA_SEQID = "dba_seqid";
$DBA_SEQUENCE = "dba_sequence";
# these used only in fetch_sprot_seq()
$DBA_OS = "dba_os";
$DBA_CNTR = "dba_cntr";

# SPROT constants
$SPROT_ID = "ID   ";
$SPROT_DE = "DE   ";
$SPROT_OS = "OS   ";
$SPROT_SEQ = "SQ   ";

# the default number of characters when printing
# the sequence
$PRINT_WIDTH = 70;
$PRINT_WIDTH3 = 12;

#----------------
# - SUBROUTINES -
# ---------------

# $seq_hash = read_fasta( $dba_file )
#
# Reads the sequence database in FASTA format, populates
# and returns the database hash.
#
# For N sequences in the database, keys of this hash are 1,
# 2, ... N. The value for each element is an anonymous.
# Let $key = 1,2, ... N and $seq_item = $seq_hash->{$key}.
# Then:
#
#   $seq_item->{$DBA_COMMENT} is the FASTA comment (minus ">")
#   $seq_item->{$DBA_SEQID} is the first string from the FASTA
#     comment (minus ">")
#   $seq_item->{$DBA_SEQUENCE} contains the sequence (newline
#     characters removed)
#
sub read_fasta {
  my ( $dba_file ) = @_;
  my ( $fp, $record, $seq_hash, @fields, $comment, $sequence );
  my ( $seqstr, $db_entry_line, $cntr, @fields2 );

  $seq_hash = {};

  # examine the first line
  $fp = open_for_reading( $dba_file );
  do { $record = <$fp> } until $. == 1 || eof;
  chomp( $record );

  @fields = split //, $record;
  if ( $fields[0] ne ">" ) {
    error( "FASTA file does not start with '>'" );
  }

  # OK, read the fasta file
  shift @fields;
  $comment = join "", @fields;
  $sequence = "";
  $seqstr = "";
  $db_entry_line = 1;
  $cntr = 1;
  @fields2 = ();

  while ( <$fp> ) {

    $cntr++;
    $record = $_;
    chomp( $record );
    @fields = split //, $record;
    if ( defined($fields[0]) && ($fields[0] eq ">") ) {
      if ( $db_entry_line == 1 ) {
        error( "improper FASTA file: comment without sequence (line $cntr)");
      }
      $db_entry_line = 0;
      if ( $cntr > 1 ) {
        add_fasta_entry( $seq_hash, $comment, $sequence );
      }
    }

    $db_entry_line++;

    if ( $db_entry_line == 1 ) {
      shift @fields;
      $comment = join "", @fields;
      $sequence = "";
    } else {
      $seqstr = join "", @fields;
      @fields2 = split / /, $seqstr;
      $seqstr = join "", @fields2;
      $sequence = $sequence . $seqstr;
    }
  }

  close_file( $fp );

  # add the last sequence to $seq_hash
  add_fasta_entry( $seq_hash, $comment, $sequence );
  return $seq_hash;
}

sub add_fasta_entry {

  my ( $seq_hash, $comment, $sequence ) = @_;
  my ( $dba_no, $seq_item, @fields );

  $dba_no = keys %$seq_hash;
  $dba_no++;
  $seq_hash->{$dba_no} = {};
  $seq_item = $seq_hash->{$dba_no};
  @fields = split " ", $comment;
  $seq_item->{$DBA_SEQID} = $fields[0];
  $seq_item->{$DBA_COMMENT} = $comment;
  $seq_item->{$DBA_SEQUENCE} = $sequence;
}

#
# read_fasta__rand( $dba_file, $rand_dba_file )
#
# Randomizes sequences in a database file $dba_file, writes out
# FASTA file with randomized sequences $rand_dba_file.
#
sub read_fasta__rand {

  my ( $dba_file, $rand_dba_file ) = @_;
  my ( $fp, $record, $seq_hash, @fields, $comment, $sequence );
  my ( $seqstr, $db_entry_line, $cntr, @fields2, $seq_cntr );

  # The function output_rand_seq() appends to output sequence
  # file. If the output file already exists, remove it first
  if (-e $rand_dba_file) {
    unlink($rand_dba_file); 
    print " [ existing file '$rand_dba_file' deleted ]\n";
  }
  print " Writing output to '$rand_dba_file' ...\n";

  # sequence hash does not accumulate
  $seq_hash = {};

  # check the first line of the FASTA file
  $fp = open_for_reading( $dba_file );
  do { $record = <$fp> } until $. == 1 || eof;
  chomp( $record );

  @fields = split //, $record;
  if ( $fields[0] ne ">" ) {
    error( "FASTA file does not start with '>'" );
  }

  # OK, read the fasta file
  shift @fields;
  $comment = join "", @fields;
  $sequence = "";
  $seqstr = "";
  $db_entry_line = 1;
  $cntr = 1;
  @fields2 = ();
  $seq_cntr = 0;

  # loop over all lines, output sequences on the fly
  while ( <$fp> ) {

    $cntr++;

    $record = $_;
    chomp( $record );

    @fields = split //, $record;

    if ( defined($fields[0]) && ($fields[0] eq ">") ) {
      if ( $db_entry_line == 1 ) {
        error( "improper FASTA file: comment without sequence (line $cntr)");
      }
      $db_entry_line = 0;
      if ( $cntr > 1 ) {
        $seq_cntr++;
        output_rand_seq( $rand_dba_file, $seq_hash, $comment, $sequence );
      }
    }

    $db_entry_line++;

    if ( $db_entry_line == 1 ) {
      shift @fields;
      $comment = join "", @fields;
      $sequence = "";
    } else {
      $seqstr = join "", @fields;
      @fields2 = split / /, $seqstr;
      $seqstr = join "", @fields2;
      $sequence = $sequence . $seqstr;
    }
  }

  # done with the file
  close_file( $fp );

  # add the last sequence to $seq_hash
  $seq_cntr++;
  output_rand_seq( $rand_dba_file, $seq_hash, $comment, $sequence );

  # return the number of sequences processed
  return $seq_cntr;
}

# 
# sub output_rand_seq ( $rand_dba_file, $seq_hash, $comment, $sequence )
#
# Creates $seq_item, permutes the sequence, and prints the sequence
# in FASTA format. The variable $seq_hash does not extpand, allowing
# reading of large sequence files without consuming the memory,
# effectively reading/output the sequences on the fly without holding
# them in memory.
#

sub output_rand_seq {

  my ( $rand_dba_file, $seq_hash, $comment, $sequence ) = @_;
  my ( $dba_no, $seq_item, @fields, @seq_array, @seq_array_rand, $sequence_rand );

  $dba_no = 1; # do not expand $seq_hash

  $seq_hash->{$dba_no} = {};
  $seq_item = $seq_hash->{$dba_no};
  @fields = split " ", $comment;

  $seq_item->{$DBA_SEQID} = $fields[0];
  $seq_item->{$DBA_COMMENT} = $comment;

  # randmly permute sequence letters
  @seq_array = split(//, $sequence);
  @seq_array_rand = shuffle(@seq_array); 
  $sequence_rand = join "", @seq_array_rand;
  $seq_item->{$DBA_SEQUENCE} = $sequence_rand;

  # output the sequence item with letters randomly permuted
  $fp = open_for_adding($rand_dba_file);
  #$fp = *STDOUT;
  print_seq_fasta($fp, $seq_item, $PRINT_WIDTH);
  close_file( $fp );
}

# $seq_hash = read_blocks( $blocks_file )
#
# Reads sequences from a BLOCKS file.
# Note: this has been only tested with BLOCKS output created
# by MEME. The file must begin with "BL", and list of sequences
# finishes with "//".
#
sub read_blocks {
  my ( $blocks_file ) = @_;
  my ( $fp, $record, @fields, @blocks_content, @seq_lines, $term_flag );
  my ( $line, $seq_hash, $dba_no, $seq_item, $seqid, $sequence );
  
  # examine the first line
  $fp = open_for_reading( $blocks_file );

  do { $record = <$fp> } until $. == 1 || eof;
  chomp( $record );

  @fields = split " ", $record;
  if ( $fields[0] ne "BL" ) {
    error( "BLOCKS file does not start with 'BL'" );
  }

  @blocks_content = <$fp>;
  @seq_lines = ();
  $term_flag = 0;

  for $line ( @blocks_content ) {
    if ( substr($line, 0, 2) ne "//" ) {
      push @seq_lines, $line; 
    } else {
      $term_flag++;
      last;
    }
  }

  if ( $term_flag == 0 ) {
    error( "BLOCKS terminator '//' not found" );
  }

  $seq_hash = {};
  $dba_no = -1;

  for $line ( @seq_lines ) {
    $dba_no++;
    $seq_hash->{$dba_no} = {};
    $seq_item = $seq_hash->{$dba_no};
    
    @fields = split " ", $line;
    $seqid = $fields[0];
    $sequence = $fields[3];
    $seq_item->{$DBA_SEQID} = $seqid;
    $seq_item->{$DBA_COMMENT} = "from BLOCKS file '$blocks_file'";
    $seq_item->{$DBA_SEQUENCE} = $sequence;
  }

  close_file( $fp );
  return $seq_hash;
}

# $keys = get_seq_keys( $seq_hash )
# 
# Returns a reference to the array which contains
# sorted keys of the DBA hash
#
sub get_seq_keys {
  my ( $seq_hash ) = @_;
  my ( @sorted_keys );
  @sorted_keys = sort { $a <=> $b } keys %$seq_hash;
  return \@sorted_keys;
}

sub get_seq_ids {
  my ( $seq_hash ) = @_;
  my ( $keys, $ids, $key, $seq_item );
  $keys = get_seq_keys( $seq_hash );
  $ids = ();
  for $key ( @$keys ) {
    $seq_item = $seq_hash->{$key};
    push @$ids, $seq_item->{$DBA_SEQID};
  }
  return $ids;
}

# $comment = get_comment_by_key( $dba_no, $seq_hash )
#
# Returns the comment from the database hash
# given the key 
#
sub get_comment_by_key {
  my ( $dba_no, $seq_hash ) = @_;
  my ( $seq_item, $comment ); 
  if ( ! exists $seq_hash->{$dba_no} ) {
    error( "item $dba_no does not exist" );
  }
  $seq_item = $seq_hash->{$dba_no};
  $comment = $seq_item->{$DBA_COMMENT};
  return $comment;
}

# $seq = get_seq_by_key( $dba_no, $seq_hash )
#
# Returns sequence from the database hash
# given the key 
#
sub get_seq_by_key {
  my ( $dba_no, $seq_hash ) = @_;
  my ( $seq_item );
  if ( ! exists $seq_hash->{$dba_no} ) {
    error( "item $dba_no does not exist" );
  }
  $seq_item = $seq_hash->{$dba_no};
  return $seq_item->{$DBA_SEQUENCE};
}

# $comment = get_comment_by_id( $id, $seq_hash )
#
# Returns the comment from the database hash
# given the ID
#
sub get_comment_by_id {
  my ( $id, $seq_hash ) = @_;
  my ( $cntr, $comment, $key, $seq_item );
  $cntr = 0;
  $comment = "";
  for $key ( keys %$seq_hash ) {
    $seq_item = $seq_hash->{$key};
    if ( $seq_item->{$DBA_SEQID} eq $id ) {
      $cntr++;
      $comment = $seq_item->{$DBA_COMMENT};
    }
  }
  if ( $cntr != 1 ) {
    error( "$cntr matches found for $id" );
  }
  return $comment;
}

# $seq = get_seq_by_id( $id, $seq_hash )
#
# Returns the sequence from the sequence hash
# given the ID
#
sub get_seq_by_id {
  my ( $id, $seq_hash ) = @_;
  my ( $cntr, $seq, $key, $seq_item );
  $cntr = 0;
  for $key ( keys %$seq_hash ) {
    $seq_item = $seq_hash->{$key};
    if ( $seq_item->{$DBA_SEQID} eq $id ) {
      $cntr++;
      $seq = $seq_item->{$DBA_SEQUENCE};
    } 
  }
  if ( $cntr != 1 ) {
    error( "$cntr matches found" );
  }
  return $seq;
}

sub print_seq {
  my ( $file, $sequence, $width ) = @_;
  my ( @seq_char, $ii );
  @seq_char = split //, $sequence;
  for $ii ( 0 .. $#seq_char ) {
    print $file "$seq_char[$ii]";
    if ( ( (($ii+1) % $width) == 0 ) &&
         ($ii != $#seq_char ) ) {
      print $file "\n";
    }
  }
  print $file "\n";
}

sub print_seq_3lett {
  my ( $fp, $seq_item, $print_width ) = @_;
  my ( @seq_char, $ch, $ii );
  printf $fp ">%s\n", $seq_item->{$DBA_COMMENT};
  @seq_char = split //, $seq_item->{$DBA_SEQUENCE};
  for $ii ( 0 .. $#seq_char ) {
    $ch = $seq_char[$ii];
    if ( defined($AA_HASH{$ch}) ) {
      printf $fp "%s ", $AA_HASH{$ch}->[0];
    } else {
      error( "unknown sequence letter '$ch'" );
    }
    if ( ( (($ii+1) % $print_width) == 0 ) &&
        ($ii != $#seq_char ) ) {
      print $fp "\n";
    }
  }
  print $fp "\n";
}

sub print_seq_fasta {
  # if $comment_as_is is defined, comment is printed as saved in 'seq_item'
  my ( $fp, $seq_item, $print_width, $comment_as_is ) = @_;
  my ( @seq_char, $ii );

  if ( defined($comment_as_is) ) {
    printf $fp ">%s\n", $seq_item->{$DBA_COMMENT};
  } else {
    $seq_comment = $seq_item->{$DBA_COMMENT};
    chomp( $seq_comment );
    printf $fp ">%s [ %s ]\n", $seq_item->{$DBA_SEQID}, $seq_comment;
  }

  @seq_char = split //, $seq_item->{$DBA_SEQUENCE};

  for my $ii ( 0 .. $#seq_char ) {
    printf $fp "%s", $seq_char[$ii];
    if ( ( (($ii+1) % $print_width) == 0 ) && ($ii != $#seq_char ) ) {
      print $fp "\n";
    }
  }

  print $fp "\n";
}

# Converts three letter amino acid name into one letter code.
# This subroutine returns "-" if the 3-letter code does not
# translate into 1-letter code, and prints a warning message
sub aa3to1 {
  my ( $aa ) = @_;
  my ( @aa1_list, $match_cntr, $aa_match, $aa1, $aa3 );
  @aa1_list = keys %AA_HASH;
  $match_cntr = 0;
  $aa_match = "-";
  for $aa1 ( @aa1_list ) {
    for $aa3 ( @{ $AA_HASH{$aa1} } ) {
      if ( $aa eq $aa3 ) {
         $match_cntr++;
         $aa_match = $aa1;
      }
    }
  }

  if ( $match_cntr == 0 ) {
    print " WARNING: residue '$aa' does not have one letter code\n";

  } elsif ( $match_cntr > 1 ) {
    error( "multiple matches for amino acid '$aa'", $sub_name );
  }

  return $aa_match;
}

# fetches a sequence from Swiss-Prot database by ID
sub fetch_sprot_seq {

  my ( $sprot_dba, $sprot_id ) = @_;

  my ( $seq_item, $file, $sprot_entry, $seq_start, $cntr, $line, @fields );
  my ( %sprot_hash, @fields2, $seqstr );

  $seq_item = {};

  $file = open_for_reading( $sprot_dba );

  $sprot_entry = 0;
  $seq_start = 0;
  $cntr = 0;

  while( <$file> ) {

    $line = $_;
    chomp($line);

    @fields = split " ", $line;

    if ( substr($line, 0, 2) eq "//" ) {

      $sprot_entry = 0;
      $seq_start = 0;

      if ( $sprot_hash{$DBA_SEQID} eq $sprot_id ) {

        $seq_item->{$DBA_SEQID} = $sprot_hash{$DBA_SEQID};
        $seq_item->{$DBA_OS} = $sprot_hash{$DBA_OS};
        $seq_item->{$DBA_COMMENT} = $sprot_hash{$DBA_COMMENT} . " " .
            $sprot_hash{$DBA_OS};
        $seq_item->{$DBA_SEQUENCE} = $sprot_hash{$DBA_SEQUENCE};
        $seq_item->{$DBA_CNTR} = $cntr;

        last;
      }
    }

    if ( substr($line, 0, 5) eq $SPROT_ID ) {
      $sprot_entry = 1;
    } 

    if ( $sprot_entry ) {

      # new entry, initialize the entry hash
      if ( $sprot_entry == 1 ) {

        %sprot_hash = ();
        $sprot_hash{$DBA_SEQID} = $fields[1];
        $sprot_entry++; # increment entry line counter
        $cntr++; # increments entries counter

      } else { # fill in entries for the current sequence

        # organism
        if ( substr($line, 0, 5) eq $SPROT_OS ) {

          @fields2 = split " ", $line;
          shift @fields2;
          $sprot_hash{$DBA_OS} = join " ", @fields2;
        }

        # description
        if ( substr($line, 0, 5) eq $SPROT_DE ) {

          @fields2 = split " ", $line;
          shift @fields2;
          $sprot_hash{$DBA_COMMENT} = join " ", @fields2;
        }

        # start sequence
        if ( substr($line, 0, 5) eq $SPROT_SEQ ) { $seq_start++; }

        if ( $seq_start ) {

          # the first line; just initialize the sequence string
          if ( $seq_start == 1 ) {
            $sprot_hash{$DBA_SEQUENCE} = "";
          } else {
            @fields2 = split " ", $line;
            $seqstr = join "", @fields2;
            $sprot_hash{$DBA_SEQUENCE} = $sprot_hash{$DBA_SEQUENCE} . $seqstr;
          }

          $seq_start++;
        }
      }
    }
  }

  close_file( $file );

  # match not found
  if (! defined($seq_item->{$DBA_SEQID}) ) {
    $seq_item->{$DBA_CNTR} = $cntr;
  }

  return $seq_item;
}


# -----
# motif
# -----

# $motif = read_motif( $motif_file )
#
# Reads sequence motif from a BLOCKS file.
#
sub read_motif {
  my ( $motif_file ) = @_;
  my ( $motif );
  $motif = read_blocks( $motif_file ); 
  return $motif;
}

# ---
# XML
# ---

# sequence XML tags
$XML_SEQROOT = "seqroot";
$XML_SEQENTRY = "seqentry";
$XML_SEQID = "seqid";
$XML_COMMENT = "comment";
$XML_SEQUENCE = "sequence";

# $xmldoc = seq2xml( $seq_hash );
#
# Converts a sequence hash into an xml document
#
sub seq2xml {

  my ( $seq_hash ) = @_;

  my ( $dom_obj, $root_elem, $keys, $key, $seq_item, $xml_seq );
  my ( $item, $text, $xml_element, $xml_decl, $xml_doc );

  $dom_obj = XML::DOM::Document->new();
  $root_elem = $dom_obj->createElement( $XML_SEQROOT );

  $keys = get_seq_keys( $seq_hash );

  for $key ( @$keys ) {

    $seq_item = $seq_hash->{$key};

    $xml_seq = $dom_obj->createElement( $XML_SEQENTRY );

    $item = $seq_item->{$DBA_SEQID}; 
    $text = $dom_obj->createTextNode( $item );
    $xml_element = $dom_obj->createElement( $XML_SEQID );
    $xml_element->appendChild( $text );
    $xml_seq->appendChild( $xml_element );

    $item = $seq_item->{$DBA_COMMENT}; 
    $text = $dom_obj->createTextNode( $item );
    $xml_element = $dom_obj->createElement( $XML_COMMENT );
    $xml_element->appendChild( $text );
    $xml_seq->appendChild( $xml_element );

    $item = $seq_item->{$DBA_SEQUENCE}; 
    $text = $dom_obj->createTextNode( $item );
    $xml_element = $dom_obj->createElement( $XML_SEQUENCE );
    $xml_element->appendChild( $text );
    $xml_seq->appendChild( $xml_element );

    $root_elem->appendChild( $xml_seq );
  }

  $xml_decl = $dom_obj->createXMLDecl ('1.0');
  $xml_doc = $xml_decl->toString . $root_elem->toString;

  return $xml_doc;
}

# $seq_hash = xml2seq( $xmldoc );
#
# Converts an xml document into a sequence hash
#
sub xml2seq {

  my ( $xmldoc ) = @_;

  my ( $dom_parser, $dom_obj, $obj, $seq_hash, $dba_no );
  my ( $seq_item, $item );

  $dom_parser = XML::DOM::Parser->new();
  $dom_obj = $dom_parser->parse( $xmldoc );

  $seq_hash = {};
  $dba_no = 0;

  foreach $obj ( $dom_obj->getElementsByTagName($XML_SEQENTRY) ) {

    $dba_no++;

    # create a new database item, and get a pointer to it
    $seq_hash->{$dba_no} = {};
    $seq_item = $seq_hash->{$dba_no};

    $item = $obj->getElementsByTagName( $XML_SEQID )
	->item(0)->getFirstChild->getNodeValue;
    $seq_item->{$DBA_SEQID} = $item;
 
    $item = $obj->getElementsByTagName( $XML_COMMENT )
	->item(0)->getFirstChild->getNodeValue;
    $seq_item->{$DBA_COMMENT} = $item;

    $item = $obj->getElementsByTagName( $XML_SEQUENCE )
	->item(0)->getFirstChild->getNodeValue;
    $seq_item->{$DBA_SEQUENCE} = $item;
  }
  return $seq_hash;
}

# -------
# BioPerl
# -------

sub add_bioperl_seq {

  my ( $seq_hash, $seqz ) = @_;
  my ( $dba_no, $seq_item );

  $dba_no = keys %$seq_hash;
  $dba_no++;

  $seq_hash->{$dba_no} = {};

  $seq_item = $seq_hash->{$dba_no};
  $seq_item->{$DBA_SEQID} = $seqz->{primary_seq}->{display_id};
  $seq_item->{$DBA_COMMENT} = $seqz->{primary_seq}->{desc};
  $seq_item->{$DBA_SEQUENCE} = $seqz->{primary_seq}->{seq};
}

return 1;

