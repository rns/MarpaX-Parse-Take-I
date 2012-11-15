use 5.010;
use strict;
use warnings;

use Test::More tests => 5;

use_ok 'MarpaX::Parse::Grammar';

# The below is BNF for decimal numbers, no literals
#
#    expr    ::= - num | num 
#    num     ::= digits | digits . digits 
#    digits  ::= digit | digits digit
#    digit   ::= 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9

my $with_closures = MarpaX::Parse::Grammar->new({   
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
    default_action => __PACKAGE__ . '::do_what_I_mean'
});

sub do_what_I_mean { 
    shift;
    my @values = grep { defined } @_;
    scalar @values > 1 ? \@values : shift @values;
}

my $tests = [

    [
        [
            [ '1', '1' ],
            [ '2', '2' ],
            [ '3', '3' ],
            [ '4', '4' ],
        ],
        '1234'
    ],    

    [
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
        '-1234.423'
    ],    

    [
        [
            [ '-', '-' ],
            [ '1', '1' ],
            [ '2', '2' ],
            [ '3', '3' ],
        ],
        '-123'
    ],    

    [
        [
            [ '1', '1' ],
            [ '2', '2' ],
            [ '3', '3' ],
            [ '4', '4' ],
            [ '.', '.' ],
            [ '4', '4' ],
            [ '3', '3' ],
        ],
        '1234.43'
    ],    
];

for my $test (@$tests){
    
    my ($number, $digits) = @$test;
    
    # setup the recognizer
    my $recognizer = Marpa::R2::Recognizer->new( { 
        grammar => $with_closures->grammar, 
        closures => $with_closures->closures, 
    } ) or die 'Failed to create recognizer';

    # read tokens
    for my $token (@$number){
        defined $recognizer->read( @$token ) or die "Recognition failed";
    }

    # evaluate the parse
    while ( defined( my $value_ref = $recognizer->value() ) ) {
        my $value = $value_ref ? ${$value_ref} : 'No parse';
        
        is $value, $digits, "decimal number '$value' parsed into digits and evaluated with closures in rules";
    }

}
