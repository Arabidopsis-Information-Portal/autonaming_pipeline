#!/usr/local/bin/perl
$| = 1;

=head1 NAME

    common_names.pl - Reads evidence from sqlite3 database and assigns a common name

=head1 SYNOPSIS

USAGE: common_names.pl -d /database/location/sqlite.db -o /output/directory/ [ --gzip ]

=head1 OPTIONS

B<--database,-d>
    REQUIRED. Path for sqlite3 database

B<--output,-o>
    REQUIRED. The directory you would like your output files written to.

B<--excludecomputes,--xc>
    OPTIONAL.  Exclude evidence categories (comma separated list of "job"names) computes.

B<--excludetaxon,--xt>
    OPTIONAL.  Exclude entries from specific taxons (comma-delimited list of taxon ids).

B<--excludebranch,--xb>
    OPTIONAL.  Exclude entries from specified taxon branches (comma-delimited list of taxon ids).

B<--gzip,-g>
    OPTIONAL.  Setting gzip flag will write to compressed files. By default this is set to 0.

B<--queryseq,-q>
    OPTIONAL.  Annotate a specific query sequence. (mostly used during debugging)

B<--threshold,-t>
    OPTIONAL.  Set the "consensus" threshold. (default is 0.8)

B<--verbose,-v>
    OPTIONAL.  Verbose output (displays protein evidence and scored names).
    
B<--help,-h>
    Print this message

=head1  DESCRIPTION

    This scripts reads in a sqlite3 database file which contains various evidence searches.
    The script then assigns a product name based on the search results.

=head1 OUTPUT

    prefix.common_names[.gz] - File contains assigned common names for the ORFs.

=head1  CONTACT

    Jeff Hoover
	jhoover@jcvi.org

=cut

#use warnings;
use strict;

#use lib ('/usr/local/devel/ANNOTATION/EAP/naming');

use Getopt::Long;
use Data::Dumper;
use Pod::Usage;
use Cwd 'realpath';
use File::Basename;
use DBI;

my $program = realpath($0);
my $pgmdir  = dirname($program);

our $myLib = dirname($program) . "/lib";
push @INC, $myLib;
require 'db.pm';
require 'generic.pm';
require 'cm_parse.pm';
require 'nameutl.pm';
require 'wkw.pm';
my %opts = ();    # Will store command line options
my ( $database, $coverage, $percid, $evalue, $output, $db_dir, $gzip );
my $job_id;

print "\ncommand: $0 " . join( " ", @ARGV ) . "\n";

our $verbose;
our %goNames;
our ( %ecdefs, %ecprofs );
our ( $excludecompute, $consensus_threshold, $trusted_list, $exclude_taxon_id,
	$excludebranch_taxon_id, $excludedtaxons, $taxonomy_lookup, $queryseq );
our ( $greek, $roman, $kingdoms,
		$domains, $isoforms, $groups, $subunits,
		$homologs, $homologous, $strength, $enzymes,
		$gerunds, $gerund2noun,
		$goodends, $badends,
		$keeppros, $aminoacids,
		$unknowns ) = special_words();

GetOptions( \%opts, 'database|d=s', 'output|o=s', 'help|h', 'queryseq|q=s',
	'gzip|g', 'verbose|v', 'consensus|k=s', 'trusted|t=s',
	'excludecompute|xc=s', 'excludetaxon|xt=s', 'excludebranch|xb=s' ) || &_pod;

# check the options and read in the config
check_options();

# create scratch directory
my $workingdir = create_workspace();

# open sqlite evidence database
my ($library_name) = split /\./, basename($database);
my $dbh = connectSQLite($database) || die "Error connecting.\n";

# open output files
if ($verbose) { print "Opening output files\n" }
my $afh = open_filehandle( "$output/$library_name.common_names", $gzip, "OUT" );

# cross-reference uniref and ncbi taxonomy
# (only if taxonomy is being used)
if (  defined $exclude_taxon_id
	|| defined $excludebranch_taxon_id )
{
	$excludedtaxons = get_excluded_taxons( $exclude_taxon_id, $excludebranch_taxon_id ); 
	print "cross-referencing UNIREF taxonomy to NCBI\n";
	cross_reference_taxonomy( $dbh );
}

# collect GO definitions
print "collecting GO definitions\n";
collect_GO_definitions();

# collect PRIAM/EC details
print "collecting PRIAM/EC details\n";
collect_PriamEC_details();

# get list of evidence categories
print "cataloging evidence\n";
my $job_list = &get_jobs($dbh);

