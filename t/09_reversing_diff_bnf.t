use 5.010;
use strict;
use warnings;

use Test::More tests => 1;

use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 0;

use MarpaX::Parse;

my $grammar = q{

    DiffOutput ::= 
        Command+
        %{ 
            join '', @{ $_[1] } 
        %}

    Command ::= 
        LineNum 'a' LineRange RightLine+ 
            %{ 
                "$_[3]d$_[1]\n" . join '', map {s/>/</; $_} @{ $_[4] }
            %}
        |
        LineRange 'd' LineNum LeftLine+ 
            %{ 
                "$_[3]a$_[1]\n" . join '', map {s/</>/; $_} @{ $_[4] }
            %}
        |
        LineRange 'c' LineRange LeftLine+ 'qr/---\n/' RightLine+
            %{
                "$_[3]c$_[1]\n" .
                join( '', map {s/>/</; $_} @{ $_[6] } ) . 
                "$_[5]" .
                join( '', map {s/</>/; $_} @{ $_[4] } )
            %}  
        
        LineRange  ::= LineNum ',' LineNum
            %{ 
                join '', @_[1..3]
            %}

    LineRange  ::= LineNum
        
    LineNum    ::= 'qr/\d+/'
    LeftLine   ::= 'qr/<.*\n/'
    RightLine  ::= 'qr/>.*\n/'

};

# input
my $diff = q{
17,18d16
< (who writes under the
< pseudonym "Omniscient Trash")
45,46c43,44
< soon every Tom, Dick or Harry
< will be writing his own Perl book
---
> soon every Tom, Randal and Larry
> will be writing their own Perl book
69a68,69
> Copyright (c) 1998, The Perl Journal.
> All rights reserved.
};

# expected
my $reversed_diff = q{16a17,18
> (who writes under the
> pseudonym "Omniscient Trash")
43,44c45,46
< soon every Tom, Randal and Larry
< will be writing their own Perl book
---
> soon every Tom, Dick or Harry
> will be writing his own Perl book
68,69d69
< Copyright (c) 1998, The Perl Journal.
< All rights reserved.
};

sub AoA { 
    shift;
    my @children = grep { defined } @_;
    scalar @children > 1 ? \@children : shift @children;
}

my $me = MarpaX::Parse->new({
    rules => $grammar,
    default_action => __PACKAGE__ . '::AoA',
});

my $value = $me->parse($diff);

is $value, $reversed_diff, "diff reversed (example from Parse::RecDescent tutorial)";

