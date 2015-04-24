#!/usr/local/bin/perl

use strict;
use Config::IniFiles;
use FindBin;
require "$FindBin::Bin/pipeline_lib.pl";

&print_time("STARTTIME");

my $results_path = $ARGV[0];
my $btab_file = $ARGV[1];
my $fasta = $ARGV[2];
my $bsml_file = $ARGV[3];
my $outfile = $ARGV[4];
my $rules = $ARGV[5];
my $config = $ARGV[6];


my $program_path = $0;
my @prog = split '/', $program_path;
my $program = pop @prog;

my $cfg;
if ($config) {
	$cfg = Config::IniFiles->new( -file => "$config" ) || die "cannot parse user suplied config file.\n";
}
my $path = &get_lib_path($cfg);

#use lib "/usr/local/devel/VIRIFX/software/VGD/lib";
#use Getopt::Euclid 0.2.4 qw(:vars);

my $btab = "$FindBin::Bin/blastbtab2bsml.pl";
my $bsml = "$FindBin::Bin/assign_ec_from_rps.pl";
my $shell_config = "$FindBin::Bin/etc/shell.config";
my $shell_template = &write_shell_template($shell_config,$path,$results_path);

my $btab_cmd = "$btab -c class -f $btab_file -o $bsml_file -q $fasta";
print "$btab_cmd\n";
my $program = &get_file_name($btab);
&run_shell_script($btab_cmd,$shell_template,$program,$results_path);
	
my $bsml_cmd = "$bsml -i $bsml_file -r $rules -o $outfile";
print "$2bsml_cmd\n";
my $program = &get_file_name($bsml);
&run_shell_script($bsml_cmd,$shell_template,$program,$results_path);

&print_time("ENDTIME");
