#!/usr/local/bin/perl

use strict;

my $file1 = $ARGV[0];

my %names_data;

open (FILE1, $file1) || die "Cannot open $file1. $!";

while (<FILE1>) {
	chomp $_;

	my @line = split /\t/, $_;
	if ($line[0] =~ /\.[0-9]*$/) {
		my @ver = split /\./, $line[0]; #//
		$names_data{$ver[0]}->{$ver[1]} = $line[1];
	}
}
close FILE1;

foreach my $gene (keys %names_data) {
	my @versions = sort keys $names_data{$gene};
	if (@versions > 1) {
		&check_names($gene,\@versions);
#		print "$gene\t" . @versions . "\n";
	} 
	if ($versions[0] != 1) {
		#print "$gene.$versions[0]\n";
	}
}


sub check_names {
	my $acc = shift;
	my $isoforms = shift;
	
	my $mismatches = 0;
	my $ver1_name = $names_data{$acc}->{$$isoforms[0]};
	for (my $i = 1; $i < @$isoforms; $i ++) {
		if ($ver1_name ne $names_data{$acc}->{$$isoforms[$i]}) {
			print "$acc.$$isoforms[0]\t$acc.$$isoforms[$i]\t$ver1_name\t$names_data{$acc}->{$$isoforms[$i]}\n";
			$mismatches ++;
		}
	}
	if ($mismatches) {
		#print "$acc\n";
	}
}