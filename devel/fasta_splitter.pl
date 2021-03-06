#!/usr/local/bin/perl

use strict;
use Bio::SeqIO;
use FindBin;
require "$FindBin::Bin/pipeline_lib.pl";


#use lib "/usr/local/devel/VIRIFX/software/VGD/lib";
#use Getopt::Euclid 0.2.4 qw(:vars);

my $file = $ARGV[0];
my $results_path = $ARGV[1];
my $enteriesPerFasta = $ARGV[2];
my $padding = $ARGV[3];
my $def_line = $ARGV[4];

if (!$enteriesPerFasta) {
	$enteriesPerFasta = 10000;
}

my $in = Bio::SeqIO->new(-file => "$file");

my $count = `grep ">" $file -c`;
chomp $count;

my $splits = $count/$enteriesPerFasta;
unless (($count%$enteriesPerFasta) == 0 ) {
	$splits = int($splits) + 1;
}
print "C: $count\nP: $splits\n";

mkdir "$results_path/partitions";

my @oseqs;
for (my $i = 1; $i <= $splits; $i ++) {
	my $pad = length($splits);
	my $num;
	if ($padding) {
		$num = $i;
	} else {
		$num = sprintf("%0${pad}d",$i);
	}
	my $dir = "$results_path/partitions/fasta" . $num;
	mkdir $dir;
	my $outfile = "$dir/fasta$num.fasta";
	push @oseqs, $outfile;
}

my $seq_count = 0;
my $file_count = 0;

my $oseq = Bio::SeqIO->new(-file => ">$oseqs[0]", -format => "fasta");

while (my $seq = $in->next_seq()) {
	if ($def_line) {
		 $seq->desc(undef);
	}
	$oseq->write_seq($seq);
	$seq_count ++;
	if ($seq_count == $enteriesPerFasta  && $oseqs[($file_count + 1)]) {
		$file_count ++;
		$seq_count = 0;
		$oseq = Bio::SeqIO->new(-file => ">$oseqs[$file_count]", -format => "fasta");
	}
}
my $list_file = "$results_path/partitions.list";
write_list_file($list_file, \@oseqs);