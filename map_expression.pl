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
use Getopt::Long;
use CGI;

#================================================================================
# VARIABLES
#================================================================================
my $expression_file;
my $svg_filename;
my $debug;
my $help;
my $html;
my $color_number = 20;
	# Default

GetOptions(
	'colornum=i' => \$color_number,
    'exp=s'    => \$expression_file,
    'svg=s'    => \$svg_filename,
    'html=s'   => \$html,
    'debug'    => \$debug,
    'help'     => \$help
);

help() if ($help or !$expression_file or !$svg_filename);


#================================================================================
# MAIN LOOP
#================================================================================

my $exp_info     = expression($expression_file);
my @sorted_nodes = sort {
	$exp_info->{$a} <=> $exp_info->{$b}
} keys %{ $exp_info };

# Get values
my @values = map {
	$exp_info->{$_};
} @sorted_nodes;

# Get intervals
my ($min, $max)  = ($values[0], $values[-1]);
my $magic_number = ($max - $min) / $color_number;
my @intervals    = ($min);

calc_intervals(
	$min,
	$magic_number,
	$color_number,
	\@intervals
);


my $int_values = join_intervals(\@intervals);

# Assign color to each interval
my ($int_2_colors, $colors) = int_to_colors($int_values);

if ($html) {
	print_colors(
		$int_2_colors, 
		$int_values, 
		$expression_file, 
		$html
	);
}

# Assign a color to each node
my $nodes_2_color = data_to_color(
	$exp_info, 
	$int_2_colors
);

# Print svg
change_svg(
	$nodes_2_color, 
	$svg_filename, 
	$colors
);

if ($debug) {
	print STDERR Dumper($exp_info);
	print STDERR Dumper($int_2_colors);
	print STDERR Dumper($nodes_2_color);
}

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
		my $rounded_val    = sprintf("%.4f", $value);
		$exp_info{$node}   = $rounded_val;
	}

	return \%exp_info;

} # sub expression

#--------------------------------------------------------------------------------
sub calc_intervals {
	my $min          = shift;
	my $magic_number = shift;
	my $color_number = shift;
	my $intervals    = shift;

	my $int_value = $min;

	for my $i (1..$color_number) {
		$int_value += $magic_number;
		push @{ $intervals }, $int_value;
	}

	return;
}


#--------------------------------------------------------------------------------
sub join_intervals {
	my $intervals  = shift;
	my %int_values = ();

	for my $i (0..@{ $intervals } -2) {
		$int_values{$intervals[$i] . "-" . $intervals[$i+1]} = $i;
	}

	return \%int_values;
}

#--------------------------------------------------------------------------------
sub int_to_colors {
	my $intervals    = shift;
	my $number       = keys %{ $intervals };
	my %int_2_colors = ();

	my $spect         = Color::Spectrum::Multi->new();
	my $colors_needed = $number -1;

	my @colors = $spect->generate(
		$colors_needed, 
		"#E6FFFF", 
		"#000099"
	);

	unshift @colors, "#FFFFFF"; # Add white to first interval

	my @sorted_int = sort { 
		$intervals->{$a} <=> $intervals->{$b} 
	} keys %{ $intervals };


	foreach my $i (0..$#colors) {
		$int_2_colors{$sorted_int[$i]} = [$i, $colors[$i]];
	}

	return (\%int_2_colors, \@colors);
}

#--------------------------------------------------------------------------------
sub print_colors {
	my $int_2_colors = shift;
	my $intervals    = shift;
	my $filename     = shift;
	my $html_name    = shift;
	my $out_name     = '';

	if ($html_name !~ /\.html$/) {
		$out_name = $html_name . '.html';
	} else {
		$out_name = $html_name;
	}


	open my $html_fh, '>', "$out_name"
		or die "Can't write to $out_name : $!\n";

	my $cgi = CGI->new;
	print $html_fh $cgi->header, 
                   $cgi->start_html("${filename}_colors"),
                   $cgi->h1('Your colors');
	print $html_fh '<table border = "1" cellspacing="0" >';

	my @sorted_int = sort { 
		$intervals->{$a} <=> $intervals->{$b} 
	} keys %{ $intervals };

	foreach my $int (@sorted_int) {
		print $html_fh '<tr><td bgcolor="', 
		               $int_2_colors->{$int}->[1], '">', 
		               $int_2_colors->{$int}->[1], '</td>',
		               "<td><td bgcolor=", 
		               $int_2_colors->{$int}->[1], '>',
		               "$int<td>", "</tr>", "\n";
	}

	print $html_fh $cgi->end_html;
	close $html_fh;
	return;

} # sub print_colors

