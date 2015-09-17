#!/usr/local/bin/perl

use strict;

my $file1 = $ARGV[0];
my $file2 = $ARGV[1];

my %names_data;
my %text;

open (FILE1, $file1) || die "Cannot open $file1. $!";

while (<FILE1>) {
	chomp $_;

	my @line = split /\t/, $_;
	$text{$line[0]} = \@line;
	if ($line[0] =~ /AT.G.*\.[0-9]*$/) {
		my @ver = split /\./, $line[0]; #//
		#print "@ver\n";
		$names_data{$ver[0]}->{$ver[1]} = $line[1];
	} else {
		$names_data{$line[0]}->{"NULL"} = $line[1];
	}
}
close FILE1;

open (FILE2, $file2) || die "Cannot open $file2. $!";

my %loci_names;

while (<FILE2>) {
	chomp $_;

	my @line = split /\t/, $_;

	my $loci = $line[0];
	my $name = $line[1];

	$loci_names{$loci} = $name;
}
close FILE2;

my $out_file = "name_changes.log";
open (OUT, ">$out_file") || die "Cannot open $out_file. $!\n";

foreach my $gene (sort keys %names_data) {
	my @versions = sort keys $names_data{$gene};
	my $iso_id;
	if ($loci_names{$gene}) {
		&update_names($gene, \@versions);
	}
	if ($versions[0] eq "NULL") {
		$iso_id = "$gene";
		print join("\t",@{$text{$iso_id}}) . "\n";
	} else {
		foreach my $ver (@versions) {
			$iso_id = "$gene.$ver";
			print join("\t",@{$text{$iso_id}}) . "\n";
		}
	}
}
close OUT;

sub update_names {
	my $acc = shift;
	my $isoforms = shift;
	
	my $new_name = $loci_names{$acc};
	
#	print OUT "LONGEST CDS FOR $acc IS $longest_isos{$acc}->{'isoform'}, NAME IS '$longest_cds_name'.\n";
	
	for (my $i = 0; $i < @$isoforms; $i ++) {
		my $isoform = "$acc.$$isoforms[$i]";
		my $this_cds_name = $text{$isoform}[1];
		$text{$isoform}[1] = $new_name;
		print OUT "CHANGING $isoform NAME '$this_cds_name' TO '$new_name'\n";
	}
}

sub extract_loci {
	my $id = shift;
	
	if ($id =~ /^AT.G/) {
		my @parts = split /\./, $id; #//
		my $loci = $parts[0];
	
		return $loci;
	} else {
		return $id;
	}
}