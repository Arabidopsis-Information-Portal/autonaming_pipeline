#!/usr/local/bin/perl

use strict;
use Config::IniFiles;
use FindBin;
require "$FindBin::Bin/pipeline_lib.pl";

&print_time("STARTTIME");

my $file = $ARGV[0];
my $results_path = $ARGV[1];
my $hmmdb = $ARGV[2];
my $snapshot_dir = $ARGV[3];
my $config = $ARGV[4];

my $program_path = $0;
my @prog = split '/', $program_path;
my $program = pop @prog;
my $input_type = "HTAB";
my @files;

my $cfg;
if ($config) {
	$cfg = Config::IniFiles->new( -file => "$config" ) || die "cannot parse user suplied config file.\n";
}
my $path = &get_lib_path($cfg);

#use lib "/usr/local/devel/VIRIFX/software/VGD/lib";
#use Getopt::Euclid 0.2.4 qw(:vars);
my $hmm3 = "/usr/local/packages/hmmer-3.0/bin/hmmscan";
my $htab = "$FindBin::Bin/htab.pl";
my $htabdb;
if ($snapshot_dir =~ /.*db$/) {
	$htabdb = $snapshot_dir;
	my @path = split /\//, $snapshot_dir;
	my $last = pop @path;
	$snapshot_dir =~ s/$last//;
} else {
	$htabdb = "$snapshot_dir/hmm3.db";
}
my $parser = "$FindBin::Bin/camera_parse_annotation_results_to_text_table.pl";
my $shell_config = "$FindBin::Bin/etc/shell.config";
my $shell_template = &write_shell_template($shell_config,$path,$results_path);

my $outfile = "$results_path/hmm3_results.out";

my $hmm3_cmd = "$hmm3 --cut_tc -o $outfile $hmmdb $file";
print "$hmm3_cmd\n";
system($hmm3_cmd);

my $htab_file = "$outfile.htab";
my $htab_cmd = "cat $outfile | $htab -d $htabdb > $htab_file";
print "$htab_cmd\n";
system($htab_cmd);

my $parsed_file = &run_parser_script($shell_template,$results_path,$htab_file,$parser,$snapshot_dir,$input_type);

&print_time("ENDTIME");