#!/usr/bin/perl
#
#################################################################################
#                               map_expression.pl								#
#################################################################################

#================================================================================
#        Copyright (C) 2014 - Sergio CASTILLO
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#================================================================================

use warnings;
use strict;
use Data::Dumper;
use Color::Spectrum::Multi;


#================================================================================
# VARIABLES
#================================================================================
my $expression_file = shift @ARGV;


#================================================================================
# MAIN LOOP
#================================================================================

my $exp_info    = expression($expression_file);
my @sorted_nodes = sort {
	$exp_info->{$a} <=> $exp_info->{$b}
} keys %{ $exp_info };


my %nodes_2_color = ();
my $spect = Color::Spectrum::Multi->new();
my @color = $spect->generate(scalar(@sorted_nodes), "#FF0000", "#00FF00");

foreach my $i (0..$#sorted_nodes) {
	$nodes_2_color{$sorted_nodes[$i]} = $color[$i];
}

print Dumper(\%nodes_2_color);

#================================================================================
# FUNCTIONS
#================================================================================

#--------------------------------------------------------------------------------
sub expression {
	my $filename = shift;
	my %exp_info    = ();

	open my $fh, '<', $filename
		or die "Can't open $filename :$!\n";

	while (<$fh>) {
		chomp;
		my ($node, $value) = split /\t/, $_;
		$exp_info{$node} = int($value);
	}

	return \%exp_info;
}

