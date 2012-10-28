use 5.010;
use strict;
use warnings;

use YAML;
use Test::More tests => 5;

use_ok 'Marpa::Easy';

=pod BNF for decimal numbers
    expr    ::= - num | num 
    num     ::= digits | digits . digits 
    digits  ::= digit | digits digit
    digit   ::= 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
=cut

my $with_closures = Marpa::Easy->new({   
    rules   => [
        [ expr => [qw(- num)], sub { $_[1] . $_[2] } ],
        [ expr => [qw(num)],   sub { $_[1] } ],

        [ num => [qw(digits)], 
          sub {
            join( '', @{ $_[1] } )
          }
        ],
        [ num => [qw(digits . digits)], 
          sub {
            join( '', @{ $_[1] } ) . $_[2] . join( '', @{ $_[3] } )
          }
        ],

        [ digits => [qw(digit)], 
          sub { 
            [ $_[1] ]                           # setup the sequence
        } ],
        [ digits => [qw(digits digit)], 
          sub { 
            push @{$_[1]}, $_[2];               # add next item to the sequence
            $_[1]                               # return the sequence array ref
        } ],

        [ digit => [qw(0)], sub { $_[1] } ],
        [ digit => [qw(1)], sub { $_[1] } ], 
        [ digit => [qw(2)], sub { $_[1] } ], 
        [ digit => [qw(3)], sub { $_[1] } ], 
        [ digit => [qw(4)], sub { $_[1] } ], 
        [ digit => [qw(5)], sub { $_[1] } ], 
        [ digit => [qw(6)], sub { $_[1] } ], 
        [ digit => [qw(7)], sub { $_[1] } ], 
        [ digit => [qw(8)], sub { $_[1] } ], 
        [ digit => [qw(9)], sub { $_[1] } ],
    ],
    default_action => 'AoA'
});

my $numbers = [
    [
        [ '1', '1' ],
        [ '2', '2' ],
        [ '3', '3' ],
        [ '4', '4' ],
    ],
    [
        [ '-', '-' ],
        [ '1', '1' ],
        [ '2', '2' ],
        [ '3', '3' ],
        [ '4', '4' ],
        [ '.', '.' ],
        [ '4', '4' ],
        [ '2', '2' ],
        [ '3', '3' ],
    ],
    [
        [ '-', '-' ],
        [ '1', '1' ],
        [ '2', '2' ],
        [ '3', '3' ],
    ],
    [
        [ '1', '1' ],
        [ '2', '2' ],
        [ '3', '3' ],
        [ '4', '4' ],
        [ '.', '.' ],
        [ '4', '4' ],
        [ '3', '3' ],
    ]
];

for my $number (@$numbers){
    my $value = $with_closures->parse($number);
#    say "## value: ", Dump $value;
    my $expected = ref $number eq "ARRAY" ? join('', map { $_->[1] } @$number) : $number;
    is $value, $expected, "decimal number $expected parsed with closures in rules";
}
