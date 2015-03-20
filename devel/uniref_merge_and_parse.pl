#!/usr/local/bin/perl

use strict;
use Config::IniFiles;
use FindBin;
require "$FindBin::Bin/pipeline_lib.pl";

&print_time("STARTTIME");

my $file = $ARGV[0];
my $results_path = $ARGV[1];
my $snapshot_dir = $ARGV[2];
my $config = $ARGV[3];

my $program_path = $0;
my @prog = split '/', $program_path;
my $program = pop @prog;
my $input_type = "BTAB";

my $cfg;
if ($config) {
	$cfg = Config::IniFiles->new( -file => "$config" ) || die "cannot parse user suplied config file.\n";
}
my $path = &get_lib_path($cfg);

#use lib "/usr/local/devel/VIRIFX/software/VGD/lib";
#use Getopt::Euclid 0.2.4 qw(:vars);

my $btab_sort = "/usr/local/devel/VIRIFX/software/Staging/Elvira/bin/mergeAndSortBlastXml2Btab";
my $parser = "$FindBin::Bin/camera_parse_annotation_results_to_text_table.pl";
my $estimate = "$FindBin::Bin/run_estimate_taxa.pl";
my $shell_config = "$FindBin::Bin/etc/shell.config";
my $shell_template = &write_shell_template($shell_config,$path,$results_path);

my $gunzip = "gunzip $results_path/*.gz";
system "$gunzip";

my $sort_prog = "mergeAndSortBlastXml2Btab";
my $sorted_file = "$results_path/sorted_uniref_results.btab";
my $sort_cmd = "$btab_sort -in $results_path -out $sorted_file";
print "$sort_cmd\n";
system $sort_cmd;

my $parsed_file = &run_parser_script($shell_template,$results_path,$sorted_file,$parser,$snapshot_dir,$input_type);

my $est_cmd = "$estimate $file $results_path $snapshot_dir";
if ($config) {
	$est_cmd .= " $config";
}
print "$est_cmd\n";
system $est_cmd;

my @xmls = <$results_path/*.xml>;
foreach my $xml_file (@xmls) {
	my $cmd = "gzip $xml_file";
	system $cmd;
}

&print_time("ENDTIME");
