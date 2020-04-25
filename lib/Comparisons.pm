package Comparisons;
use strict;
use warnings;
use Carp;
 
use Exporter qw(import);
our @EXPORT = qw(
    parseFile
    removeUncommonColumnsAndRows
    countDiffs
    calcDiffs
    printPair
    makeColNames
);

#### Parse the processed file from UC Berkeley and return a hash ref
## with data structure:
##        $data->{fips} -> {#cases_date} = #cases;
##        $data->{fips} -> {#deaths_date} = #deaths;

sub parseFile {
    my $file = shift;
    my $columns = shift; 
    my $allFIPS = shift; 
    my $noCases = shift;
    my $skipFIPS = shift; 

    open F, $file or croak "Can't open processed file $file";
    my $header = <F>;
    chomp $header;
    my @header = split /,/, $header;
    map{$columns->{$_} ++} @header[1..$#header];
    my %data;
    while (<F>) {
	chomp;
	my @F = split /,/;
	my $fips = $F[0];
	## New York City and Kansas City, MO are in the NYT file as City[12]
	next if ($fips =~ /^City[12]$/);
	next if (exists $skipFIPS->{$fips});

	### skip the lines with no cases;
	my $skip = 1;
	foreach my $value (@F[1..$#F]) {
	    if ($value > 0) {
		$skip = 0;
		last;
	    } ##
	}  ## foreach value
	if ($skip) {
	    $noCases->{$fips} ++;
	    next;
	}

	$allFIPS->{$fips} ++;
	map{
	    ## data{fips} -> {#cases_date} = #cases;
	    ## data{fips} -> {#deaths_date} = #deaths;
	    $F[$_] =~ s/\.0+$//;
	    $data{$fips} -> {$header[$_]} = $F[$_];
	} (1..$#F);
    } ## while
    close F;
    return \%data;
}
sub removeUncommonColumnsAndRows {
    my @data = @ {shift()};
    my %allHeaders = % {shift()};
    my %allFIPS = %{ shift()};
    my @columns2Delete = ();
    foreach my $i (0..$#data) {
	my %data = %{$data[$i]};
	my @FIPS = keys %data;

	my @columns = keys %{$data{$FIPS[0]}};
	my %columns;
	map{$columns{$_} = 1} @columns;
	foreach my $col (keys %allHeaders) {
	    if (not exists $columns{$col}) {
		push @columns2Delete, $col;
	    }
	} ## foreach column
    } ## foreach $i

    foreach my $i (0..$#data) {
	my %data = %{$data[$i]};
	my @FIPS = keys %data;

	my @fips2Remove;
	foreach my $fips (sort @FIPS) {
	    ## this is missing rows that have all zeros in one and a nonzero
	    ## in another;  maybe add this later; 
	    if ($allFIPS{$fips} != scalar @data) {
		#carp "Removing fips $fips from data source $i\n";
		#delete $data{$fips};
		push @fips2Remove, $fips;
		next;
	    } ## if
	    delete @{$data{$fips}}{@columns2Delete};
	}  ## foreach fips
	delete @data{@fips2Remove};
	carp "Removed fips @fips2Remove from data source $i\n";
	$data[$i] = \%data;
    } ## foreach data source
    return \@data;
} ## sub remove columns and rows

sub countDiffs {
    my @data = @{ shift()};

    my @FIPS = sort {$a<=>$b} keys %{$data[0]};
    my @columns = sort keys %{$data[0]->{$FIPS[0]}};
    my %diffs;
    
    foreach my $fips (@FIPS) {
	my %counts;
	foreach my $col (@columns) {
	    my $diff = $data[0]->{$fips}->{$col} - $data[1]->{$fips}->{$col};
	    $counts{$diff} ++;
	}
	$diffs{$fips} = \%counts;
    } ## foreach
    return \%diffs;

} ## sub countDiffs

sub calcDiffs {
    my @data = @{ shift()};

    my @FIPS = sort {$a<=>$b} keys %{$data[0]};
    my @columns = sort keys %{$data[0]->{$FIPS[0]}};
    
    my %diffs;
    my %l1Dist;
    foreach my $fips (@FIPS) {
	my %counts;
	my @diffs;
	foreach my $col (@columns) {
	    my $diff = $data[0]->{$fips}->{$col} - $data[1]->{$fips}->{$col};
	    push @diffs, $diff;
	}
	$diffs{$fips} = \@diffs;
	my $l1 = 0;
	map{$l1 += abs} @diffs;
	$l1Dist{$fips} = $l1;
    } ## foreach
    return (\%diffs,\%l1Dist);
} ## sub calcDiffs

## to do: change this to printHeader and printLine(0,1 or (0,1)
sub printPair {
    my @data = @{shift()};
    my $fips = shift;
    my @files = @{shift()};
    map{s%^.*/(.....).*$%$1%} @files;

    my %d0 = %{$data[0]->{$fips}};
    my %d1 = %{$data[1]->{$fips}};
    my @colName = makeColNames($data[0]);
    print join("\t", $fips, @colName), "\n";
    print join("\t", $files[0], @d0{sort keys %d0}), "\n";
    print join("\t", $files[1], @d1{sort keys %d1}), "\n";
    print "\n";
}

sub makeColNames {
    my %data = %{ shift()};
    my $oneFIPS = (keys %data)[0];
    my @colName = sort keys %{$data{$oneFIPS}};
    map{s/^#(.).*_(\d{2}-\d{2})-\d{4}$/${1}_$2/} @colName;
    return(@colName);
} # sub makeColNames;

1;
