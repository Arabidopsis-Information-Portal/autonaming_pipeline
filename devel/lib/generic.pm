use Exporter 'import';
@EXPORT_OK = qw(rpad);
use strict;
use warnings;

our $errorMessage;

###################################################################
# generic utilities
###################################################################
#
# extract values from hash and return as array
sub extractArrayFromHash{

	my ( $inhash, $keys ) = @_;
	
	my @outarray = ();
	for my $key ( @$keys ) {
		if ( defined $inhash->{$key} ) {
			push(@outarray,$inhash->{$key});
		} else {
			push(@outarray,undef);
		}
	}
	return \@outarray;
}

sub extractHashFromArray{

	my ( $inarray, $keys ) = @_;
	
	my %outhash;
	for my $i ( 0 .. @$keys-1 ) {
		if ( defined $$keys[$i] ) {
			$outhash{$$keys[$i]} = $$inarray[$i];
		}
	}
	
	return \%outhash;
}

#
# convert an array of hashes to a hash of hashes
sub arrayHashToHashHash {
	my ( $array, $key ) = @_;
	$errorMessage = undef;
	
	if ( !defined $array ) {
		$errorMessage = "ArrayHashToHashHash: input array is undefined";
		return undef
	};
	
	if ( !defined $key ) {
		$errorMessage = "ArrayHashToHashHash: key is undefined";
		return undef
	};
		
	my %hash;
	foreach my $item ( @$array ) {
		if ( !defined $$item{$key} ) {
			$errorMessage = "ArrayHashToHashHash: keyless item";
			return undef;
		}
		$hash{ $$item{$key} } = $item;
	}

	return \%hash;
}

# display hash data
sub print_hash {
	my ( $hashname, $hash ) = @_;

	our %hashes;

	#if ( exists $hashes{$hashname} ) { return }
	$hashes{$hashname} = $hash;

	print "\n$hashname\n";
	for my $hashkey ( sort keys %$hash ) {
		if ( !defined $$hash{$hashkey} ) {
			print "$hashkey=\n";
			next;
		}
		my $hashval = "$$hash{$hashkey}";
		if ( $hashval =~ /HASH/ ) {
			print_hash( "$hashname.$hashkey", $$hash{$hashkey} );
		}
		elsif ( $hashval =~ /ARRAY/ ) {
			for my $element ( @{ $$hash{$hashkey} } ) {
				if ( "$element" =~ /HASH/ ) {
					print_hash( "$hashname.$hashkey.element", $element );
				}
				else {
					print "$hashname=>ARRAY: $$hash{$hashkey}\n";
				}
				last;
			}
		}
		else {
			print "$hashkey=$hashval\n";
		}
	}
	return;
}

# find element in array with matching value
sub findArrayValue {
	my ( $value, $array ) = @_;
	
	foreach my $i ( 0..scalar @$array -1 ) {
		if ( $$array[$i] eq $value ) { return $i }
	}
	return -1;
}

sub sqr {
	my ( $a ) = @_;
	
	return $a * $a;
}

#
# right pad string to fixed length
sub rpad {
	my ( $text, $pad_len, $pad_char) = @_;

	if ( !defined $pad_char ) {
		$pad_char = " ";
	} elsif ( length($pad_char)>1 ) {
		$pad_char = substr($pad_char,0,1);
	}

    $text = $pad_char unless defined $text;
	
	if ( $pad_len<=0 ) {
		return "";
	} elsif ( $pad_len<=length($text) ) {
		return substr($text,0,$pad_len);
	}

	if ( $pad_len>length($text) ) {
		$text .= $pad_char x ( $pad_len - length( $text ) );
	}
	
	return "$text"; 
}

#
# left pad string to fixed length
sub lpad {
	my ( $text, $pad_len, $pad_char) = @_;

	if ( !defined $pad_char ) {
		$pad_char = " ";
	} elsif ( length($pad_char)>1 ) {
		$pad_char = substr($pad_char,0,1);
	}

    $text = $pad_char unless defined $text;

	if ( $pad_len<=0 ) {
		return "";
	} elsif ( $pad_len<length($text) ) {
		return substr($text,0,$pad_len);
	}

	if ( $pad_len>length($text) ) {
		$text = $pad_char x ( $pad_len - length( $text ) ). $text;
	}
	
	return "$text"; 
}

#
# center string in fixed length
sub cpad {
	my ( $text, $pad_len, $pad_char) = @_;

	if ( !defined $pad_char ) {
		$pad_char = " ";
	} elsif ( length($pad_char)>1 ) {
		$pad_char = substr($pad_char,0,1);
	}

    $text = $pad_char unless defined $text;
	
	if ( $pad_len<=0 ) {
		return "";
	} elsif ( $pad_len<length($text) ) {
		return substr($text,0,$pad_len);
	}

	my $margin = int( ( $pad_len - length($text) ) / 2. );
	if ( $margin>0 ) {
		$text = &lpad($pad_char,$margin,$pad_char) . $text;
	}

	$margin = $pad_len - length($text);
	if ( $margin>0 ) {
		$text .= &rpad($pad_char,$margin,$pad_char);
	}

	return "$text"; 
}

#
# return current date and time YYYY-MM-DD:HH:MI:SS
sub now {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	
	$sec = &lpad($sec,2,"0");
	$min = &lpad($min,2,"0");
	$hour = &lpad($hour,2,"0");
	$mday = &lpad($mday,2,"0");
	$mon = &lpad($mon+1,2,"0");
	$year = &lpad($year+1900,4,"0");
	my $now = "$year-$mon-$mday $hour:$min:$sec";
	return $now;
}

#
# return current date YYYY-MM-DD
sub today {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	
	$mday = &lpad($mday,2,"0");
	$mon = &lpad($mon+1,2,"0");
	$year = &lpad($year+1900,4,"0");
	$year+=100;
	my $today = "$year-$mon-$mday";
	return $today;
}

sub maxval {
	my @values = @_;
	if ( ! @values ) { return undef }
	
	my $max = $values[0];
	for my $i ( 1..@values-1 ) {
		if ( $values[$i] > $max ) { $max = $values[$i] }
	}
	
	return $max;
}

sub minval {
	my @values = @_;
	if ( ! @values ) { return undef }
	
	my $min = $values[0];
	for my $i ( 1..@values-1 ) {
		if ( $values[$i] < $min ) { $min = $values[$i] }
	}
	
	return $min;
}

sub sign {
	my ( $val ) = @_;
	
	if ( $val < 0.0 ) { return -1 }
	elsif ( $val > 0.0 ) { return 1 }
	else { return 0 }
}

sub remove_undefs {
	my @inarray = @_;
	
	my @outarray;
	for my $element ( @inarray ) {
		if ( defined $element ) { push @outarray, $element }
	}
	
	return @outarray;
}


sub format_decimal {
	my ( $value, $isize, $dsize ) = @_;

	my ( $i, $d ) = split /\./, $value;
	if ( $value =~ /E/i ) {
		$i = "0";
		$d = "0";
	}
	if ( ! defined $i ) { $i = "0" }
	if ( ! defined $d ) { $d = "0" }

	if ( length( $i ) > $isize ) { $i = lpad( "*", $isize, "*" ) }
	else { $i = lpad( $i, $isize ) }

	$d = rpad( $d, $dsize, "0" );
	
	return "$i.$d";
}

sub format_decimal1 {
	my ( $inval ) = @_;
	
	my $outval = int( 10.0 * $inval + 0.5 ) / 10.0;
	if ( $outval !~ /\./ ) { $outval .= ".0" }
	
	return $outval;
}

1;
