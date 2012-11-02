use 5.010;
use strict;
use warnings;

use Test::More;

use YAML;

use_ok 'Marpa::Easy';

#
# This test case is borrowed from Jeffrey Kegler's Marpa::R2 distribution 
# (https://github.com/jeffreykegler/Marpa--R2/blob/master/r2/t/timeflies.t)
# where the necessary details are provided.
#

#
# We are parsing the sentence using 2 methods: one is input model (IM) that implies 
# using alternate()/earleme_complete() when ambiguous tokens are seen
# and the other is ambiguous tokens (AT) that joins ambiguous tokens types 
# into a single token and adds token rules like [ type1 => ['type1/type2/type3'] ]
# to the grammar. The test case cited uses both methods in a single grammar.
#
my $grammar = q{
    
    S    ::= C | C comma conjunction C
    
    C      ::= NP VP
    
    V        ::= v
    O      ::= NP
    
    NP          ::= article? adjective? noun

    VP          ::= V O | V A
    A     ::= PP                  
    PP          ::= preposition NP
    
    adjective   ::= adj
    article     ::= ia
    comma       ::= ,
    conjunction ::= c
    noun        ::= n
    preposition ::= p
    
};

# part-of-speech (pos) data 
my $pos = {

    a       => [qw{ ia       }],    # indefinite article
    an      => [qw{ ia       }],

    arrow   => [qw{    adj n   }],    
    banana  => [qw{    adj n   }],
    but     => [qw{ c        }],    # conjunction
    flies   => [qw{      n v }],    
    fruit   => [qw{    adj n v }],    # adjective noun verb
    time    => [qw{    adj n v }],    

    like    => [qw{ p  adj n v }],    # like is also a preposition

};

# check if we have WordNet::QueryData to pull pos from
eval { require WordNet::QueryData };
my $WordNet_QueryData_installed = $@;

# split sentence into [ part_of_speech, word ] tokens
sub tokenize {

    my $text   = shift;

    my @lexems = grep { $_ } map { s/^\s+//; s/\s+$//; $_ } split /(\w+)/, $text;
    
    my $tokens = [];
    
    my $wn     = $WordNet_QueryData_installed ? WordNet::QueryData->new( noload => 1 ) : undef;
    
    # set up [ pos, word ] tokens
    for my $lexem (@lexems){

        # pull lexem's part(s) of speech from WordNet if we have it installed
        # set empty otherwise
        my %pos = ref $wn eq 'WordNet::QueryData' ? 
                  map   { $_->[1] => undef } 
                  grep  { $_ ne 'r' } # filter adverbs out
                  map   { [ split /#/ ] } $wn->validForms( $lexem ) : 
                  ();
                  
        
        # add only missing part-of-speech data from $pos
        map { $pos{$_} = undef } @{ $pos->{$lexem} || [] };
        
        # set up part of speech data as an array
        my @pos = keys %pos;
        
        # ambiguous token
        if (@pos > 1){      
            push @$tokens, [ map { [ $_, $lexem ] } @pos ] ;
        }
        # unambiguous token
        elsif (@pos){       
            push @$tokens, [ $pos[0], $lexem ];
        }
        # unknown token, treat as a bare literal
        else {
            push @$tokens, [ $lexem, $lexem ];
        }
    }
    
    $tokens;
}

# input
my $sentence = 'time flies like an arrow, but fruit flies like a banana';

# we know we want multiple parses, hence the array context of ->parse
my $tokens = tokenize($sentence);
my %token_rules;
for my $token (@$tokens){
    # ambiguous
    if (ref $token->[0] eq "ARRAY"){
        next unless $token->[0]->[1] =~ /\w/;
        $token_rules{$_} = undef for map { join ' ::= ', @$_ } @$token;
    }
    # unambiguous
    else{ 
        next unless $token->[1] =~ /\w/;
        $token_rules{join ' ::= ', @$token} = undef;
    }
}
my $token_rules = join "\n", sort keys %token_rules;

say $grammar . $token_rules;

#
# set up the grammar handling ambiguity with input model
#
my $mp_IM = Marpa::Easy->new({
    rules => $grammar . $token_rules,
    default_action => 'sexpr',
    ambiguity => 'input_model',
});
say $mp_IM->show_rules;
isa_ok $mp_IM, 'Marpa::Easy';

my @input_model_parses = $mp_IM->parse( [ map { [ $_, $_ ] } grep { $_ } map { s/^\s+//; s/\s+$//; $_ } split /(\w+)/, $sentence ] );

# expected
my $expected_IM = <<EOT;
(S (C (NP (adjective time) (noun flies)) (VP (V like) (O (NP (article an) (noun arrow))))) (comma ,) (conjunction but) (C (NP (adjective fruit) (noun flies)) (VP (V like) (O (NP (article a) (noun banana))))))
(S (C (NP (adjective time) (noun flies)) (VP (V like) (O (NP (article an) (noun arrow))))) (comma ,) (conjunction but) (C (NP (noun fruit)) (VP (V flies) (A (PP (preposition like) (NP (article a) (noun banana)))))))
(S (C (NP (noun time)) (VP (V flies) (A (PP (preposition like) (NP (article an) (noun arrow)))))) (comma ,) (conjunction but) (C (NP (adjective fruit) (noun flies)) (VP (V like) (O (NP (article a) (noun banana))))))
(S (C (NP (noun time)) (VP (V flies) (A (PP (preposition like) (NP (article an) (noun arrow)))))) (comma ,) (conjunction but) (C (NP (noun fruit)) (VP (V flies) (A (PP (preposition like) (NP (article a) (noun banana)))))))
EOT

my $trees = join("\n", map { $mp_IM->show_parse_tree($_) } sort @input_model_parses);
# tests
unless (
    is $trees . "\n", 
    $expected_IM, 
    "ambiguous sentence ‘$sentence’ parsed using alternate()/earleme_complete() input model"
    ){
    say $trees;
}

done_testing;
