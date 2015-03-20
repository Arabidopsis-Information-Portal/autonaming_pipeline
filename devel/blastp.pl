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

my $list = $ARGV_infile;
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

my $cfg;
if ($config) {
	$cfg = Config::IniFiles->new( -file => "$config" ) || die "cannot parse user suplied config file.\n";
}

my $fasta_split = "$FindBin::Bin/fasta_splitter.pl";
my $run_blast = "$FindBin::Bin/run_blast_etc.pl";
my $uniref_annotation = "$FindBin::Bin/uniref_annotation_processing.pl";

my $snapshot_dir;
my $uniref;
if ($cfg->val($service, 'snapshot_dir')) {
	$snapshot_dir = $cfg->val($service, 'snapshot_dir');
} else {
#	$snapshot_dir = "/usr/local/projects/DB/MGX/mgx-prok-annotation/20101221";
}
if ($cfg->val($service, 'blast_db')) {
	$uniref = $cfg->val($service, 'blast_db');
} else {
#	$uniref = "/usr/local/projects/CAMERA/runtime-shared/filestore/system/BlastDatabases/1550565668133273887/";
}

my @blast_partitions = <${uniref}p*.fasta>;

@files = &read_list_file($list);
my $fasta_file =  "$results_path/all.fasta";
system "cat @files > $fasta_file";

my $cmd = "$fasta_split $fasta_file $results_path 10000 no no";
print "$cmd\n";
system $cmd;

my $list2 = "$results_path/partitions.list";

my @files2 = &read_list_file($list2);

my $max_job_array;
my @SINGLES;
my @JOBS;
my %results_hash;
foreach my $file (@files2) {
	my @results_files;
	$max_job_array = @blast_partitions;
	my @path = split '/', $file;
	my $q_file = pop @path;
	my $dir = $results_path . "/$q_file";
	mkdir $dir;
	foreach my $partition_file (@blast_partitions) {
		my @parts = split '/', $partition_file;
		my $db_name = pop @parts;
		$db_name =~ s/.fasta//;
		my $results_file = $dir . "/$db_name.results.xml";
		push @results_files, $results_file;
		if ($partition_file =~ /p_0.fasta/) {
			my $blast_cmd = "$run_blast $file $partition_file $dir/$db_name.results.xml"; 
			if ($config) {
				$blast_cmd .= " $config";
			}
			if ($service) {
				$blast_cmd .= " $service";
			}
			
			print "$blast_cmd\n";
			$max_job_array -= 1;
			my $sh_script = write_shell_script($dir,"${program}_$db_name",$blast_cmd);
			
			unless ($skip_blast) {
				my $job_id = launch_grid_job( $sh_script, $queue, 1, $dir, $grid_code);
				push @SINGLES, $job_id;
			}
		}
	}
	$results_hash{$dir} = \@results_files;

	my $blast_cmd = "$run_blast $file ${uniref}p_" . '$SGE_TASK_ID.fasta' . " $dir/p_" . '$SGE_TASK_ID.results.xml'; 

	if ($config) {
		$blast_cmd .= " $config";
	}
	if ($service) {
		$blast_cmd .= " $service";
	}

	print "$blast_cmd\n";

	my $sh_script = write_shell_script($dir,$program,$blast_cmd);
	
	unless ($skip_blast) {
		my $job_id = launch_grid_job( $sh_script, $queue, $max_job_array, $dir, $grid_code);
		push @JOBS, $job_id;
	}
}

unless ($skip_blast) {
	print "waiting for singles...\n";
	wait_for_grid_jobs_arrays( \@SINGLES,1,1 ) if ( scalar @SINGLES );
	print "waiting for arrays...\n";
	wait_for_grid_jobs_arrays( \@JOBS,1,$max_job_array ) if ( scalar @JOBS );

	print "All jobs complete.\n";
}

print "Running merge parse and other analyses.\n";

my @dirs = sort keys %results_hash;

my $dir_file = "$results_path/dir.list";
&write_list_file($dir_file,\@dirs);

my $anno_cmd = 	"$uniref_annotation --infile $dir_file --results_path $results_path --project_code $grid_code"; 
if ($config) {
	$anno_cmd .= " --config $config";
}
if ($queue) {
	$anno_cmd .= " --queue $queue";
}
if ($tag) {
	$anno_cmd .= " --project_tag $tag";
}
if ($service) {
	$anno_cmd .= " $service";
}
print "$anno_cmd\n";
system $anno_cmd;

print "Done processing Uniref annotations.\n";