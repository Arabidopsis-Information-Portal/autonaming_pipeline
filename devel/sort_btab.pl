#!/usr/local/bin/perl

use strict;

my $file = $ARGV[0];
my @path = split '/', $file;
my $f_name = pop @path;
my $dir = join('/', @path);
my $outfile = "$dir/sorted_$f_name";

open (IN, "$file") || die "cannot open $file. $!\n";

my %results;

while (<IN>) {
	chomp $_;
	my @line = split "\t", $_;
	push @{$results{$line[0]}}, $_;
}

close IN;

open (OUT, ">$outfile") || die "cannot open $outfile. $!\n";

foreach my $qs (sort { $a cmp $b } keys %results) {
	my $array = sort_array_by_evalue(\@{$results{$qs}});
	my $count = 0;
	foreach my $row (@$array) {
		if ($count < 10) {
			print OUT "$row\n";
			$count ++;
		}
	}
}

close OUT;

sub sort_array_by_evalue {
	my $array = shift;
	my @sortedarray = sort { (split '\t', $a)[19] <=> (split '\t', $b)[19] } @$array;
	return \@sortedarray;
}