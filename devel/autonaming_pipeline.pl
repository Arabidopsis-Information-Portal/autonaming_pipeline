#!/usr/local/bin/perl

=head1 NAME
    
    autonaming_pipeline.pl
    
=head1 USAGE

    autonaming_pipeline.pl [-]-results_path <results_path> [-]-infile <infile> [-]-project_code <project_code>

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

This script will run a stand alone version of the eukaryotic autonaming pipeline.

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

my $services_config = "$FindBin::Bin/etc/services.config";
my %EXECS = get_services($services_config, $results_path);

my $cfg;
my @order;
if ($config) {
	$cfg = Config::IniFiles->new( -file => "$config" ) || die "cannot parse user suplied config file.\n";
	@order = $cfg->Sections();
	print "@order\n";
	foreach my $service (@order) {
		unless ($EXECS{$service}) {
			die "$service is not a defined pipeline service, check $config for errors.\n";
		}
	}
}
	
foreach my $prog (keys %EXECS) {
	print "$prog\t$EXECS{$prog}->{'cmd'}\n";
}

my $results_list = "$results_path/evidence_service_results.list";
open (RES_LIST, ">$results_list") || die "cannot open $results_list. $!\n"; 
foreach my $dir (@order) {
	print "Running $dir service...\n";
	&print_time("$dir STARTTIME");
	mkdir "$EXECS{$dir}->{'dir'}";
	my $cmd = $EXECS{$dir}->{'cmd'} . " -infile $list -results_path $EXECS{$dir}->{'dir'} -project_code $grid_code -service $dir";
	if ($queue) {
		$cmd .= " -queue $queue";
	}
	if ($config) {
		$cmd .= " -config $config";
	}
	if ($tag && $dir eq "UNIREF") {
		$cmd .= " -project_tag $tag";
	}

	print "$cmd\n";
	system $cmd;

	my @list = `ls $EXECS{$dir}->{'dir'}/*.list`;
	foreach my $item (@list) {
		chomp $item;
		print RES_LIST "\n";
	}

	&print_time("$dir ENDTIME");
	print "Done with $dir service.\n";
}
close RES_LIST;

#print "Running RULES service...\n";
#&print_time("RULES STARTTIME");
#mkdir "$dirs{RULES}";
#my $cmd = $EXECS{RULES} . " -infile $results_list -results_path $dirs{RULES} -project_code $grid_code";
#if ($queue) {
#	$cmd .= " -queue $queue";
#}
#if ($config) {
#	$cmd .= " -config $config";
#}
#print "$cmd\n";
#system $cmd;
#&print_time("RULES ENDTIME");
#print "Done with RULES service.\n";