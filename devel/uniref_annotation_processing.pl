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
my $tag = $ARGV_project_tag;
my $service = $ARGV_service;

my $program_path = $0;
my @prog = split '/', $program_path;
my $program = pop @prog;
my @files;

&print_time("STARTTIME");

my $cfg;
if ($config) {
	$cfg = Config::IniFiles->new( -file => "$config" ) || die "cannot parse user suplied config file.\n";
}

my $fasta_split = "$FindBin::Bin/fasta_splitter.pl";
my $run_blast = "$FindBin::Bin/run_blast_etc.pl";
my $merge_and_parse = "$FindBin::Bin/uniref_merge_and_parse.pl";
#my $pro_taxa = "$FindBin::Bin/process_taxa_summaries.pl";
#my $pro_anno = "$FindBin::Bin/process_annotation_summaries.pl";

my $snapshot_dir;
my $uniref;
if ($cfg->val($service, 'snapshot_dir')) {
	$snapshot_dir = $cfg->val('UNIREF', 'snapshot_dir');
}# else {
#	$snapshot_dir = "/usr/local/projects/DB/MGX/mgx-prok-annotation/20101221";
#}
if ($cfg->val($service, 'blast_db')) {
	$uniref = $cfg->val('UNIREF', 'blast_db');
}# else {
#	$uniref = "/usr/local/projects/CAMERA/runtime-shared/filestore/system/BlastDatabases/1550565668133273887/";
#}

@files = &read_list_file($list);

print "Converting to btab.\n";
my @parsed_files;
my @taxa_files;
my @tax_anno_files;
my @SINGLES;
foreach my $dir (@files) {
	my $sort_prog = "uniref_merge_and_parse.pl";
	my $sorted_file = "$dir/sorted_uniref_results.btab";
	my $parsed_file = "$dir/sorted_uniref_results.btab.parsed";
	my $perc_id_file = "$sorted_file.perc_id";
	my $taxa_id_file = "$perc_id_file.taxa_id";
	my $taxa_file = "$dir/taxa_summary.tsv";
	my $sort_cmd = "$merge_and_parse $sorted_file $dir $snapshot_dir";
	if ($config) {
		$sort_cmd .= " $config";
	}
	my $sh_script = write_shell_script($dir,$sort_prog,$sort_cmd);
	print "$sort_cmd\n";

	my $job_id = launch_grid_job( $sh_script, $queue, 1, $dir, $grid_code);
	push @SINGLES, $job_id;

	push @parsed_files, $parsed_file;
	push @taxa_files, $taxa_file;
	push @tax_anno_files, $taxa_id_file;
}
print "waiting for grid jobs...\n";
wait_for_grid_jobs_arrays( \@SINGLES,1,1 ) if ( scalar @SINGLES );

print "Done converting to btab and parsing\n";

my $final_btab = "$results_path/uniref_blastp_btab.combined.out.parsed";
&cat_files(\@parsed_files, $final_btab);

my $final_taxa = "$results_path/sample_taxa_summary.tsv";
&cat_files(\@taxa_files, $final_taxa);

my $final_tax_anno = "$results_path/sample_annotation_summary.tsv";
&cat_files(\@tax_anno_files, $final_tax_anno);

print "Done merging all parsed btab and annotation files.\n";

print "Generating annotation and taxa summary tables.\n";

#my $cmd = "$pro_taxa $final_taxa $results_path $config $tag";
#print "$cmd\n";
#system $cmd;

#my $cmd = "$pro_anno $final_tax_anno $results_path $config $tag";
#print "$cmd\n";
#system $cmd;

print "Done generating annotation and taxa summary tables.\n";
