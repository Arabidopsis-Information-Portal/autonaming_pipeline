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
my $service = $ARGV[4];

my $program_path = $0;
my @prog = split '/', $program_path;
my $program = pop @prog;
my $input_type = "BTAB";

my $cfg;
if ($config) {
	$cfg = Config::IniFiles->new( -file => "$config" ) || die "cannot parse user suplied config file.\n";
}
my $path = &get_lib_path($cfg,$service);

my $max_hits = 10;
if ($cfg->val($service, 'max_hits')) {
	$max_hits = $cfg->val($service, 'max_hits');
}

#use lib "/usr/local/devel/VIRIFX/software/VGD/lib";
#use Getopt::Euclid 0.2.4 qw(:vars);

my $btab_sort = "/usr/local/devel/VIRIFX/software/Staging/Elvira/bin/mergeAndSortBlastXml2Btab";
my $parser = "$FindBin::Bin/camera_parse_annotation_results_to_text_table.pl";
my $shell_config = "$FindBin::Bin/etc/shell.config";
my $shell_template = &write_shell_template($shell_config,$path,$results_path);

my $gunzip = "gunzip $results_path/*.gz";
system "$gunzip";

my $sort_prog = "mergeAndSortBlastXml2Btab";
my $sorted_file = "$results_path/sorted_uniref_results.btab";
if ($service =~ /rpsblast/) {
	$sorted_file = "$results_path/sorted_rps_results.btab";
}
my $sort_cmd = "$btab_sort -in $results_path -out $sorted_file -max_hits $max_hits";
print "$sort_cmd\n";
system $sort_cmd;

my @xmls = <$results_path/*.xml>;
foreach my $xml_file (@xmls) {
	my $cmd = "gzip $xml_file";
	system $cmd;
}

&print_time("ENDTIME");