#--------------------------------------------------------------------------------
sub data_to_color {
	my $data         = shift;
	my $int_2_colors = shift;
	my %data_2_color = ();

	my ($min_int, $max_int);

	foreach my $node (keys %{ $data }) {

		foreach my $interval (keys %{ $int_2_colors }) {
			my ($min, $max) = split /\-/, $interval;
			my $rounded_min = sprintf("%.4f", $min);
			my $rounded_max = sprintf("%.4f", $max);
			my $rounded_val = sprintf("%.4f", $data->{$node});

			if ($rounded_val >= $rounded_min and $rounded_val <= $rounded_max) {
				$data_2_color{$node} = $int_2_colors->{$interval}->[1]
					unless exists $data_2_color{$node};
			}# if

		} # foreach interval

	} # foreach node

	return \%data_2_color;

} # sub data_2_color

sub missing_nodes {
	
	# This will be needed when $range option is provided,

	## Find missing nodes
	#my @sorted = sort {
	#	$int_2_colors->{$a}[0] <=> $int_2_colors->{$b}[0]
	#} keys %$int_2_colors;

	#my ($min_int, $max_int) = ($sorted[0], $sorted[-1]);

	#my @missing_nodes = grep {
	#	!exists $data_2_color{$_} 
	#} keys %{ $data };

}


#--------------------------------------------------------------------------------
sub change_svg {
	
	my $nodes_2_color = shift;
	my $svg_file      = shift;
	my $colors        = shift;

	open my $svg_fh, '<', $svg_file
		or die "Can't asdf open $svg_file : $!\n";


	local $/ = '<circle';

	my $first =<$svg_fh>;
	$first =~ s/<circle//;
	$first =~ s/[\s\t]+$//;
	
	print "$first\n"; # skip first line;
	print_legend($colors);

	while (<$svg_fh>) {
		
		chomp;
		if ($_ =~ m/class=\"(\w+)\"/g) {
			my $node = $1;
			if (exists $nodes_2_color->{$node}) {
				my $color = $nodes_2_color->{$node};

				$_ =~ s/fill=\"(.*?)\"/fill=\"$color\"/g;
				#$_ =~ s/fill=\"#(\d+)\"/fill=\"$color\"/ge;

				print "\t<circle$_\n";
			} else {
				print "\t<circle$_\n";# if gene
			}
		
		} # if node
		
	} # while 

	return;

} # sub change_svg


#--------------------------------------------------------------------------------
sub print_legend {
	my $colors = shift;

	my $x = 70;
	my $y = 50;

	foreach my $color (@{ $colors }) {
		print "<rect", "\n",
		      "style=\"fill:$color;fill-opacity:1;stroke-opacity:1;stroke:#000000\"", "\n",
		      "id=\"rect3099\"", "\n",
		      "width=\"250\"", "\n",
		      "height=\"60\"", "\n",
		      "x=\"$x\"", "\n",
		      "y=\"$y\" />", "\n";
		$y += 62;
	} 

	return;
}

#--------------------------------------------------------------------------------
sub help {
	print STDERR << 'EOF';

||--------------------------------------------------------------------------------||
||  This script maps expression data onto an svg graph.                           ||
||  It will create an svg file with different colors depending                    ||
||  on the expression of each node. The output will be printed                    ||
||  to STDOUT.                                                                    ||
||                                                                                ||
||  Usage:                                                                        ||
||  	perl map_expression.pl <options> > /path/to/output.svg                    ||
||                                                                                ||
||  Options:                                                                      ||
||                                                                                ||
||  	REQUIRED:                                                                 ||
||  	--exp <file>   - dot file with expression data.                           ||
||  	--svg <file>   - svg file.                                                ||
||                                                                                ||
||  	OPTIONAL:                                                                 ||
||  	--cutoff   <integer> - Everything below this value will be white.         ||
||  	--html     <file>    - Creates an html file with the gradient generated.  ||
||  	--colornum <integer> - Set number of colors.                              ||
||                                                                                ||
||--------------------------------------------------------------------------------||
EOF

exit(0);
} # sub help