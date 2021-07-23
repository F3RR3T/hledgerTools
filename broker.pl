#!/usr/bin/perl
# BROKER.pl
# Add Brokerage to JOURNAL files that have been generated from csv
#
use strict;
use warnings;
use Cwd;		# Current working directory

my $thisDir = cwd;
my $rawFile; # the name of the file to process
my $outputFile;
#die  "hello ";

if (@ARGV > 0) {
    $rawFile = $ARGV[0];
    if ($rawFile =~ /^raw-/ ) {
        print "Processing raw journal file $rawFile for Brokerage\n";
        $outputFile = $';   # the rest of the matched string
    }
    else {die " The input filename must begin with 'raw-'.";} 
} else { # no commmand line argument
    # if ("No COMMAND line, arguments" =~ /\s(\w+),/) { print "That was ($`)($&)($').\n"; }
    opendir(DIR, $thisDir);
    my @rawFiles = grep(/^raw-.+\.journal$/,readdir(DIR));
    closedir(DIR);
    my $numFiles = @rawFiles;
    #print "Number of files: ".$numFiles . "\n";
    if ($numFiles > 1) {
        die "Usage: you can only have one RAW .journal file in the directory.";
    } elsif ($numFiles = 1) {
        $rawFile = $rawFiles[0];
        $rawFile =~ /^raw-/;
        $outputFile = $';       # strip off the raw- prefix
        #        print $outputFile . "\n";
    } else { die " Usage: name the .journal file to process as a command line argument.";}
}

if ( ! open IN, "< ".$thisDir."/".$rawFile) {
    die " Cannot open journal file in ". $thisDir. ": $!";
}

if (! open OUT, "> ${outputFile}") {
    die " Could not open $outputFile for output in ".$thisDir.": $!";
}

my $i=0;
my $brokerageACC = "expenses:misc:shares:brokerage";
my $brokerageTransaction = 0; # default is FALSE
my $brokerageTotal =0;
my $buysellFlag;
my ($numShares, $coCode, $sharePrice);

while (<IN>) {
    chomp;
    &writeOUT and next if (/^;/);   # write out comments 
    if (/^\s*$/) {                  # Blank line means end of (previous) transaction
        &writeBrokerage if ($brokerageTransaction);            # Write summed Brokerage amount from prev.
        &writeOUT;                  # Write the blank line
        next;
    }

    # check for transaction top lines
    if (/^\d{4}\/\d{2}\/\d{2}/) {       # we found a date at the start of the line
        $i++;                           # increment transaction counter
	&buySell;
	&getShareCode;			# scrape code and num shares
        $brokerageTransaction = (/Fees:[0-9.]+/) ? 1 : 0;
	my ($fee, $gst) = /Fees:(\d+.\d\d)\+([0-9.]+)/;
	$brokerageTotal = $fee + $gst;
        &writeOUT and next;
    } 
    if ($brokerageTransaction) {;             # top line was tagged 'Fees:'
        applyBrokerage();
    }
    else {
        writeOUT();
    }
}

# special case if last transaction in file was GST 
&writeBrokerage if ($brokerageTransaction);            # Write summed GST amount from prev.
print "Processed $i transactions, written to $outputFile.\n";

################################################################

sub applyBrokerage {
    my($account, $amt, $desc) = (split /\s{2,}/)[1, 2, 3];
    my $posting;
    # print "account:$account\n";
    # print " dollars $amt\n";
    #if (($buysellFlag eq "BUY") && ($account =~ /assets:shares/)) {
    if ($account =~ /assets:shares/) {
    	print "this is a share\n$_\n";
	# Unprocessed share amounts are always NEGATIVE
	# Therefore ADD the brokerage to reduce ABS()
	$amt = sprintf("%.2f", $amt + $brokerageTotal);
    }
    # Correct sign of transaction if BUY
    $amt = ($buysellFlag eq "BUY") ? -1 * $amt : $amt;
    $amt = sprintf("%.2f", $amt);
    $desc = (length($desc)) ? $desc : "";
    XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:
    print OUT "    $account  $numShares $coCode @ $sharePrice   $desc\n";
}

sub writeBrokerage {
    $brokerageTotal = sprintf("%.2f", $brokerageTotal);     # format to 2 decimals for cents
    print OUT "    $brokerageACC    $brokerageTotal\n";
    $brokerageTransaction = 0;
}

sub buySell {
    s/B Contract/BUY Contract/;   
    s/S Contract/SELL Contract/;   
    # set flag for adjustSign subroutine
    $buysellFlag = (/BUY Contract/) ? "BUY" : "SELL";
}

sub  getShareCode{
	print "getShareCode\n$_\n";
    s/(Price:)\s+/$1/;
    s/Num Shares:(\d+)\.\d\d/$1/;
    print $_."\n";
    $numShares = $1;
    ($coCode) = /Company:(\w+)/;
    if ($coCode eq "CL8") { $coCode = "CL"};
    ($sharePrice) = /Price:(\d+.\d+)/;
    print "numShares: $numShares\t $coCode\n";
}

sub writeOUT {
    if (/^\s*$/) {$_ = ""};     # replace whitespace-only line with clean blank line
    print OUT $_ . "\n";
    #next;  <-- don't use next in a subroutine bc bad ok
}
