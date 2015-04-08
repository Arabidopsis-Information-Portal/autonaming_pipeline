#!/usr/local/bin/perl


=head1 NAME

hmmpfam2htab.pl - creates an htab file from hmmpfam raw input
    using HmmTools.pm

=head1 SYNOPSIS

USAGE: hmmpfam2htab.pl
    --input_file=/path/to/hmmpfam.raw
    --output_htab=/path/to/hmmpfam.htab

=head1 OPTIONS

B<--input_file,-i>
    Raw output from hmmpfam run

B<--output_htab,-o>
    HTAB output file

B<--mldbm_file,-m>
    MLDBM perl data structure (tied hash) containing HMM information.  This was previously
    queried out of egad.hmm2.  See hmmlib_to_mldbm.pl for more information.

B<--log,-l>
    Logfile.

B<--help,-h>
    Print this message

=head1  DESCRIPTION

This script is used to convert the output from hmpfam into htab using $ANNOT_DEVEL/hmm/bin/HmmTools.pm

=head1  INPUT

Output can be in multisequence format (generated from hmmpfam from multifasta input).

Can also be a list of file names.

example hmmpfam raw output: 

Logical Depth LDhmmpfam v1.5.4
Copyright (C) Logical Depth, Inc. All rights reserved.
TIGR and TIGR Affiliates 300 CPU-socket License

hmmpfam
HMMER 2.3-compatible (LDhmmpfam)

HMM file:      /usr/local/db/HMM_LIB/ALL_LIB_bin.HMM
Sequence file: /usr/local/annotation/MOORE/output_repository/translate_sequence/8422_translate_promoted/12/cya1.polypeptide.724320.1.fsa

Query sequence: cya1.polypeptide.724320.1
Accession:      [none]
Description:    [none]

Scores for sequence family classification (score includes all domains):
Model     Description                                   Score    E-value #D
--------  -----------                                   -----    ------- --
TIGR01730 RND_mfp: efflux transporter, RND family, MF   114.8    3.5e-31  1
TIGR00998 8a0101: efflux pump membrane protein          -97.8    1.2e-06  1
TIGR00999 8a0102: Membrane Fusion Protein cluster 2 p    -0.3    4.9e-06  1
TIGR01843 type_I_hlyD: type I secretion membrane fusi  -170.3    0.00012  1

...
...
...

Parsed for domains:
Model     Domain Seq-f Seq-t    HMM-f HMM-t      Score  E-value
--------  ------ ----- -----    ----- -----      -----  -------
TIGR03007  1/1      23   432 ..     1   510 []  -337.6     0.54
TIGR01000  1/1      29   442 ..     1   476 []  -289.8     0.25
TIGR01133  1/1      30   293 ..     1   368 []  -183.6      8.9
TIGR00998  1/1      32   434 ..     1   379 []   -97.8  1.2e-06

...
...
...s

Alignments of top-scoring domains:
TIGR03007: domain 1 of 1, from 23 to 432: score -337.6, E = 0.54
                   *->eqllsYlkgiWrr.RwlfvavAwvVmivGwvvvyvlPdrYeAsarVY
                      e+ +   +   +++Rwl+ +v +  +i+ w                 
  cya1.polyp    23    EENRQNTTKNKQFpRWLIPIVILGGGITLWQ---------------- 53   

                   VDTQsvLrPLlkGlAvtPnvdqkirIlsrtLlS.....RpnLekVirmlD
                        + +PL+   + t n     + ++ +LlS+++++R +  +++ +++
  cya1.polyp    54 -----IFSPLVIPTTETNNQTPPPKPVETVLLSsgqgnRQV--RLLGQVE 96   

                   LDvgakspaqlEalitklqknIsIslagrdNLFtISYeDkdPelA.....
                   +  +a+   q  + ++k+  +   s++   + +    +D+d++ A  + +
  cya1.polyp    97 AGAKATLSSQVSGTVEKILVKEGDSITS--GMIVAILDDADGKIAlaeaq 144 



