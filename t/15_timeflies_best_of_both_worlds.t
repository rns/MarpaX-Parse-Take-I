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

# SENT for sentence, CLAU for clause, OBJT for object, ADJN for adjunct
my $grammar = q{
    
    SENT  ::= CLAU | CLAU PUNC? CONJ CLAU
    
    CLAU  ::= NP VP
    
    OBJT  ::= NP
    
    NP    ::= DET? ADJ? NOUN

    VP    ::= VERB OBJT | VERB ADJN
    ADJN  ::= PP                  
    PP    ::= PREP NP

};

# part-of-speech (pos) data based on "A Universal Part-of-Speech Tagset" 
# by Slav Petrov, Dipanjan Das and Ryan McDonald
# for more details: http://arxiv.org/abs/1104.2086
# http://code.google.com/p/universal-pos-tags/source/browse/trunk/README
# except that . changed for PUNC in ". - punctuation"
my $pos = {

    ','     => [qw{ PUNC                        }],    # commas, periods, etc.

    a       => [qw{      DET                    }],    # indefinite article
    an      => [qw{      DET                    }],

    arrow   => [qw{             ADJ NOUN        }],    
    banana  => [qw{             ADJ NOUN        }],
    but     => [qw{      CONJ                   }],    # conjunction
    flies   => [qw{                 NOUN VERB   }],    
    fruit   => [qw{             ADJ NOUN VERB   }],    # adjective noun verb
    time    => [qw{             ADJ NOUN VERB   }],    

    like    => [qw{      PREP   ADJ NOUN VERB   }],    # like is also a preposition

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
        $token_rules{$_} = undef for map { join ' ::= ', @$_ } @$token;
    }
    # unambiguous
    else{ 
        $token_rules{join ' ::= ', @$token} = undef;
    }
}
my $token_rules = join "\n", sort keys %token_rules;

#say $grammar . $token_rules;

#
# set up the grammar handling ambiguity with input model
#
my $mp_IM = Marpa::Easy->new({
    rules => $grammar . $token_rules,
    default_action => 'sexpr',
    ambiguity => 'input_model',
});
#say $mp_IM->show_rules;
isa_ok $mp_IM, 'Marpa::Easy';

my @input_model_parses = $mp_IM->parse( [ map { [ $_, $_ ] } grep { $_ } map { s/^\s+//; s/\s+$//; $_ } split /(\w+)/, $sentence ] );

# expected
my $expected_IM = <<EOT;
(SENT (CLAU (NP (ADJ time) (NOUN flies)) (VP (VERB like) (OBJT (NP (DET an) (NOUN arrow))))) (PUNC ,) (CONJ but) (CLAU (NP (ADJ fruit) (NOUN flies)) (VP (VERB like) (OBJT (NP (DET a) (NOUN banana))))))
(SENT (CLAU (NP (ADJ time) (NOUN flies)) (VP (VERB like) (OBJT (NP (DET an) (NOUN arrow))))) (PUNC ,) (CONJ but) (CLAU (NP (NOUN fruit)) (VP (VERB flies) (ADJN (PP (PREP like) (NP (DET a) (NOUN banana)))))))
(SENT (CLAU (NP (NOUN time)) (VP (VERB flies) (ADJN (PP (PREP like) (NP (DET an) (NOUN arrow)))))) (PUNC ,) (CONJ but) (CLAU (NP (ADJ fruit) (NOUN flies)) (VP (VERB like) (OBJT (NP (DET a) (NOUN banana))))))
(SENT (CLAU (NP (NOUN time)) (VP (VERB flies) (ADJN (PP (PREP like) (NP (DET an) (NOUN arrow)))))) (PUNC ,) (CONJ but) (CLAU (NP (NOUN fruit)) (VP (VERB flies) (ADJN (PP (PREP like) (NP (DET a) (NOUN banana)))))))
EOT

# stringify the parse trees
my $trees = join("\n", map { $mp_IM->show_parse_tree($_) } sort @input_model_parses);

# test
unless (
    is $trees . "\n", 
    $expected_IM, 
    "parsed '$sentence'"
) {
    say $trees;
}

done_testing;
