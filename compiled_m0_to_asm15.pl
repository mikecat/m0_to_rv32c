#!/usr/bin/perl

use strict;
use warnings;

sub regNameToId {
	my $name = $_[0];
	if ($name eq "sp") { return 13; }
	elsif ($name eq "lr") { return 14; }
	elsif ($name eq "pc") { return 15; }
	elsif (substr($name, 0, 1) eq "r") { return int(substr($name, 1)); }
	return 0;
}

my %calc_ops = (
	"neg", "= -",
	"mul", "*= ",
	"lsl", "<<= ",
	"lsr", ">>= ",
	"mvn", "= ~",
	"and", "&= ",
	"orr", "|= ",
	"eor", "^= ",
	"cmp", "- ",
	"cmn", "+ ",
	"tst", "& "
);

my @lines = ();
while (my $line = <STDIN>) {
	chomp($line);
	push(@lines, $line);
}

for (my $i = 0; $i < @lines; $i++) {
	my $line = $lines[$i];
	$line =~ s/^\s+//;
	if ($line =~ /^\.(arch|fpu|eabi_attribute|code|file|text|global|code|thumb_func|type|size|ident|section)(\s|$)/) {
		# ignore
	} elsif ($line =~ /^@/) {
		# ignore (comment?)
	} elsif ($line =~ /^(\S+):$/) {
		my $label = $1;
		$label =~ s/\./_dot_/g;
		printf "\@%s\n", $label;
	} elsif ($line =~ /^\.align\s+(\d+)$/) {
		printf "\tALIGN %d, 0, #46C0\n", 1 << int($1);
	} elsif ($line =~ /^\.word\s+(\d+)$/) {
		printf "\tUDATAL %s\n", $1;
	} elsif ($line =~ /^\.short\s+(\d+)$/) {
		printf "\tUDATAW %s\n", $1;
	} elsif ($line =~ /^\.byte\s+(\d+)$/) {
		my $data1 = $1;
		if ($i + 1 < @lines && $lines[$i + 1] =~ /^\s*\.byte\s+(\d+)$/) {
			printf "\tUDATAB %s, %s\n", $data1, $1;
			$i++;
		} else {
			printf STDERR "warning: unpaired .byte at line %d: %s\n", $i + 1, $line;
			printf "\tUDATAB %s\n", $data1;
		}
	} elsif ($line =~ /^\.word\s+(\S+)$/) {
		my $label = $1;
		$label =~ s/\./_dot_/g;
		printf "\tDADDRL \@%s\n", $label;
	} elsif ($line =~ /^mov\s+r(\d+)\s*,\s*#(\d+)$/) {
		printf "\tR%s = %s\n", $1, $2;
	} elsif ($line =~ /^mov\s+(r\d+|sp|lr|pc)\s*,\s*(r\d+|sp|lr|pc)$/) {
		my ($rd, $rm) = (&regNameToId($1), &regNameToId($2));
		if ($rd < 8 && $rm < 8) {
			printf "\tR%d = R%d + 0\n", $rd, $rm;
		} else {
			printf "\tR%d = R%d\n", $rd, $rm;
		}
	} elsif ($line =~ /^(add|sub)\s+r(\d+)\s*,\s*r(\d+)\s*,\s*#(\d+)$/) {
		my $op = $1 eq "add" ? "+" : "-";
		my ($rd, $rn) = (int($2), int($3));
		if ($rd == $rn) {
			printf "\tR%d %s= %s\n", $rd, $op, $4;
		} else {
			printf "\tR%d = R%d %s %s\n", $rd, $rn, $op, $4;
		}
	} elsif ($line =~ /^(add|sub)\s+(r\d+|sp|lr|pc)\s*,\s*(r\d+|sp|lr|pc)\s*,\s*(r\d+|sp|lr|pc)$/) {
		my $op = $1 eq "add" ? "+" : "-";
		my ($rd, $rn, $rm) = (&regNameToId($2), &regNameToId($3), &regNameToId($4));
		if ($op eq "add" && $rd == $rn && ($rd >= 8 || $rm >= 8)) {
			printf "\tR%d += R%d\n", $rd, $rm;
		} else {
			printf "\tR%d = R%d %s R%d\n", $rd, $rn, $op, $rm;
		}
	} elsif ($line =~ /^(neg|mul|lsl|lsr|mvn|and|orr|eor|cmp|cmn|tst)\s+r(\d+)\s*,\s*r(\d+)$/) {
		printf "\tR%s %sR%s\n", $2, $calc_ops{$1}, $3;
	} elsif ($line =~ /^ls([lr])\s+r(\d+)\s*,\s*r(\d+)\s*,\s*#(\d+)$/) {
		my $op = $1 eq "l" ? "<<" : ">>";
		printf "\tR%d = R%d %s %s\n", $2, $3, $op, $4;
	} elsif ($line =~ /^add\s+r(\d+)\s*,\s*pc\s*,\s*#(\d+)$/) {
		my $delta = int($2);
		if ($delta % 4 != 0) {
			printf STDERR "warning: delta is truncated at line %d: %s\n", $i + 1, $line;
		}
		printf "\tR%s = PC + %d\n", $1, $delta >> 2;
	} elsif ($line =~ /^adr\s+r(\d+)\s*,\s*([^\s+]+)(\s*\+\s*(\d+))?$/) {
		my $offset = "";
		if (defined($4)) {
			my $delta = int($4);
			if ($delta % 4 != 0) {
				printf STDERR "warning: offset is truncated at line %d: %s\n", $i + 1, $line;
			}
			$offset = sprintf(" + %d", $delta >> 2);
		}
		my ($rd, $label) = ($1, $2);
		$label =~ s/\./_dot_/g;
		printf "\tR%s = \@%s%s\n", $rd, $label, $offset;
	} elsif ($line =~ /cmp\s+r(\d+)\s*,\s*#(\d+)$/) {
		printf "\tR%s - %s\n", $1, $2;
	} elsif ($line =~ /^cmp\s+(r\d+|sp|lr|pc)\s*,\s*(r\d+|sp|lr|pc)$/) {
		printf "\tR%d - R%d\n", &regNameToId($1), &regNameToId($2);
	} elsif ($line =~ /^ldr(s?[bh]?)\s+r(\d+)\s*,\s*\[\s*(sp|pc|r\d+)\s*,\s*([#r])(\d+)\s*\]$/) {
		my ($size, $div) = ("L", 4);
		if ($1 eq "b") { $size = ""; $div = 1; }
		elsif ($1 eq "sb") { $size = "C"; $div = 1; }
		elsif ($1 eq "h") { $size = "W"; $div = 2; }
		elsif ($1 eq "sh") { $size = "S"; $div = 2; }
		my $kind = "R";
		my $offset = int($5);
		if ($4 eq "#") {
			$kind = "";
			if ($offset % $div != 0) {
				printf STDERR "warning: offset is truncated at line %d: %s\n", $i + 1, $line;
			}
			$offset /= $div;
		}
		printf "\tR%s = [%s + %s%d]%s\n", $2, uc($3), $kind, $offset, $size;
	} elsif ($line =~ /^str([bh]?)\s+r(\d+)\s*,\s*\[\s*(sp|r\d+)\s*,\s*([#r])(\d+)\s*\]$/) {
		my ($size, $div) = ("L", 4);
		if ($1 eq "b") { $size = ""; $div = 1; }
		elsif ($1 eq "h") { $size = "W"; $div = 2; }
		my $kind = "R";
		my $offset = int($5);
		if ($4 eq "#") {
			$kind = "";
			if ($offset % $div != 0) {
				printf STDERR "warning: offset is truncated at line %d: %s\n", $i + 1, $line;
			}
			$offset /= $div;
		}
		printf "\t[%s + %s%d]%s = R%s\n", uc($3), $kind, $offset, $size, $2;
	} elsif ($line =~ /^ldr\s+r(\d+)\s*,\s*([^\s+]+)(\s*\+\s*(\d+))?$/) {
		my $offset = "";
		if (defined($4)) {
			my $delta = int($4);
			if ($delta % 4 != 0) {
				printf STDERR "warning: offset is truncated at line %d: %s\n", $i + 1, $line;
			}
			$offset = sprintf(" + %d", $delta >> 2);
		}
		my ($rd, $label) = ($1, $2);
		$label =~ s/\./_dot_/g;
		printf "\tR%s = [\@%s%s]L\n", $rd, $label, $offset;
	} elsif ($line =~ /^b(eq|ne|cs|cc|mi|pl|vs|vc|hi|ls|ge|lt|gt|le)\s+(\S+)$/) {
		my ($cond, $label) = ($1, $2);
		$label =~ s/\./_dot_/g;
		printf "\tIF %s GOTO \@%s\n", uc($cond), $label;
	} elsif ($line =~ /^b\s+(\S+)$/) {
		my $label = $1;
		$label =~ s/\./_dot_/g;
		printf "\tGOTO \@%s\n", $label;
	} elsif ($line =~ /^bx\s(r\d+|sp|lr|pc)$/) {
		my $rm = &regNameToId($1);
		if ($rm == 14) {
			print "\tRET\n";
		} else {
			printf "\tGOTO R%d\n", $rm;
		}
	} elsif ($line =~ /^bl\s+(\S+)$/) {
		my $label = $1;
		$label =~ s/\./_dot_/g;
		printf "\tGOSUB \@%s\n", $label;
	} elsif ($line =~ /^blx\s(r\d+|sp|lr|pc)$/) {
		printf "\tGOSUB R%d\n", &regNameToId($2);
	} elsif ($line =~ /^(push|pop)\s+(\{[^\{\}]*\})$/) {
		printf "\t%s %s\n", uc($1), uc($2);
	} elsif ($line =~ /^(add|sub)\s+sp\s*,\s*sp\s*,\s*#(\d+)$/) {
		my $op = $1 eq "add" ? "+" : "-";
		my $delta = int($2);
		if ($delta % 4 != 0) {
			printf STDERR "warning: delta is truncated at line %d: %s\n", $i + 1, $line;
		}
		printf "\tSP %s= %d\n", $op, $delta >> 2;
	} elsif ($line =~ /^add\s+r(\d+)\s*,\s*sp\s*,\s*#(\d+)$/) {
		my $delta = int($2);
		if ($delta % 4 != 0) {
			printf STDERR "warning: delta is truncated at line %d: %s\n", $i + 1, $line;
		}
		printf "\tR%s = SP + %d\n", $1, $delta >> 2;
	} elsif ($line =~ /^(rev|rev16|revsh|[su]xt[hb])\sr(\d+)\s*,\s*r(\d+)$/) {
		printf "\tR%s = %s(R%s)\n", $2, uc($1), $3;
	} elsif ($line =~ /^asr\s+r(\d+)\s*,\s*r(\d+)\s*,\s*#(\d+)$/) {
		printf "\tR%s = ASR(R%s, %s)\n", $1, $2, $3;
	} elsif ($line =~ /^(asr|bic|ror)\s+r(\d+)\s*,\s*r(\d+)$/) {
		printf "\t%s R%s, R%s\n", uc($1), $2, $3;
	} elsif ($line =~ /^(ad|sb)c\s+r(\d+)\s*,\s*(\d+)$/) {
		my ($op, $suffix) = ("+", "C");
		if ($1 eq "sb") { $op = "-"; $suffix = "!C"; }
		printf "\tR%d %s= R%d + %s\n", $2, $op, $3, $suffix;
	} elsif ($line =~ /^(ld|st)mia\s+r(\d+)!\s*,\s*(\{[^\{\}]*\})$/) {
		printf "\t%sM R%s, %s\n", uc($1), $2, uc($3);
	} elsif ($line =~ /^(cpsi[de])(\s+i)?$/) {
		printf "\t%s\n", uc($1);
	} elsif ($line =~ /^(wfi|yield|wfe|sev|dmb|dsb|isb)$/) {
		printf "\t%s\n", uc($1);
	} elsif ($line =~ /^svc\s+(\d+)$/) {
		printf "\tSVC %s\n", $1;
	} elsif ($line =~ /^bkpt\s+0x([0-9a-fA-F]+)$/) {
		printf "\tBKPT #%s\n", $1;
	} else {
		printf STDERR "unsupported at line %d: %s\n", $i + 1, $line;
		printf "\t' %s\n", $line;
	}
}
