#!/usr/local/bin/perl

=head1 NAME
    
    .pl
    
=head1 USAGE

    .pl [-]-results_path <results_path> [-]-evidence_location <infile> [-]-project_code <project_code>

=head1 REQUIRED ARGUMENTS

=over

=item [-]-evidence_location  <evidence_location>

path to the location of the evidence to be used for autonaming.

=for Euclid:
    evidence_location.type: readable

=item [-]-results_path  <results_path>

full path to the location results files should be written

=for Euclid:
    results_path.type: string

=item [-]-service  <service>

service type to indicate where to look for optional parameter configurations

=for Euclid:
    service.type: string

=item [-]-project_code  <project_code>

charge code for using the grid

=for Euclid:
    project_code.type: string
       
=back

=head1 OPTIONS

=over

=item [-]-queue  <queue>

Specifies a queue for the grid jobs
   
=for Euclid:
    queue.type: string

=item [-]-config  <config>

Specifies a config file (ini format) used to overide standard pipeline configurations and default parameters

=for Euclid:
	config.type: string

=item [-]-project_tag  <project_tag>

=for Euclid:
	project_tag.type: string

=item [-]-skip_blast

skips the blast search step.

=back

=head1 DESCRIPTION

This script will run .

=cut

use strict;
use Config::IniFiles;
use FindBin;
require "$FindBin::Bin/pipeline_lib.pl";

use lib "/usr/local/devel/VIRIFX/software/VGD/lib";
use Getopt::Euclid 0.2.4 qw(:vars);

my $evidence_location = $ARGV_evidence_location;
my $results_path = $ARGV_results_path;
my $queue = $ARGV_queue;
my $config = $ARGV_config;
my $grid_code = $ARGV_project_code;
my $skip_blast = $ARGV_skip_blast;
my $tag = $ARGV_project_tag;
my $service = $ARGV_service;

my $program_path = $0;
my @prog = split '/', $program_path;
my $program = pop @prog;
my @files;

my $makedb = "$FindBin::Bin/makeDB.pl";
my $common_names = "$FindBin::Bin/common_names.pl";

my $dbname = "$results_path/autonaming_results.db";

my $make_cmd = "$makedb $dbname $evidence_location";
print "$make_cmd\n";
system($make_cmd);

my $auto_cmd = "$common_names -d $dbname -o $results_path -verbose";
print "$auto_cmd\n";
my $output = `$auto_cmd`;

my $log_file = "$results_path/autonaming.log";
open (OUT, ">$log_file") || die "Cannot open $log_file.";
print OUT "$output";
close OUT;