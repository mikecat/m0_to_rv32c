#!/usr/bin/perl

use strict;
use warnings;

sub getIntValue {
	my $s = $_[0];
	my $sign = 1;
	$s =~ s/#/0x/g;
	$s =~ s/`/0b/g;
	if (substr($s, 0, 1) eq "-") {
		$sign = -1;
		$s = substr($s, 1);
	}
	return $sign * oct($s);
}

# 行の正規化
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

# $regMap[M0_reg] = RV32C_reg
my @regMap = (
	10, 11, 12, 13, 8, 9, 18, 19,
	20, 21, 22, 23, 14, 2, 1, 15
);

# 変換処理
my @convertedLines = ();
for (my $i = 0; $i < @lines; $i++) {
	my $line = $lines[$i];
	my $converted = $rawLines[$i];
	if ($line eq "") {
		$converted = "";
	} elsif ($line =~ /^(U?DATA[BWL]?|MODE|IFM0|ORGR?|ALIGNR?|SPACE)/) {
		# 疑似命令
		my $lineStripped = $rawLines[$i];
		$lineStripped =~ s/^\s+//;
		$converted = "\t" . uc($lineStripped);
	} elsif (substr($line, 0, 1) eq "@") {
		# ラベル
		$converted = $line;
	} elsif ($line =~ /^R(\d+)=([0-9A-F#`-]+)$/) {
		my ($rd, $u8) = ($1, $2);
		my $rdc = $regMap[$rd];
		my $u8v = &getIntValue($u8);
		$converted = sprintf("\tR%d = %s%s", $rdc, 0 <= $u8v && $u8v < 0x20 ? "" : "R0 + ", $u8);
	} elsif ($line =~ /^R(\d+)=R(\d+)$/) {
		my ($rd, $rm) = ($1, $2);
		if ($rd == 15 && $rm == 15) {
			printf STDERR "R15 = R15 is not supported at line %d\n", $i + 1;
			$converted = "' " . $rawLines[$i];
		} elsif ($rd == 15) {
			$converted = sprintf("\tGOTO R%d", $regMap[$rm]);
		} elsif ($rm == 15) {
			my $rdc = $regMap[$rd];
			$converted = sprintf("\tR%d = PC + 0\n\tR%d += 4", $rdc, $rdc);
		} else {
			$converted = sprintf("\tR%d = R%d", $regMap[$rd], $regMap[$rm]);
		}
	} else {
		printf STDERR "warning: unsupported at line %d\n", $i + 1;
		$converted = "' " . $rawLines[$i];
	}
	push(@convertedLines, $converted);
}

# 変換結果の出力
for (my $i = 0; $i < @convertedLines; $i++) {
	print $convertedLines[$i];
	if ($comments[$i] ne "") {
		print " ' " . $comments[$i];
	}
	print "\n";
}
