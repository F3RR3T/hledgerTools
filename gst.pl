#!/usr/bin/perl
# Can I read a file and mark the items for GST processing?
#
use strict;
use warnings;
# use diagnostics;

my $rawFile; # the name of the file to process
my $outputFile;
# my $numArgs = scalar(@ARGV);
# my $blah = "I saw ${numArgs} Arguments: " . $ARGV[0] . "\n";
# print $blah;


if (@ARGV > 0) {
    $rawFile = $ARGV[0];
    if ($rawFile =~ /^raw-/ ) {
        print "Processing raw journal file $rawFile for GST\n";
        $outputFile = $';   # the rest of the matched string
    }
    else {die " The input filename must begin with 'raw-'.";} 
} else { # no commmand line argument
    # if ("No COMMAND line, arguments" =~ /\s(\w+),/) { print "That was ($`)($&)($').\n"; }
    opendir(DIR, ".");
    my @rawFiles = grep(/^raw-.+\.journal$/,readdir(DIR));
    closedir(DIR);
    my $numFiles = @rawFiles;
    #print $numFiles . "\n";
    if ($numFiles > 1) {
        die "Usage: you can only have one RAW .journal file in the directory.";
    } elsif ($numFiles = 1) {
        $rawFile = $rawFiles[0];
        $rawFile =~ /^raw-/;
        $outputFile = $';       # strip off the raw- prefix
        #        print $outputFile . "\n";
    } else { die " Usage: name the .journal file to process as a command line argument.";}
}

if ( ! open IN, "< $rawFile") {
    die " Cannot open journal file: $!";
}

if (! open OUT, "> ${outputFile}") {
    die " Could not open $outputFile for output: $!";
}

my $i=0;
my $gstCount=0;
my $gstRoot = "liabilities:current:gst:";
my $gstACC;
my $isGST = 0; # default is FALSE
my $gstTotal =0;

while (<IN>) {
    chomp;
    
    &writeOUT and next if (/^;/);   # write out comments 
    
    if (/^\s*$/) {                  # Blank line means end of (previous) transaction
        &writeGST if ($isGST);            # Write summed GST amount from prev.
        &writeOUT;                  # Write the blank line
        next;
    }

    # check for transaction top lines
    if (/^\d{4}\-\d{2}\-\d{2}/) {       # we found a date at the start of the line
        $i++;                           # increment transaction counter
        $isGST = (/tax:GST/) ? 1 : 0;
        $gstCount = $gstCount + $isGST;
        &writeOUT and next;
    } 
    
    # this is a ledger line (i.e. either a credit or a debit)
    if ($isGST) {;             # top line was tagged 'tax:GST'
        writeOUT() and next if (/assets:/ || /liabilities:/);
        if (/^\s+expenses:/) {
            $gstACC = $gstRoot . "paid";   	
        }
        if (/^\s+income:/) {
            $gstACC = $gstRoot . "collected";
        }
        applyGST();
    }
    else {
        writeOUT();
    }
}

# special case if last transaction in file was GST 
&writeGST if ($isGST);            # Write summed GST amount from prev.
print "Processed $gstCount GST items from $i transactions, written to $outputFile.\n";

################################################################

sub applyGST {
    my($account, $amt, $desc) = (split /\s{2,}/)[1, 2, 3];
    # print "account:$account\n";
    # print " dollars $amt\n";
    my $examt = sprintf("%.2f", $amt * 10 / 11);
    $gstTotal = $gstTotal +  sprintf("%.2f", $amt - $examt);
    $desc = (length($desc)) ? $desc : "";
    print OUT "    $account\t\t\t$examt  $desc\n";
    #print OUT "    $gstACC\t\t\t$gst\n";
}

sub writeGST {
    $gstTotal = sprintf("%.2f", $gstTotal);     # format to 2 decimals for cents
    print OUT "    $gstACC\t\t\t$gstTotal\n";
    $isGST = 0;
    $gstTotal = 0;
}

sub writeOUT {
    if (/^\s*$/) {$_ = ""};     # replace whitespace-only line with clean blank line
    print OUT $_ . "\n";
    #next;  <-- don't use next in a subroutine bc bad ok
}
