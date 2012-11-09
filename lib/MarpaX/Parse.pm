package MarpaX::Parse;

use 5.010;
use strict;
use warnings;

use YAML;

use Marpa::R2;

use MarpaX::Parse::Grammar;
use MarpaX::Parse::Grammar::BNF;
use MarpaX::Parse::Grammar::EBNF;

use MarpaX::Parse::Tree;

use Clone qw{clone};

#
# Any BNF grammar passed to MarpaX::Parse by setting <rules> to scalar 
# is parsed by the BNF parser with rules set in MarpaX::Parse::BNF
#
# BNF parser tokens, rules and closures are shown by show_bnf_parser_* options
# 
# tokens, rules and closures of the BNF grammar passed to MarpaX::Parse are shown
# by show_bnf_* options
# 
# Finally, tokens, rules and closures of the input parsed by the BNF grammar passed 
# to MarpaX::Parse are shown # by show_* options
#

my @Marpa_recognizer_options = qw{
    closures
    end
    event_if_expected
    max_parses
    ranking_method
    too_many_earley_items
    trace_actions
    trace_file_handle
    trace_terminals
    trace_values
    warnings
};

my @Marpa_grammar_options = qw{
    action_object
    actions
    default_action
    default_empty_action
    inaccessible_ok
    infinite_action
    rules
    start
    symbols
    terminals
    trace_file_handle
    unproductive_ok
    warnings
};

sub new{

    my $class = shift;
    my $options = shift;
    
    ref $options eq "HASH" or die "options must be a HASH; got $options instead";
    
    my $self = {};
    
    # extract recognizer options to pass them to parser
    my $recognizer_options = {};
    for my $o (@Marpa_recognizer_options, qw{
        ambiguity 
        recognition_failure_sub 
        show_recognition_failures
        }
        ){
        if (exists $options->{$o}){
            $recognizer_options->{$o} = $options->{$o};
            delete $options->{$o};
        }
    }

    # the rest is assumed to be the grammar options
    my $grammar_options = $options;
    
#    say "# new", ref $self, Dump $grammar_options;
    
    my $grammar;
    # array ref means we have rules
    if (ref $grammar_options->{rules} eq "ARRAY"){  
        # set up and save the grammar
        $grammar = MarpaX::Parse::Grammar->new($grammar_options);
    }
    # scalar means we have a BNF or EBNF grammar we need to parse to get rules
    elsif (ref $options->{rules} eq ""){
        # try bnf first
        eval {
            $grammar = MarpaX::Parse::Grammar::BNF->new(clone $grammar_options);
        };
        # now try EBNF
        if ($@){
            my $bnf_parsing_errors = $@;
            # TODO: catch EBNF parsing errors, e.g. := not ::=
            eval {
                $grammar = MarpaX::Parse::Grammar::EBNF->new(clone $grammar_options);
            };
            if ($@){
                # TODO: return parsing errors somehow 
                my $ebnf_parsing_errors = $@;
                $@ = "\n# bnf parsing error(s)\n"  .  $bnf_parsing_errors . 
                       "# ebnf parsing error(s)\n" . $ebnf_parsing_errors;
                return;
            }
        }
    }
    # everything else
    else {
        die "Don't know what to do with rules in these options:", Dump $options;
    }
    
    # save grammar
    $self->{g} = $grammar;
    
    # set up parser
    $recognizer_options->{grammar}        = $grammar->grammar;
    $recognizer_options->{default_action} = $grammar->{default_action};
    $recognizer_options->{closures}       = $grammar->{closures};
    $self->{p} = MarpaX::Parse::Parser->new($recognizer_options);
    
    bless $self, $class;
}

# TODO: compatibility-only, remove
sub show_rules{
    my $r = $_[0]->{g}->show_rules;
    chomp $r;
    $r;
}

# =========
# accessors
# =========

sub grammar { $_[0]->{g}->grammar }

sub parse {

    my $self = shift;
    
    my $input = shift;

    return $self->{p}->parse($input);
}

1;

__END__
