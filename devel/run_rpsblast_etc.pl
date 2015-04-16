#!/usr/local/bin/perl

use strict;
use Config::IniFiles;
use FindBin;
require "$FindBin::Bin/pipeline_lib.pl";

&print_time("STARTTIME");

my $file = $ARGV[0];
my $partition_file = $ARGV[1];
my $output_file = $ARGV[2];
my $config = $ARGV[3];
my $service = $ARGV[4];

my $program_path = $0;
my @prog = split '/', $program_path;
my $program = pop @prog;
my $input_type = "BTAB";
my $blast_type = "rpsblast";

my $cfg;
if ($config) {
	$cfg = Config::IniFiles->new( -file => "$config" ) || die "cannot parse user suplied config file.\n";
}
my $path = &get_lib_path($cfg,$service);

my @files;

#use lib "/usr/local/devel/VIRIFX/software/VGD/lib";
#use Getopt::Euclid 0.2.4 qw(:vars);

my $blast = "/usr/local/bin/rpsblast";
my $uniref_config = "$FindBin::Bin/etc/rpsblast.config";
my $blastp_params = parse_params_config($uniref_config);
if ($config) {
	if ($cfg->SectionExists($service)) {
		my @parameters = $cfg->Parameters($service);
		print "@parameters\n";
		foreach my $param (@parameters) {
			if ($$blastp_params{$param}) {
				$$blastp_params{$param}->{"value"} = $cfg->val($service, $param);
			}
		}
		if ($cfg->val($service, 'blastprog')) {
			$blast_type = $cfg->val($service, 'blastprog');
		}
	}
}
my $params_string = write_params_string($blastp_params);

my $blast_cmd = "$blast -d $partition_file -i $file -o $output_file" . "$params_string";
print "$blast_cmd\n";
system $blast_cmd;

&print_time("ENDTIME");
