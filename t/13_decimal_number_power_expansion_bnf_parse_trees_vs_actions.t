use 5.010;
use strict;
use warnings;

use Test::More;

use YAML;

use XML::Twig;
use Tree::Simple;

use_ok 'MarpaX::Parse';
use_ok 'MarpaX::Parse::Tree';

my $grammar = q{

    # decimal number, possibly signed and fractional
    
    # start
    expr    ::= minus? num
        
    # parts
    num         ::= integer fractional?
    integer     ::= digit+
    fractional  ::= point digit+
    
    # terminals (literals (tokens))
    digit   ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
    minus   ::= '-' 
    point   ::= '.' 
   
};

my $grammar_with_actions = q{

    # decimal number, possibly signed and fractional
    
    # start
    expr        ::= minus? num
        %{ 
            # num is a HASH (see below the relevant rule action below)
            my $num = ( grep { ref eq "HASH" } @_ )[1];
            # int          frac          neg
            [ $num->{int}, $num->{frac}, $_[1] eq '-' ]
        %}
        
    # parts
    num         ::= integer fractional?
        %{ 
            { 
                int  => $_[1],              # integer part digits
                frac => $_[2] //= [],       # return empty array for integers
            } 
        %}
    integer     ::= digit+
    fractional  ::= point digit+
        %{ 
            $_[2]; # we don't need no decimal point
        %}
    
    # terminals (literals (tokens))
    digit   ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
    minus   ::= '-' 
    point   ::= '.' 
   
};

#
# test data
#
my $numbers_and_series = [
    # positive integer
    [ '1234',      '1*10^3 + 2*10^2 + 3*10^1 + 4*10^0' ],
    # negative float
    [ '-1234.423', '-(1*10^3 + 2*10^2 + 3*10^1 + 4*10^0 + 4*10^-1 + 2*10^-2 + 3*10^-3)' ],
    # negative integer
    [ '-1234',     '-(1*10^3 + 2*10^2 + 3*10^1 + 4*10^0)' ],
    # positive float
    [ '1234.423',  '1*10^3 + 2*10^2 + 3*10^1 + 4*10^0 + 4*10^-1 + 2*10^-2 + 3*10^-3' ],
];

#
# Note: show_parse_tree method of MarpaX::Parse really helps with layout 
# and construction of accessor expressions in a multileve data structure
#

#
# parse tree: Array of Arrays
#
sub traverse_AoA{

    my $tree = shift;
    
    my (@int, @frac, $neg);
    
    # negative
    if ( $tree->[0] eq '-' ){ 
        # integer
        if ( ref $tree->[1]->[0] ne "ARRAY" ){
            @int  = @{ $tree->[1] };
            @frac = ();
            $neg  = 1;
        }
        # float
        else {
            @int  = @{ $tree->[1]->[0] };
            @frac = @{ $tree->[1]->[1]->[1] };
            $neg  = 1;
        }
    } 
    # positive integer
    elsif ( ref $tree->[1] ne "ARRAY" ) {
        @int  = @$tree;
        @frac = ();
    }    
    # positive float
    else{
        @int  = @{ $tree->[0] };
        @frac = @{ $tree->[1]->[1] };
    }
    
    return [ \@int, \@frac, $neg ]
}

#
# parse tree: Hash of Arrays
#
sub traverse_HoA{

    my $tree = shift;
    
    my (@int, @frac, $neg);

    # positive integer or float
    if (ref $tree->{expr} eq "HASH"){
        # positive integer
        if (ref $tree->{expr}->{num} eq "HASH"){
            @int  = map { $_->{digit} } @{ $tree->{expr}->{num}->{integer}->{'digit+'} };
            @frac = ();
        }
        # positive float
        else{
            @int  = map { $_->{digit} } @{ $tree->{expr}->{num}->[0]->{integer}->{'digit+'} };
            @frac = map { $_->{digit} } @{ $tree->{expr}->{num}->[1]->{fractional}->[1]->{'digit+'} };
        }
    }
    # negative float
    elsif (ref $tree->{expr}->[1]->{num} eq "ARRAY") {
        @int  = map { $_->{digit} } @{ $tree->{expr}->[1]->{num}->[0]->{integer}->{'digit+'} };
        @frac = map { $_->{digit} } @{ $tree->{expr}->[1]->{num}->[1]->{fractional}->[1]->{'digit+'} };
        $neg  = 1;
    }
    # negative integer 
    else{
        @int  = map { $_->{digit} } @{ $tree->{expr}->[1]->{num}->{integer}->{'digit+'} };
        @frac = ();
        $neg  = 1;
    }

    return [ \@int, \@frac, $neg ]
}

