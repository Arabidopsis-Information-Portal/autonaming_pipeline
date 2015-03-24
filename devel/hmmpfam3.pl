#!/usr/local/bin/perl

=head1 NAME
    
    .pl
    
=head1 USAGE

    .pl [-]-results_path <results_path> [-]-infile <infile> [-]-project_code <project_code>

=head1 REQUIRED ARGUMENTS

=over

=item [-]-infile  <infile>

file containing a full path list of all multifasta files to process through the pipeline.

=for Euclid:
    infile.type: readable

=item [-]-results_path  <results_path>

full path to the location results files should be written

=for Euclid:
    results_path.type: string

=item [-]-project_code  <project_code>

charge code for using the grid

=for Euclid:
    project_code.type: string

=for Euclid:
    results_path.type: string

=item [-]-service  <service>

service type to indicate where to look for optional parameter configurations
    
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
	
=back

=head1 DESCRIPTION

This script will run .

=cut

use strict;
use Config::IniFiles;
use FindBin;
require "$FindBin::Bin/mg_lib.pl";

use lib "/usr/local/devel/VIRIFX/software/VGD/lib";
use Getopt::Euclid 0.2.4 qw(:vars);

my $list = $ARGV_infile;
my $results_path = $ARGV_results_path;
my $queue = $ARGV_queue;
my $config = $ARGV_config;
my $grid_code = $ARGV_project_code;
my $service = $ARGV_service;

my $program_path = $0;
my @prog = split '/', $program_path;
my $program = pop @prog;
my $input_type = "HTAB";
my @files;

my $cfg;
if ($config) {
	$cfg = Config::IniFiles->new( -file => "$config" ) || die "cannot parse user suplied config file.\n";
}

my $fasta_split = "$FindBin::Bin/fasta_splitter.pl";
my $run_hmmscan = "$FindBin::Bin/run_hmmscan_etc.pl";

my $snapshot_dir;
my $hmmdb;
if ($cfg->val($service, 'snapshot_dir')) {
	$snapshot_dir = $cfg->val($service, 'snapshot_dir');
} #else {
	#$snapshot_dir = "/usr/local/projects/DB/MGX/mgx-prok-annotation/20101221";
#}
if ($cfg->val($service, 'hmmdb')) {
	$hmmdb = $cfg->val($service, 'hmmdb');
} #else {
	#$hmmdb = "/usr/local/projects/CAMERA/runtime-shared/filestore/system/Hmmer3Databases/1552815578744359083/ALL_LIB.HMM";
#}

@files = &read_list_file($list);

my $fasta_file =  "$results_path/all.fasta";
system "cat @files > $fasta_file";

my $cmd = "$fasta_split $fasta_file $results_path 500 no";
print "$cmd\n";
system $cmd;
my $list2 = "$results_path/partitions.list";

my @files2 = &read_list_file($list2);

my @JOBS;
my @parsed_files;
foreach my $file (@files2) {
	my @parts = split '/', $file;
	my $in_name = pop @parts;
	$in_name =~ s/.fasta//;
	my $count = $in_name;
	$count =~ s/fasta//;
	my $dir = "$results_path/partitions/$in_name";
	my $outfile = "$dir/hmm3_results.out";
	my $htab_file = $outfile . ".htab";
	my $parsed_file = "$htab_file.parsed";
	push @parsed_files, $parsed_file;
}

my $dir = "$results_path/partitions/fasta" . '$SGE_TASK_ID';

my $outfile = "$dir/hmm3_results.". '$SGE_TASK_ID' . ".out";
my $file = "$dir/fasta" . '$SGE_TASK_ID.fasta';

my $hmm3_cmd = "$run_hmmscan $file $dir $hmmdb $snapshot_dir";
if ($config) {
	$hmm3_cmd .= " $config";
}
print "$hmm3_cmd\n";

my $sh_script = write_shell_script($results_path,"${program}",$hmm3_cmd);

my $max_job_array = @files2;

my $job_id = launch_grid_job( $sh_script, $queue, $max_job_array, $results_path, $grid_code);
push @JOBS, $job_id;

print "waiting for jobs...\n";
wait_for_grid_jobs_arrays( \@JOBS,1,$max_job_array ) if ( scalar @JOBS );

print "All jobs complete.\n";

my $merged_htab =  "$results_path/hmm3_all.htab.parsed";
&cat_files(\@parsed_files, $merged_htab);

print "Merged hmm3 htab files to $merged_htab.\n";
