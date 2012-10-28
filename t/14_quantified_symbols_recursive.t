use 5.010;
use strict;
use warnings;

use Test::More tests => 8;

use YAML;

use Marpa::Easy;

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

my $me = Marpa::Easy->new({ 
    rules => $rules,
    default_action => 'AoA',
    quantifier_rules => 'recursive',
});

#say $me->show_rules();

for my $input (@$inputs){
    my $input_str = join ' ', map { $_->[0] } @$input;
    my $value = $me->parse($input);
    unless (is ref $value eq "ARRAY" ? join(' ', @$value) : $value, $input_str, "<$input_str> parsed with quantified symbols in recursive rules"){
        say Dump $value;
    }
}
    