#
# parse tree: Hash of Hashes 
#
sub traverse_HoH{

    my $tree = shift;
    
    my (@int, @frac, $neg);

    @int = @{ $tree->{expr}->{num}->{integer}->{'digit+'}->{digit} };
    @frac = exists $tree->{expr}->{num}->{fractional} ? @{ $tree->{expr}->{num}->{fractional}->{'digit+'}->{digit} } : ();
    $neg = $tree->{expr}->{minus};

    return [ \@int, \@frac, $neg ]
}

#
# parse tree: XML
#
sub traverse_xml{

    my $tree = shift;

    my (@int, @frac, $neg);

    # start the integer part
    my $digits = \@int;

    # setup XML parse tree
    my $t = XML::Twig->new(
        twig_handlers => {
            'digit' => sub {
                push @$digits, $_[1]->first_child->text;
            },
            # end the integer part, start the fractional part, if any
            'point' => sub {
                $digits = \@frac;
            },
            # toggle $negative on
            'minus' => sub {
                $neg = 1;
            }
        },
        pretty_print => 'indented',
    );
    $t->parse($tree);

    return [ \@int, \@frac, $neg ];
}

#
# parse tree: Tree::Simple
#
sub traverse_tree{

    my $tree = shift;

    my (@int, @frac, $neg);

    my $digits = \@int;
    
    $tree->traverse(
        sub {
            my ($t) = @_;
            my $nv = $t->getNodeValue;
            given ($nv){
                when ("minus"){
                    $neg = 1;
                }
                when ("fractional"){
                    $digits = \@frac;
                }
                when ("digit"){
                    push @$digits, $t->getChild(0)->getNodeValue;
                }
            }
        }
    );
    return [ \@int, \@frac, $neg ]
}

#
# set up closures hash
#
my $tree_traversers = {
    AoA     => \&traverse_AoA,
    HoA     => \&traverse_HoA,
    HoH     => \&traverse_HoH,
    xml     => \&traverse_xml,
    tree    => \&traverse_tree,
#    actions => sub { shift }, # what we need was returned by parse($number)
};

#
# power expansion of numbers for every parse tree type
#
for my $tree_type (sort keys %$tree_traversers){
    
    # set up grammar
    my $mp = MarpaX::Parse->new({ # Marpa::Parser
        rules           => $tree_type eq "actions" ? $grammar_with_actions : $grammar,
        default_action  => $tree_type eq "actions" ? undef : "MarpaX::Parse::Tree::$tree_type",
        # otherwise optional (? and *) will be present as undefs
        nullables_for_quantifiers => 0,
    });
    
    # test on number
    for my $number_and_series (@$numbers_and_series){

        # get the number and series we'd like to see
        my ($number, $expected_series) = @$number_and_series;
        
        # parse the number
        my $tree = $mp->parse($number); 

        # set up the parts of a number: int, frac, sign
        my ($int, $frac, $negative) = @{ $tree_traversers->{$tree_type}->($tree) };
        my @integer_part_digits = @$int;
        my @fractional_part_digits = @$frac;

        # build the series
        my @series;
        for my $i (0..$#integer_part_digits){
            # the positive power series term
            my $digit = $integer_part_digits[$i];
            my $power = $#integer_part_digits - $i;
            push @series, "$digit*10^$power"; 
        }
        for my $i (0..$#fractional_part_digits){
            # the negative power series term
            my $digit = $fractional_part_digits[$i];
            my $power = $i + 1;
            push @series, "$digit*10^-$power"; 
        }

        # stringify the series
        my $got_series = join ' + ', @series;
        $got_series = '-(' . $got_series . ')' if $negative;

        unless (is $got_series, $expected_series, "$number expanded to power series via BNF grammar with $tree_type parse tree"){
            diag "parse tree: $tree_type";
            diag MarpaX::Parse::Tree->new({ type => $tree_type })->show_parse_tree($tree);
        }
            
    } ## number_and_series 

} ## tree_type

done_testing;