# get list of query ids
print "fetching query sequences\n";
my $querySeqs = &get_query_seqs( $dbh, $queryseq );
if ( !defined $querySeqs ) {
	print "No query sequences found.\n";
	exit(0);
}

# for each query sequence
print "starting annotation\n";
for my $seq_acc ( sort { $a cmp $b } keys %$querySeqs ) {
	my $seq_list = $$querySeqs{$seq_acc};
	print "\n" . rpad( "$seq_acc ($seq_list) ", 120, "=" ) . "\n";

	# collect evidence for query sequence
	my ( $besthit, $evidence ) = collect_query_evidence( $dbh, $seq_list, $job_list );
	if ($verbose) {
		display_evidence( $evidence );
	}
	if ( ! defined $besthit ) {
		report_hypothetical_protein( $afh, $seq_acc );
		next;
	}

	# collect names from evidence
	my $names = collect_evidence_names($evidence);
	if ( ! defined $names ) {
		report_conserved_hypothetical_protein( $afh, $seq_acc, $besthit );
		next;
	}

	# collect keywords from names
	my $keywords = collect_name_keywords($names);
	if ( ! defined $keywords ) {
		report_conserved_hypothetical_protein( $afh, $seq_acc, $besthit );
		next;
	}		

	# weight keyword evidence
	weight_keyword_evidence( $keywords, $evidence );

	# score names based on weighted keywords
	score_names( $names, $keywords );

	# find consensus among top names
	my $consensus = find_consensus_name( $names, $keywords, $consensus_threshold );
	if ($verbose) {
		display_names($consensus);
	}

	# select and output best name
	output_best_name( $afh, $seq_acc, $consensus, $besthit );
}

$dbh->disconnect();
close $afh;

if ($verbose) { print "annotation completed\n" }

exit(0);

##############################################################

sub check_options {

# Parse the options.  Override the configs with command-line options, if they've been given
# Make sure we have the required options by the end of this subprocedure.
	my $errors = '';
	my $usage  =
"./common_names.pl -d /database/location/sqlite.db -o /output/directory/";

	if ( $opts{'help'} ) {
		&_pod;
		exit(0);
	}

	# get the options from the ini file.
	if ( $opts{'database'} ) {
		if ( -s $opts{database} ) {
			$database = $opts{database};
		}
		else {
			die "\n$opts{database} does not exist or is an empty file\n";
		}
	}
	else {
		print STDERR "\nDatabase is required. -d \n\n";
		print STDOUT "Usage: $usage\n";

		exit(0);
	}

	if ( $opts{'output'} ) {
		$output = $opts{output};
	}
	else {
		print STDERR "\nOutput directory is required. -o /output_dir/ \n\n";
		print STDOUT "Usage: $usage\n";

		exit(0);
	}

	$gzip = $opts{'gzip'} || 0;

	$verbose = $opts{'verbose'} || 0;

	if ( defined $opts{'consensus'} ) {
		$consensus_threshold = $opts{consensus};
	}
	else {
		$consensus_threshold = 0.80;
	}
	if ( $consensus_threshold < 0 || $consensus_threshold > 1 ) {
		die "\nthreshold (-t $consensus_threshold) must be between 0 and 1\n";
	}
	if ( $consensus_threshold < 0 || $consensus_threshold > 1 ) {
		die "\nthreshold (-t $consensus_threshold) must be between 0 and 1\n";
	}

	if ( defined $opts{'trusted'} ) {
		$trusted_list = "," . uc( $opts{trusted} ) . ",";
		$trusted_list =~ s/ //g;
	}
	else {
		$trusted_list = "";
	}

	if ( $opts{'excludetaxon'} ) {
		$exclude_taxon_id = $opts{excludetaxon};
	}
	else {
		$exclude_taxon_id = undef;
	}

	if ( $opts{'excludebranch'} ) {
		$excludebranch_taxon_id = $opts{excludebranch};
	}
	else {
		$excludebranch_taxon_id = undef;
	}

	if ( $opts{'excludecompute'} ) {
		$excludecompute = uc( $opts{excludecompute} );
		$excludecompute =~ s/^  *//;
		$excludecompute =~ s/  *$//;
		$excludecompute =~ s/ *, */|/g;
		$excludecompute = "|$excludecompute|";
	}
	else {
		$excludecompute = undef;
	}

	if ( $opts{'queryseq'} ) {
		$queryseq = $opts{'queryseq'};
	}

	return;
}

sub _pod {
	pod2usage( { -exitval => 0, -verbose => 2, -output => \*STDERR } );
}