=head1 OUTPUT

    Description of the output format (tab-delimited, one line per domain hit)

    col  perl-col   description
    1      [0]      HMM accession
    2      [1]      Date search was run (if available), otherwise date of htab parse
    3      [2]      Length of the HMM (not populated if -s is used)
    4      [3]      Search program
    5      [4]      Database file path
    6      [5]      Sequence accession
    7      [6]      Alignment start position on HMM match - hmm-f
    8      [7]      Alignment end position on HMM match - hmm-t
    9      [8]      Alignment start position on sequence - seq-f
    10     [9]      Alignment end position on sequence - seq-t
    11     [10]     frame (only populated if --frames search is run on nucleotide sequence)
    12     [11]     Domain score
    13     [12]     Total score
    14     [13]     Index of domain hit
    15     [14]
    16     [15]     HMM description (may be truncated by hmmsearch or hmmpfam if -s is used)
    17     [16]     Sequence description (may be truncated by hmmsearch or hmmpfam)
    18     [17]     Total score trusted cutoff (not populated if -s is used)
    19     [18]     Total score noise cutoff (not populated if -s is used)
    20     [19]     Expect value for total hit
    21     [20]     Expect value for domain hit
    22     [21]     Domain score trusted cutoff (egad..hmm2.trusted_cutoff2) (not populated if -s is used)
    23     [22]     Domain score noise cutoff (egad..hmm2.noise_cutoff2) (not populated if -s is used)
    24     [23]     Total score gathering threshold (not populated if -s is used)
    25     [24]     Domain score gathering threshold (not populated if -s is used)

=head1  CONTACT

    Kevin Galens
    kgalens@tigr.org

=cut

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
use MLDBM 'DB_File';
use Fcntl qw( O_RDONLY );
require Exporter;
use Carp;
use Data::Dumper;

#use Ergatis::IdGenerator;
#use Ergatis::Logger;

####### GLOBALS AND CONSTANTS ###########
my $dbg = 1;
my @input_files;                   #Holds input files
my $output_htab;                   #Output htab file
my $output_alignment;              #Output alignment file
my $debug;                         #The debug variable
my $alignment_format;              #Holds the format to print output formats
my %alignment_formats =            #Accepted output alignment formats
    ( 'mul' => 1,
      'mfs' => 1,
      'fasta' => 1 );
                         
########################################

my %options = ();
my $results = GetOptions (\%options, 
                          'input_file|i=s',
                          'output_htab|o=s',
                          'mldbm_file|m=s',
                          'log|l=s',
                          'debug=s',
                          'help|h') || &_pod;

#Setup the logger
##my $logfile = $options{'log'} || Ergatis::Logger::get_default_logfilename();
##my $logger = new Ergatis::Logger('LOG_FILE'=>$logfile,
##				  'LOG_LEVEL'=>$options{'debug'});
##$logger = $logger->get_logger();

# Check the options.
&check_parameters(\%options);

#Gather information about the hmms.
tie(my %hmm_info, 'MLDBM', $options{mldbm_file}, O_RDONLY ) or die("Unable to tie hash to $options{mldbm_file}");

foreach my $file (@input_files) {

    #Get the output file names;
    my $htab_file = $output_htab;
    if( -d $output_htab ) {
        my $base = $1 if($file =~ m|.*/([^/]+)\.[^/\.]+$| );
        $htab_file = $output_htab.$base.".htab";
    }

    #Generate the htab file.
    system( "rm -f $htab_file" ) if( -e $htab_file );
    my $hmm_data = &generate_htab( $file, $htab_file, \%hmm_info );
}


######################## SUB ROUTINES #######################################
sub generate_htab {
    my ( $file, $outfile, $hmm_db_info ) = @_;

    #If the hmmer output file is in multi sequence format, HmmTools.pm can't handle it.
    #So we will add the functionality here.
    my $tmp_dir = "/tmp/hmmpfam2htab/$$"; #append process id..this will break ongrid!
    my @tmp_files = &write_tmp_files( $file, $tmp_dir );

    foreach my $tmp_file ( @tmp_files ) {

        my $data = read_hmmer_output( $tmp_file );

        my $htab_h;
        open( $htab_h, ">> $outfile") or die("Unable to open $outfile for writing ($!)");
        &print_htab( $data, $hmm_db_info, $htab_h );
        close( $htab_h );
    }

    #Remove the tmp directory
    system( "rm -rf $tmp_dir" );

}

