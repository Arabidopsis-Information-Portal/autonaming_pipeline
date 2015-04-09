#!/usr/local/bin/perl

use strict;
use Config::IniFiles;
use FindBin;
require "$FindBin::Bin/pipeline_lib.pl";

&print_time("STARTTIME");

my $file = $ARGV[0];
my $results_path = $ARGV[1];
my $config = $ARGV[2];

my $program_path = $0;
my @prog = split '/', $program_path;
my $program = pop @prog;
my $input_type = "LipoproteinMotifBSML";
my @files;

my $cfg;
if ($config) {
	$cfg = Config::IniFiles->new( -file => "$config" ) || die "cannot parse user suplied config file.\n";
}
my $path = &get_lib_path($cfg);

my $id_rep = "$results_path/id_repository";
system("touch $id_rep");

#use lib "/usr/local/devel/VIRIFX/software/VGD/lib";
#use Getopt::Euclid 0.2.4 qw(:vars);

my $lipo = "$FindBin::Bin/lipoprotein_motif.pl";
my $parser = "$FindBin::Bin/camera_parse_annotation_results_to_text_table.pl";
my $shell_config = "$FindBin::Bin/etc/shell.config";
my $shell_template = &write_shell_template($shell_config,$path,$results_path);

my $in_name = &get_file_name($file);
$in_name =~ s/.fasta//;
my $outfile = "$results_path/lipo_results.$in_name.bsml";

my $lipo_cmd = "perl $lipo --input $file -output $outfile -gzip_output 0 -is_mycoplasm 0 -id_repository $id_rep";
print "$lipo_cmd\n";
my $program = &get_file_name($lipo);
&run_shell_script($lipo_cmd,$shell_template,$program,$results_path);

#my $parsed_file = &run_parser_script($shell_template,$results_path,$outfile,$parser,$results_path,$input_type);
#my $sed_cmd = "sed 's/__\t/_+\t/' $parsed_file -i";
#print "$sed_cmd\n";
#system($sed_cmd);

&print_time("ENDTIME");