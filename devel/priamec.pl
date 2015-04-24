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
   
=item [-]-service  <service>

service type to indicate where to look for optional parameter configurations

=for Euclid:
    service.type: string
       
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
use FindBin;
use Config::IniFiles;
require "$FindBin::Bin/pipeline_lib.pl";

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
my @files;

my $fasta_split = "$FindBin::Bin/fasta_splitter.pl";
my $run_priamec = "$FindBin::Bin/run_priamec_etc.pl";

my $cfg;
if ($config) {
	$cfg = Config::IniFiles->new( -file => "$config" ) || die "cannot parse user suplied config file.\n";
}
my $rules;
if ($cfg->val($service, 'rules_xml')) {
	$rules = $cfg->val($service, 'rules_xml');
} 

my @path = split /\//, $results_path;
pop @path;
my $rpsblast_dir =  join('/',@path) . "/priamrps_results";
my $rpsblast_list = "$rpsblast_dir/rpsblast.btab.list";

my @files2 = &read_list_file($rpsblast_list);

my @results_files;
foreach my $file (@files2) {
	my $dir = "$results_path/";
	my @path = split /\//, $file;
	pop @path;
	my $fasta = pop @path;
	$fasta =~ s/\.fasta//;
	my $count = $fasta;
	$count =~ s/fasta//;
	my $fasta_file = "$rpsblast_dir/partitions/$fasta/$fasta.fasta";
	my $new_fasta = "$dir/$fasta.fasta";
	my $btab_file = "$dir/priamrps.btab.$count.btab";
	system ("cp $file $btab_file");
	system ("cp $fasta_file $new_fasta");
	my $btab_bsml_file = "$dir/priamrps.btab.$count.bsml";
	my $outfile = "$dir/priamec_results.$count.bsml";

	push @results_files, $outfile;
}

my @JOBS;

my $dir = "$results_path/";
my $btab = "$dir/priam.btab." . '$SGE_TASK_ID.btab';
my $fasta = "$dir/fasta" . '$SGE_TASK_ID.fasta';
my $bsml = "$dir/priam.btab." . '$SGE_TASK_ID.bsml';
my $outfile = "$dir/priamec_results." . '$SGE_TASK_ID.bsml';

my $run_cmd = "$run_priamec $dir $btab $fasta $bsml $outfile $rules";
if ($config) {
	$run_cmd .= " $config";
}
print "$run_cmd\n";

my $sh_script = write_shell_script($results_path,"${program}",$run_cmd);

my $max_job_array = @files2;

#my $job_id = launch_grid_job( $sh_script, $queue, $max_job_array, $results_path, $grid_code);
#push @JOBS, $job_id;

#print "waiting for jobs...\n";
#wait_for_grid_jobs_arrays( \@JOBS,1,$max_job_array ) if ( scalar @JOBS );

print "All jobs complete.\n";

my $combined = "$results_path/priam_ec_assignment.bsml.list";
&write_list_file($combined, \@results_files);

print "Wrote $service results list to $combined.\n";
