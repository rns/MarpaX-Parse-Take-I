package MarpaX::Parse;

use 5.010;
use strict;
use warnings;

use Carp qw{cluck};

use YAML;

use Marpa::R2;

use MarpaX::Parse::Grammar;
use MarpaX::Parse::Grammar::BNF;
use MarpaX::Parse::Grammar::EBNF;

use Encode qw{ encode is_utf8 };

use XML::Twig;

use Clone qw(clone);

=pod distro module layout

# 
MarpaX::Parse
    
    grammar
    
    sub new{
        ref $rules eq 
            "ARRAY" # Marpa::R2::Grammar
            "HASH"
            "" = textual grammar: 
            first try to parse it with BNF; if this fails, then with EBNF 
            to have $rules which will be fed to MarpaX::Parse::Grammar       

    sub grammar {

    sub recognition_failure {
    sub parse{
    sub show_parse_forest{
    sub show_parse_tree{

MarpaX::Parse::Grammar
    
    grammar = Marpa::R2::Grammar
    
    sub _build {
    
    sub _extract_start_symbol
    sub _set_default_action
    sub _closures_to_actions
    sub _quantifiers_to_rules   # if there are quantifiers, e.g. symbol+
    sub _rule_signature
    sub _action_name

    sub _extract_terminals
    sub _extract_symbols

    sub merge_token_rules {     # add rules to the grammar and re-build()


    MarpaX::Parse::Grammar::BNF->can(build)
    MarpaX::Parse::Grammar::EBNF->can(build)
   
MarpaX::Parse::NLP
    
    5W+H+Vs
    
    lex input as for NM
    tokenize ($input, $features_provider)
        augment grammar
    parse
    
    MarpaX::Parse::NLP::Grammar
        MarpaX::Parse::RU::Grammar
        MarpaX::Parse::EN::Grammar
#
MarpaX::Parse::Util -- Debug::Msg
    
    sub _dump {

MarpaX::Parse::Options
    
    new (MarpaX::Parse)
    
    sub _token_string {
    sub set_option{
    sub get_option{
    sub comment_option {
    sub show_option{
    sub show_parsed_bnf_rules      
    sub show_transformed_bnf_rules 
    sub show_closures              
    sub show_bnf_tokens            
    sub show_bnf_rules             
    sub show_bnf_closures          
    sub show_tokens                
    sub show_rules                 
    sub show_symbols               
    sub show_terminals             
    sub show_lexer_rules           
    sub show_literals              
    sub show_lexer_regexes         
    sub show_recognition_failures  

BNF/EBNF
    sub _bnf_to_rules
    sub _ebnf_to_rules

MarpaX::Parse::Parser # MarpaX::Parse -> MarpaX::Dakini MarpaX::Marp->marp
    sub parse
    sub merge_token_rules
    sub recognition_failure

=cut

=head1 DESCRIPTION

=cut

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

sub new{

    my $class = shift;
    my $options = shift;
    
    my $self = {};
    bless $self, $class;
    
    # TODO: extract recognizer options and pass them to parser
    my @recognizer_options = qw{
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

    my $grammar;
    # array ref means we have rules
    if (ref $options->{rules} eq "ARRAY"){  
        # set up and save the grammar
        my $grammar = MarpaX::Parse::Grammar->new(clone $options);
    }
    # scalar means we have a BNF or EBNF grammar we need to parse to get rules
    elsif (ref $options->{rules} eq ""){
        say "rules is scalar";        
        # try bnf first
        eval {
            $grammar = MarpaX::Parse::Grammar::BNF->new($options->{rules});
        } or die "can't parse: $@";
        # now try EBNF
        if ($@){
            my $bnf_parsing_errors = $@;
            # TODO: catch EBNF parsing errors, e.g. := not ::=
            eval {
                $grammar = MarpaX::Parse::Grammar::EBNF->new($options->{rules});
            };
            if ($@){
                # TODO: return parsing errors somehow 
                my $ebnf_parsing_errors = $@;
                $@ = $bnf_parsing_errors . $ebnf_parsing_errors;
                return;
            }
            else {
                # return parsed EBNF rules
            }
        }
    }
    # everything else
    else {
        die "Don't know what to do with rules in these options:", Dump $options;
    }
    
    # save grammar
    $self->{grammar} = $grammar;
    
    # set up parser
    my $p = MarpaX::Parse::Parser->new( $grammar );

    return $self;
}

# =========
# accessors
# =========

sub grammar { $_[0]->{grammar} }

sub parse {

    my $self = shift;
    
    my $input = shift;

    return $self->{p}->parse($input);
}

1;

__END__