sub write_tmp_files {
    my ($file, $outdir) = @_;
    my @files;
    my $header;

    open( RAW, "< $file" ) or die("Unable to open $file ($!)");
    system( "mkdir -p $outdir" );


    my ($oh, $flag);
    while( my $line = <RAW> ) {
        chomp($line);
        if( $line =~ /query sequence file\:\s+(.*)/ ) {
	    my $base = $1;
	    $base =~ s|/||g; # remove slashes from file name
            my $tmp_file = "$outdir/$base.tmp.raw";
            push( @files, $tmp_file );
            close($oh) if($oh);
            open( $oh, "> $tmp_file") or die("Can't open temp file for writing $tmp_file ($!)");
            print $oh "$header$line\n";
            $flag = 1;
        } elsif( $flag ) {
            print $oh $line."\n";
        } else {
            $header .= $line."\n";
        }
    }
    close($oh) if($oh);

    return @files;

}


sub check_parameters {
    my $options = shift;

    &_pod if($options{'help'});

    ## mldbm file must be passed
    if ( ! $options{mldbm_file} ) {
        die("Option mldbm_file is required\n");
    }

    if($options{'input_file'}) {
        die("Option input_file ($options{'input_file'}) does not exist\n") 
            unless(-e $options{'input_file'});
        my $infile = $options{'input_file'};
        open( IN, "< $infile") or die("Unable to open $infile ($!)");
        chomp( my $first_line = <IN> );
        if( -e $first_line ) {
            chomp( @input_files = <IN> );
            push( @input_files, $first_line );
        } else {
            push( @input_files, $infile );
        }
        close IN;

    } else {
        die("Option input_file is required\n");
    }

    unless($options{'output_htab'}) {
        die("Option output_htab is required\n");
    } else {
        $output_htab = $options{'output_htab'};
        if( @input_files > 1 && -f $output_htab ) {
            $output_htab = $1 if($output_htab =~ m|^(.*)/[^/]+|);
            warn("Using $output_htab as output directory because a list of files was passed in");
        }
        
    }

    if($options{'debug'}) {
        $debug = $options{'debug'};
    }
    
}

sub _pod {   
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}

