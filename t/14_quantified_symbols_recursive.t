use 5.010;
use strict;
use warnings;

use Test::More tests => 8;

use YAML;

use MarpaX::Parse;

my $inputs = [
    [
        [ 'head', 'head' ],
        [ 'tail', 'tail' ],
    ],
    [
        [ 'head', 'head' ],
        [ 'item', 'item' ],
        [ 'tail', 'tail' ],
    ],
    [
        [ 'head', 'head' ],
        [ 'item', 'item' ],
    ],
    [
        [ 'head', 'head' ],
        [ 'item', 'item' ],
        [ 'item', 'item' ],
    ],
    [
        [ 'item', 'item' ],
        [ 'item', 'item' ],
        [ 'tail', 'tail' ],
    ],
    [
        [ 'item', 'item' ],
        [ 'tail', 'tail' ],
    ],
    [
        [ 'head', 'head' ],
    ],
    [
        [ 'tail', 'tail' ],
    ],
];

my $rules = [
    [ sequence => [qw(head_zero_or_one_tail)] ],

    [ sequence => [qw(head_zero_or_more)] ],
    [ sequence => [qw(zero_or_more_tail)] ],

    [ sequence => [qw(head_one_or_more)] ],
    [ sequence => [qw(one_or_more_tail)] ],
    
    [ head_zero_or_one_tail => [qw(head item? tail)], sub { 
        shift; 
        join ' ', @_
    } ],
    
    [ head_zero_or_more => [qw(head item*)], sub { 
        # grep is to filter '' produced by join ' ', []
        join ' ', $_[1], grep { $_ } join ' ', @{ $_[2] }
    } ],
    [ head_one_or_more => [qw(head item+)], sub { 
        join ' ', $_[1], grep { $_ } join ' ', @{ $_[2] }
    } ],

    [ zero_or_more_tail => [qw(item* tail)], sub { 
        join ' ', grep { $_ } join(' ', @{ $_[1] }), $_[2]
    } ],
    [ one_or_more_tail => [qw(item+ tail)], sub { 
        join ' ', grep { $_ } join(' ', @{ $_[1] }), $_[2]
    } ],
];

sub AoA { 
    shift;
    my @children = grep { defined } @_;
    scalar @children > 1 ? \@children : shift @children;
}

my $me = MarpaX::Parse->new({ 
    rules => $rules,
    default_action => __PACKAGE__ . '::AoA',
    quantifier_rules => 'recursive',
    nullables_for_quantifiers => 0,
});

for my $input (@$inputs){
    my $input_str = join ' ', map { $_->[0] } @$input;
    my $value = $me->parse($input);
    unless (is ref $value eq "ARRAY" ? join(' ', @$value) : $value, $input_str, "<$input_str> parsed with quantified symbols in recursive rules"){
        say Dump $value;
    }
}
    
