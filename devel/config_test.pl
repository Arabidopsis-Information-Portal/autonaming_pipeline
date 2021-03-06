#!/usr/local/bin/perl

use strict;
use Config::IniFiles;
use FindBin;
require "$FindBin::Bin/pipeline_lib.pl";

my $list = $ARGV[0];
my $results_path = $ARGV[1];
my $queue = $ARGV[2];
my $config = $ARGV[3];
my $blast_type = "blastp";
my $cfg;
if ($config) {
	$cfg = Config::IniFiles->new( -file => "$config" ) || die "cannot parse user suplied config file.\n";
}

my $uniref_config = "$FindBin::Bin/etc/uniref.config";
my $blastp_params = parse_params_config($uniref_config);
my $params_string = write_params_string($blastp_params);
my $blast = "/usr/local/bin/blastall";

&print_time("STARTTIME");
my $blast_cmd = "$blast -p $blast_type -d test_db.file -i test_in.file -o test_out.file" . "$params_string";
print "$blast_cmd\n";

if ($cfg->SectionExists('ncbi-blastp.uniref')) {
	my @parameters = $cfg->Parameters('UNIREF');
	print "@parameters\n";
	foreach my $param (@parameters) {
		if ($$blastp_params{$param}) {
			$$blastp_params{$param}->{"value"} = $cfg->val('UNIREF', $param);
		}
	}
	if ($cfg->val('ncbi-blastp.uniref', 'blastprog')) {
		$blast_type = $cfg->val('ncbi-blastp.uniref', 'blastprog');
	}
}

my $params_string = write_params_string($blastp_params);
my $blast_cmd = "$blast -p $blast_type -d test_db.file -i test_in.file -o test_out.file" . "$params_string";
print "$blast_cmd\n";
&print_time("ENDTIME");

my $services_config = "$FindBin::Bin/etc/services.config";

my %EXECS = get_services($services_config, $results_path);

foreach my $cmd (keys %EXECS) {
	print "$cmd\t$EXECS{$cmd}->{'cmd'}\t$EXECS{$cmd}->{'dir'}\n"
}