sub read_hmmer_output {
    my $path = shift;
	if ( $dbg ) { print STDERR "--- $path -------------------------\n" . `cat $path` . "\n" }
    my $data = {};

    # drink in data
    my @lines;

    # drink in the output from file or stdin
    if ( $path ne '' ) {
        chomp $path;
        my @statd = stat $path;
        $data->{ 'search_date' } =
            ( ( localtime( $statd[ 9 ] ) )[ 3 ] ) . "-"
          . ( ( localtime( $statd[ 9 ] ) )[ 4 ] + 1 ) . "-"
          . ( ( localtime( $statd[ 9 ] ) )[ 5 ] + 1900 );
        open( FH, "$path" )
          || die "Can't open $path for reading: $!\n";
        chomp( @lines = <FH> );
        close FH;
    }
    else {
        chomp( @lines = <STDIN> );
        $data->{ 'search_date' } =
            ( ( localtime )[ 3 ] ) . "-"
          . ( ( localtime )[ 4 ] + 1 ) . "-"
          . ( ( localtime )[ 5 ] + 1900 );
    }
    if ( !@lines ) {
        carp "No data read from input $path";
        return undef;
    }
    my $i = 0;

    # first line grouping is company, package and license info
    # warn "Parsing License. Line $i\n";
    # amahurkar:1/15/08 Seems like the current output does not have licesning info, so commenting this
    # jinman:08/04/10: whatever... changing it back.
    # so commenting out these lines 
    until ( $lines[ $i ] =~ /^# -/ ) {
        if ( $lines[ $i ] =~ / (hmmscan) ::/ ) {
            $data->{ 'program' } = $1;
            my $version_line = $lines[ ++$i ];
            $version_line =~ / HMMER (\d+)\.(\S+)/;
            ( $data->{ 'version' }, $data->{ 'release' } ) = ( $1, $2 );
        } else {
        	$data->{ 'header' } .= $lines[ $i ] . "\n";
		}
		$i++;
    }
    $i++;



    # next group is program parameters
    # warn "Parsing Parameters. Line $i\n";
    # amahurkar:1/15/08 the format has changed and now there is no blank space
    # after program name, so we are using '- -' as tha match param
    # to stop parsing for program parameters
    until ( $lines[ $i ] =~ /^\s*$/ ) {
if ( $dbg ) { print STDERR "read1 $i=$lines[$i]\n" }
    #until ( $lines[ $i ] =~ m/^-\s-/) {
        if ( $lines[ $i ] =~ /^# target HMM (file|database):\s+(\S+)/ ) {
            $data->{ 'hmm_file' } = $2;
        }
        elsif ( $lines[ $i ] =~ /^# query sequence (file|database):\s+(.+)/ ) {
            $data->{ 'sequence_file' } = $2;
        }
        elsif ( $lines[ $i ] =~ /^# per-sequence score cutoff:\s+(.+)/ ) {
            $data->{ 'total_score_cutoff' } = $1;
        }
        elsif ( $lines[ $i ] =~ /^# per-domain score cutoff:\s+(.+)/ ) {
            $data->{ 'domain_score_cutoff' } = $1;
        }
        elsif ( $lines[ $i ] =~ /^# per-sequence E-value cutoff:\s+(.+)/ ) {
            $data->{ 'total_evalue_cutoff' } = $1;
        }
        elsif ( $lines[ $i ] =~ /^# per-domain E-value cutoff:\s+(.+)/ ) {
            $data->{ 'domain_evalue_cutoff' } = $1;
        }
        $i++;
    }
    $i++; 
    
    # get query info
    # warn "Parsing Query Info. Line $i\n";
    until ( $lines[ $i ] =~ /^(Scores for|No hits)/ ) { # check no hits case
if ( $dbg ) { print STDERR "read2 $i=$lines[$i]\n" }
       	$data->{ 'query' } = "";
       	$data->{ 'query_accession' } = "";
       	$data->{ 'query_description' } = "";
        if ( $lines[ $i ] =~ /^Query:\s+(.+)\s+/ ) {
            $data->{ 'query' } = $1;
        }
        elsif ( $lines[ $i ] =~ /^Accession:\s+(.+)/ ) {
            $data->{ 'query_accession' } = $1;
        }
        elsif ( $lines[ $i ] =~ /^Description:\s+(.+)/ ) {
            $data->{ 'query_description' } = $1;
        }
        else {
        	$data->{ 'query_description' } = "";
        }
        $i++;
    }

    # next section is global search results
    my $find_frame = 0;  # is datbase nucleotide sequence?
    my $hit_index;
    $i += 4;
    until ( $lines[ $i ] eq "" ) {
if ( $dbg ) { print STDERR "read3 $i=$lines[$i]\n" }
        if ( $lines[ $i ] =~ /(No targets|No hits)/i ) {
        	return;
        }
        if ( $lines[$i] =~ /^\s*$/ ) { $i++ }
        if ( $lines[$i] =~ /\[No hits/ ) { return }

        my @c = split /\s+/, $lines[ $i ];
        if ( $find_frame ) { # check this
            $hit_index = $c[ 0 ] . $c[ $#c ];
            if ( $hit_index =~ /^(PF[0-9]{5})\.[0-9]*$/ ) { $hit_index = $1 }
            $data->{ 'hit' }->{ $hit_index }->{ 'frame' } = pop @c;
        } else {
            $hit_index = "$c[9]";
            if ( $hit_index =~ /^(PF[0-9]{5})\.[0-9]*$/ ) { $hit_index = $1 }
            $data->{ 'hit' }->{ $hit_index }->{ 'frame' } = "";
        }
        if ( $c[9] =~ /^(PF[0-9]{5})\.[0-9]*$/ ) { $c[9] = $1 }
        
        $data->{ 'hit' }->{ $hit_index }->{ 'accession' }    = $c[9];
        $data->{ 'hit' }->{ $hit_index }->{ 'domain_count' } = $c[8];
        $data->{ 'hit' }->{ $hit_index }->{ 'total_evalue' } = $c[1];
        $data->{ 'hit' }->{ $hit_index }->{ 'total_score' }  = $c[2];
        $data->{ 'hit' }->{ $hit_index }->{ 'hit_description' } = join " ", @c[10..$#c];
if ( $dbg ) {
	print STDERR "parse3 $i=$lines[$i]
hit: $hit_index
accession: $data->{ 'hit' }->{ $hit_index }->{ 'accession' }
numDomains: $data->{ 'hit' }->{ $hit_index }->{ 'domain_count' }
evalue: $data->{ 'hit' }->{ $hit_index }->{ 'total_evalue' }
score: $data->{ 'hit' }->{ $hit_index }->{ 'total_score' }
description: $data->{ 'hit' }->{ $hit_index }->{ 'hit_description' }\n";
}

        $i++;
    }
    $i++;


    # next section is domain breakdown
    until ( $lines[ $i ] =~ /^Internal/ ) {
	
		if ( $dbg ) { print STDERR "next $i: $lines[$i]\n" }
        if ( $lines[$i] !~ /^>> (.+?)\s+/) {
        	$i++;
        }	
        else {
			$hit_index=$1;
        	if ( $lines[$i+1] =~ /No individual domains/ ) {
        		$i++;
        	}
        	else {
	            if ( $hit_index =~ /^(PF[0-9]{5})\.[0-9]*$/ ) { $hit_index = $1 }
				if ( $dbg ) { print STDERR "hdr  $hit_index\n" }
				$i += 3;
				while ( $lines[$i] !~ /^\s*$/ ) {
					if ( $dbg ) { print STDERR "dom  $i=$lines[$i]\n" }
		            my @c = split /\s+/, $lines[ $i ];
		            if ( $find_frame ) { # check this
		                $hit_index = $c[ 0 ] . $c[ $#c ];
		            }
					if ( $dbg ) { print STDERR "c=" . join( " , ", @c ) . "\n" }
			  
				    my $d=$c[1];
		            $data->{ 'hit' }->{ $hit_index }->{ 'domain' }->{ $d }
		              ->{ 'seq_f' } = $c[ 10 ];
		            $data->{ 'hit' }->{ $hit_index }->{ 'domain' }->{ $d }
		              ->{ 'seq_t' } = $c[ 11 ];
		            $data->{ 'hit' }->{ $hit_index }->{ 'domain' }->{ $d }
		              ->{ 'hmm_f' } = $c[ 7 ];
		            $data->{ 'hit' }->{ $hit_index }->{ 'domain' }->{ $d }
		              ->{ 'hmm_t' } = $c[ 8 ];
		            $data->{ 'hit' }->{ $hit_index }->{ 'domain' }->{ $d }
		              ->{ 'domain_score' } = $c[ 3 ];
		            $data->{ 'hit' }->{ $hit_index }->{ 'domain' }->{ $d }
		              ->{ 'domain_evalue' } = $c[ 5 ];
		            $i++;
		    	}
	        }
        }
    }

    return $data;
}


    
sub hmm_database_info {
    my $dbh   = shift;
    my $hmm_q =
      "SELECT hmm_acc, hmm_len, trusted_cutoff, noise_cutoff, hmm_com_name,"
      . " trusted_cutoff2, noise_cutoff2, gathering_cutoff, gathering_cutoff2"
      . " FROM hmm2"
      . " WHERE is_current = 1";
    my $HMM = $dbh->selectall_hashref( $hmm_q, 'hmm_acc' );
    return $HMM;
}

sub print_htab {
    my $data   = shift;
    my $HMM    = shift;
    my $output = shift;

    foreach my $hit (
        sort {
            $data->{ 'hit' }->{ $b }->{ 'total_score' } <=> $data->{ 'hit' }
              ->{ $a }->{ 'total_score' }
        } keys %{ $data->{ 'hit' } }
      )
    {
        my $h = $data->{ 'hit' }->{ $hit };
        foreach my $domain ( sort { $a <=> $b } keys %{ $h->{ 'domain' } } )
        {
            # for convenience
            my $dh = $h->{ 'domain' }->{ $domain };
            if ( $data->{ 'program' } =~ /hmmsearch/ ) {
                my $hmm_com_name =
                    $HMM->{ $data->{ 'query' } }->{ 'hmm_com_name' }
                  ? $HMM->{ $data->{ 'query' } }->{ 'hmm_com_name' }
                  : $data->{ 'query_description' };
                print $output "$data->{query}"
                  . "\t$data->{search_date}"
                  . "\t$HMM->{$data->{query}}->{hmm_len}"
                  . "\t$data->{program}"
                  . "\t$data->{sequence_file}"
                  . "\t$h->{accession}"
                  . "\t$dh->{hmm_f}"
                  . "\t$dh->{hmm_t}"
                  . "\t$dh->{seq_f}"
                  . "\t$dh->{seq_t}"
                  . "\t$h->{frame}"
                  . "\t$dh->{domain_score}"
                  . "\t$h->{total_score}"
                  . "\t$domain"
                  . "\t$h->{domain_count}"
                  . "\t$hmm_com_name"
                  . "\t$h->{hit_description}"
                  . "\t$HMM->{$data->{query}}->{trusted_cutoff}"
                  . "\t$HMM->{$data->{query}}->{noise_cutoff}"
                  . "\t$h->{total_evalue}"
                  . "\t$dh->{domain_evalue}"
                  . "\t$HMM->{$data->{query}}->{trusted_cutoff2}"
                  . "\t$HMM->{$data->{query}}->{noise_cutoff2}"
                  . "\t$HMM->{$data->{query}}->{gathering_cutoff}"
                  . "\t$HMM->{$data->{query}}->{gathering_cutoff2}" . "\n";
            }
            elsif ( $data->{ 'program' } =~ /(hmmscan|hmmpfam)/ ) {
            	my $cazy = "CAZY_$hit";
            	if (!$HMM->{$hit} && $HMM->{$cazy}) {
            		my $hmm_com_name =
                    	$HMM->{ $cazy }->{ 'hmm_com_name' }
                  		? $HMM->{ $cazy }->{ 'hmm_com_name' }
                  		: $h->{ 'hit_description' };
                	print $output "$h->{accession}"
                   		. "\t$data->{search_date}"
		                . "\t$HMM->{$cazy}->{hmm_len}"
		                . "\t$data->{program}"
		                . "\t$data->{hmm_file}"
		                . "\t$data->{query}"
		                . "\t$dh->{hmm_f}"
		                . "\t$dh->{hmm_t}"
		                . "\t$dh->{seq_f}"
		                . "\t$dh->{seq_t}"
		                . "\t$h->{frame}"
		                . "\t$dh->{domain_score}"
		                . "\t$h->{total_score}"
		                . "\t$domain"
		                . "\t$h->{domain_count}"
		                . "\t$hmm_com_name"
		                . "\t$data->{query_description}"
		                . "\t$HMM->{$cazy}->{trusted_cutoff}"
		                . "\t$HMM->{$cazy}->{noise_cutoff}"
		                . "\t$h->{total_evalue}"
		                . "\t$dh->{domain_evalue}"
		                . "\t$HMM->{$cazy}->{trusted_cutoff2}"
		                . "\t$HMM->{$cazy}->{noise_cutoff2}"
		                . "\t$HMM->{$cazy}->{gathering_cutoff}"
		                . "\t$HMM->{$cazy}->{gathering_cutoff2}" . "\n";
            	} else {
                	my $hmm_com_name =
                    	$HMM->{ $hit }->{ 'hmm_com_name' }
                  		? $HMM->{ $hit }->{ 'hmm_com_name' }
                  		: $h->{ 'hit_description' };
                	print $output "$h->{accession}"
                   		. "\t$data->{search_date}"
		                . "\t$HMM->{$hit}->{hmm_len}"
		                . "\t$data->{program}"
		                . "\t$data->{hmm_file}"
		                . "\t$data->{query}"
		                . "\t$dh->{hmm_f}"
		                . "\t$dh->{hmm_t}"
		                . "\t$dh->{seq_f}"
		                . "\t$dh->{seq_t}"
		                . "\t$h->{frame}"
		                . "\t$dh->{domain_score}"
		                . "\t$h->{total_score}"
		                . "\t$domain"
		                . "\t$h->{domain_count}"
		                . "\t$hmm_com_name"
		                . "\t$data->{query_description}"
		                . "\t$HMM->{$h->{accession}}->{trusted_cutoff}"
		                . "\t$HMM->{$h->{accession}}->{noise_cutoff}"
		                . "\t$h->{total_evalue}"
		                . "\t$dh->{domain_evalue}"
		                . "\t$HMM->{$h->{accession}}->{trusted_cutoff2}"
		                . "\t$HMM->{$h->{accession}}->{noise_cutoff2}"
		                . "\t$HMM->{$h->{accession}}->{gathering_cutoff}"
		                . "\t$HMM->{$h->{accession}}->{gathering_cutoff2}" . "\n";
            	}
            }
        }
    }
}

sub build_alignment {
    my $data         = shift;
    my $instructions = shift;

    # build output file name
    my $output_file;
    $output_file =
      $instructions->{file_prefix} . "." . $instructions->{file_format};
    open my $OUT, ">$output_file"
      or croak "Can't open '$output_file' as output file: $!\n";
    select $OUT;

    # retrieve aligned sequences
    my %screened;
    foreach my $hit ( keys %{ $data->{ 'hit' } } ) {

        # screen for total score cutoffs
        if ( $data->{hit}->{ $hit }->{total_score} >=
               $instructions->{total_bit_cutoff}
            && $data->{hit}->{ $hit }->{total_evalue} <=
            $instructions->{total_evalue_cutoff} )
        {
            foreach my $domain ( keys %{ $data->{hit}->{ $hit }->{domain} } )
            {
                if ( $data->{hit}->{ $hit }->{domain}->{ $domain }
                    ->{domain_score} >= $instructions->{domain_bit_cutoff}
                    && $data->{hit}->{ $hit }->{domain}->{ $domain }
                    ->{domain_evalue} <=
                    $instructions->{domain_evalue_cutoff} )
                {
                    $screened{ $hit } = $domain;
                }
            }
        }
    }

    # Now that we have sequences aligned to hmm sequence, we have to translate
    # this into a multiple alignment. Assign each position in each alignment to
    # a position on the hmm 'sequence', and keep track of gaps in the hmm alignment
    my %DIST;
    foreach my $hit ( keys %screened ) {
        my $ref =
          $data->{ 'hit' }->{ $hit }->{ 'domain' }->{ $screened{ $hit } };

        # split aligned hmm seq and aligned protein seq into arrays
        my @hmma  = split / */, $ref->{hmm_seq};
        my @prota = split / */, $ref->{prot_seq};

        # these should be the same length. If not, there's an error.
        if ( @hmma != @prota ) {
            croak "Length of hmm alignment (" . @hmma . ")"
              . " is not equal to protein alignment ("
              . @prota . ")"
              . ": $data->{query}/$data->{hit}->{$hit}->{accession}\n"
              . "$ref->{hmm_seq}\n@hmma\n$ref->{prot_seq}\n@prota\n";
        }

       # assign each position in the protein alignment to its hmm alignment position,
       # if one exists
        my $hmm_pos = $ref->{hmm_f};
        my $gap     = 0;
        for ( my $i = 0 ; $i < @hmma ; $i++ ) {
            if ( $hmma[ $i ] ne "." ) {

                # assign position in the protein alignment to its hmm alignment position,
                $prota[ $i ] = $hmm_pos;

                # record max gap distance between hmm alignment positions.
                $DIST{ $hmm_pos } = $gap
                  if ( $gap >= $DIST{ $hmm_pos } );
                $gap = 0;
                $hmm_pos++;
            }
            else {
                $gap++;
            }
        }
        $ref->{aln_map} = \@prota;
    }

    # Now go back through (now that we've fully expanded the hmm alignment
    # to include any and all gaps) and make aligned protein sequence
    foreach my $hit ( keys %screened ) {
        my $ref =
          $data->{ 'hit' }->{ $hit }->{ 'domain' }->{ $screened{ $hit } };
        my @prot_seq = split / */, $ref->{prot_seq};

        # start our aligned protein with any gap resulting from a partial HMM hit.
        my $aln_prot = "." x ( $ref->{hmm_f} - 1 );
        my $insert = 0;
        for ( my $i = 0 ; $i < @prot_seq ; $i++ ) {

            # grab the hmm alignment position for each protein alignment position
            my $pos = $ref->{aln_map}->[ $i ];
            if ( $pos =~ /\d+/ ) {

                # if it maps to a position, first insert any gap from the hmm alignment
                $aln_prot .= "." x ( $DIST{ $pos } - $insert );

                # then add the aa.
                $aln_prot .= $prot_seq[ $i ];
                $insert = 0;
            }

            # if it is an insertion (ie the hmm alignment shows gap), insert a gap
            else {
                $aln_prot .= $prot_seq[ $i ];
                $insert++;
            }
        }
        $aln_prot =~ s/\-/\./g;
        $ref->{aln_prot} = $aln_prot;
    }

    # Now print out in selected format
    # Stockholm format
    if ( $instructions->{file_format} eq "mul" ) {
        print "# STOCKHOLM 1.0\n";
        foreach my $hit (
            sort {
                $data->{ 'hit' }->{ $b }
                  ->{ 'total_score' } <=> $data->{ 'hit' }->{ $a }
                  ->{ 'total_score' }
            } keys %screened
          )
        {
            my $domain     = $screened{ $hit };
            my $hit_ref    = $data->{hit}->{ $hit };
            my $domain_ref = $hit_ref->{domain}->{ $domain };

            # each line should look like:
            # prot_acc/coord-coord sequence
            printf "%-40s%s\n",
              (
                "$hit_ref->{accession}/$domain_ref->{seq_f}-$domain_ref->{seq_t}",
                $domain_ref->{aln_prot}
              );
        }
    }

    # FASTA format
    elsif ($instructions->{file_format} eq "fasta"
        || $instructions->{file_format} eq "fa" )
    {
        foreach my $hit (
            sort {
                $data->{ 'hit' }->{ $b }
                  ->{ 'total_score' } <=> $data->{ 'hit' }->{ $a }
                  ->{ 'total_score' }
            } keys %screened
          )
        {
            my $domain     = $screened{ $hit };
            my $hit_ref    = $data->{hit}->{ $hit };
            my $domain_ref = $hit_ref->{domain}->{ $domain };
            my $aln_prot = $domain_ref->{aln_prot};
            $aln_prot =~ s/(.{60})/$1\n/g;
            $aln_prot =~ s/\n+/\n/g;
            chomp $aln_prot;
            my $header =
              ">$hit_ref->{accession}/$domain_ref->{seq_f}-$domain_ref->{seq_t}\n";
            print $header . $aln_prot . "\n";
        }
    }

    # MSF format
    elsif ( $instructions->{file_format} eq "msf" ) {
        my $head_len = 40;
        my ( %new_acc, %tmp_seq );
        my $header_line = 0;
        my @alignment;
        foreach my $hit (
            sort {
                $data->{ 'hit' }->{ $b }
                  ->{ 'total_score' } <=> $data->{ 'hit' }->{ $a }
                  ->{ 'total_score' }
            } keys %screened
          )
        {
            my $domain     = $screened{ $hit };
            my $hit_ref    = $data->{hit}->{ $hit };
            my $domain_ref = $hit_ref->{domain}->{ $domain };
            my $len        = length( $domain_ref->{aln_prot} );
            if ( $header_line == 0 ) {

                #added DUMMY checksum for HMMER 2.2g hmmbuild. DHH.
                print
                  "PileUp\n\n   MSF:  $len  Type: P  Check: 1111  ..\n\n";
                $header_line = 1;
            }

            # print accession list at top
            printf " Name: %-40s Len:  $len  Check:   0  Weight:  1.0\n",
              "$hit_ref->{accession}/$domain_ref->{seq_f}-$domain_ref->{seq_t}";

            # prepare alignment for bottom
            my @tmp_pep = split //, $domain_ref->{aln_prot};
            for ( my $i = 0 ; $i < ( $len / 50 ) ; $i++ ) {
                $alignment[ $i ] .= sprintf "%-40s",
                  "$hit_ref->{accession}/$domain_ref->{seq_f}-$domain_ref->{seq_t}";
                for ( my $b = 0 ; $b < 5 ; $b++ ) {
                    for ( my $a = 0 ; $a < 10 ; $a++ ) {
                        $alignment[ $i ] .=
                          $tmp_pep[ $a + ( $b * 10 ) + ( 50 * $i ) ];
                    }
                    $alignment[ $i ] .= " ";
                }
                $alignment[ $i ] .= "\n";
            }
        }
        print "\n//\n\n\n";
        foreach my $block ( @alignment ) {
            print "$block\n\n";
        }
    }
    else {
        croak
          "Don't recognize alignment file format $instructions->{file_format}\n";
    }
    select STDOUT;
}

sub get_cutoffs_for_hmm_accession {
    my $dbh       = shift;
    my $accession = shift;
    my $hmm_q     =
      "select trusted_cutoff, trusted_cutoff2, noise_cutoff from egad..hmm2 where hmm_acc = '$accession'";
    return $dbh->selectrow_hashref( $hmm_q );
}
1;
