#!/usr/bin/perl

package adcc::x86_64emit;
use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw(EmitObject);
sub EmitObject {
	my $aast = shift @_;
	my @lines;
	
	push @lines, "\t".'.section .note.GNU-stack,"",@progbits';
	push @lines, "\t".'.section .text';
   	foreach my $func (@{$aast->{functions}}) {
		EmitFunction($func, \@lines);
	}
	return \@lines;
}

sub EmitFunction {
	my $func = shift @_;
	my $lines = shift @_;
	push @{$lines}, "\t.globl $func->{name}";
	push @{$lines}, "$func->{name}:";
	push @{$lines}, "\tpushq %rbp";
	push @{$lines}, "\tmovq %rsp, %rbp";
	my $stack = 0-$func->{minStack};
	push @{$lines}, "\tsubq \$$stack, %rsp";
	for my $inst (@{$func->{instructions}}) {
		if($inst->{name} eq 'ret') {
			push @{$lines}, "\tmovq %rbp, %rsp";
			push @{$lines}, "\tpopq %rbp";
		}
		my $line = "\t";
		$line .= $inst->{name}." ";
		while( @{$inst->{operands}} ) {
			my $op = shift @{$inst->{operands}};
			$line .= OperandToString($op);
			$line .= ", " if( @{$inst->{operands}} );
		}
		push @{$lines}, $line;
	}
	
}
			


sub OperandToString {
	my $op = shift @_;
	if($op->{type} eq "imm"){ return '$'.$op->{value}; }
	elsif($op->{type} eq "register"){ return '%'.$op->{value}; }
	elsif($op->{type} eq "stack"){ return $op->{value}; }
	die "unknown operand type $op->{type}";
};

1
	
