#!/usr/bin/perl

use strict;
use warnings;

my @rawLines = ();
my @lines = ();
my @comments = ();
while (my $line = <STDIN>) {
	chomp($line);
	push(@rawLines, $line);
	# コメントを分離
	if ($line =~ /(('|r\s*e\s*m).*)$/i) {
		push(@comments, $1);
	} else {
		push(@comments, "");
	}
	$line =~ s/('|r\s*e\s*m).*$//ig;
	# 空白を除去
	$line =~ s/\s//g;
	# 大文字に統一
	push(@lines, uc($line));
}
