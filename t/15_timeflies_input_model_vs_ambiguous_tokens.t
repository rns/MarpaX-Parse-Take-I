use 5.010;
use strict;
use warnings;

use Test::More;

use YAML;

use_ok 'Marpa::Easy';

#
# This test case is borrowed from Jeffrey Kegler's Marpa::R2 distribution 
# https://github.com/jeffreykegler/Marpa--R2/blob/master/r2/t/timeflies.t
# where are the necessary details are provided.
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
    
    adjective   ::= a
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

    arrow   => [qw{    a n   }],    
    banana  => [qw{    a n   }],
    but     => [qw{ c        }],    # conjunction
    flies   => [qw{      n v }],    
    fruit   => [qw{    a n v }],    # adjective noun verb
    time    => [qw{    a n v }],    

    like    => [qw{ p  a n v }],    # like is also a preposition

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

#
# set up the grammar handling ambiguity with input model
#
my $mp_IM = Marpa::Easy->new({
    rules => $grammar,
    default_action => 'sexpr',
    ambiguity => 'input_model',
});

#
# set up the grammar handling ambiguity with ambiguous tokens
#
my $mp_AT = Marpa::Easy->new({
    rules => $grammar,
    default_action => 'sexpr',
    ambiguity => 'tokens',
});

isa_ok $mp_IM, 'Marpa::Easy';

# we know we want multiple parses, hence the array context of ->parse
my @input_model_parses = $mp_IM->parse( tokenize($sentence) );
my @tokens_parses      = $mp_AT->parse( tokenize($sentence) );

# expected
my $expected_IM = <<EOT;
(S (C (NP (adjective time) (noun flies)) (VP (V like) (O (NP (article an) (noun arrow))))) (comma ,) (conjunction but) (C (NP (adjective fruit) (noun flies)) (VP (V like) (O (NP (article a) (noun banana))))))
(S (C (NP (adjective time) (noun flies)) (VP (V like) (O (NP (article an) (noun arrow))))) (comma ,) (conjunction but) (C (NP (noun fruit)) (VP (V flies) (A (PP (preposition like) (NP (article a) (noun banana)))))))
(S (C (NP (noun time)) (VP (V flies) (A (PP (preposition like) (NP (article an) (noun arrow)))))) (comma ,) (conjunction but) (C (NP (adjective fruit) (noun flies)) (VP (V like) (O (NP (article a) (noun banana))))))
(S (C (NP (noun time)) (VP (V flies) (A (PP (preposition like) (NP (article an) (noun arrow)))))) (comma ,) (conjunction but) (C (NP (noun fruit)) (VP (V flies) (A (PP (preposition like) (NP (article a) (noun banana)))))))
EOT

my $expected_AT = <<EOT;
(S (C (NP (adjective (a time)) (noun (n flies))) (VP (V (v like)) (O (NP (article an) (noun (n arrow)))))) (comma ,) (conjunction but) (C (NP (adjective (a fruit)) (noun (n flies))) (VP (V (v like)) (O (NP (article a) (noun (n banana)))))))
(S (C (NP (adjective (a time)) (noun (n flies))) (VP (V (v like)) (O (NP (article an) (noun (n arrow)))))) (comma ,) (conjunction but) (C (NP (noun (n fruit))) (VP (V (v flies)) (A (PP (preposition (p like)) (NP (article a) (noun (n banana))))))))
(S (C (NP (noun (n time))) (VP (V (v flies)) (A (PP (preposition (p like)) (NP (article an) (noun (n arrow))))))) (comma ,) (conjunction but) (C (NP (adjective (a fruit)) (noun (n flies))) (VP (V (v like)) (O (NP (article a) (noun (n banana)))))))
(S (C (NP (noun (n time))) (VP (V (v flies)) (A (PP (preposition (p like)) (NP (article an) (noun (n arrow))))))) (comma ,) (conjunction but) (C (NP (noun (n fruit))) (VP (V (v flies)) (A (PP (preposition (p like)) (NP (article a) (noun (n banana))))))))
EOT

# tests
is  join("\n", map { $mp_IM->show_parse_tree($_) } sort @input_model_parses) . "\n", 
    $expected_IM, 
    "ambiguous sentence ‘$sentence’ parsed using alternate()/earleme_complete() input model";


is  join("\n", map { $mp_AT->show_parse_tree($_) } sort @tokens_parses) . "\n", 
    $expected_AT, 
    "ambiguous sentence ‘$sentence’ parsed using ambiguous tokens";

done_testing;
