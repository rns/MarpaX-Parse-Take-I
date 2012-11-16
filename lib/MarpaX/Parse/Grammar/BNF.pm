package MarpaX::Parse::Grammar::BNF;

use 5.010;
use strict;
use warnings;

use YAML;

use Eval::Closure;
use Clone qw{clone};

our @ISA = qw(MarpaX::Parse::Grammar);

use MarpaX::Parse::Parser;
use MarpaX::Parse::Lexer::BNF;

# BNF parser rules, see below
my $action_prolog = q{
    # start action prolog
    # imports
    use 5.010; use strict; use warnings; use YAML;
    # rule parts and signature
    my ($rule_lhs, @rule_rhs) = $Marpa::R2::Context::grammar->rule($Marpa::R2::Context::rule);
    my $rule_signature = $rule_lhs . ' -> ' . join ' ', @rule_rhs;
    # end action prolog
};

my $bnf_rules = [
    
    [ grammar => [qw( production+ )], 
      sub {
        shift;
        my $rules = [];
        my @productions = @_;
        for my $production (@productions){
            for my $Marpa_rules (@$production){
#                say "# production rules: ", Dump $Marpa_rules;
                push @$rules, @$Marpa_rules;
            }
        }
#        say Dump \@_;
#        \@_;
        $rules;
      } 
    ],

    [ production => [qw( lhs ::= rhs )],
      sub {
        shift;

#        say "\n#\n# production -> lhs ::= rhs\n#\n", Dump \@_;
        my ($lhs, undef, $rhs) = @_;
#        say ref $rhs;
        my $rules = [];
        
#        say "# production/lhs:\n", $lhs;
#        say "# production/rhs:\n", Dump $rhs;
        for my $rule (@$rhs){ # [ { symbols => [], action => $ } ]
#            say "# production/rhs/rule (", ref $rule, "):\n", Dump $rule;
            # extract symbols  and action
            my ($symbols, $action) = map { $rule->{$_} } qw{ symbols action };
#            say "# production/rhs/rule/symbols:\n", Dump $symbols;
            $symbols = ref $symbols eq "ARRAY" ? $symbols : [ $symbols ];
            # add Marpa rules
            my $Marpa_rule = {
                lhs => $lhs,
                rhs => $symbols,
            };
            if (defined $action) {
#                say "# production/rhs/rule/action:\n", $action;
                # setup anonsub text
                $action =~ s/^%{/sub{\n$action_prolog\n/;
                $action =~ s/%}$/}/;
                # setup closure
                my $closure = eval_closure(
                    source => $action,
                    description => 'action of rule ' . 
                        $Marpa_rule->{lhs} . ' -> ' . join ' ', @{ $Marpa_rule->{rhs} },
                );
                # add action
                $Marpa_rule->{action} = $closure;
            }
            else {
#                say "# No action";
            }
            push $rules, $Marpa_rule;
        }

#        \@_;
        $rules;
      }
    ],
    
    [ lhs => [qw( symbol )] ],
    
    { lhs => 'rhs', rhs => ['rule'], min => 1, separator => '|', proper => 1, action => sub {
        shift;
        \@_;
    } },

    [ rule       => [qw( symbols )], sub {
        { symbols => $_[1] }
    } ],
    [ rule       => [qw( symbols action )], sub {
        { symbols => $_[1], action => $_[2] }
    } ],
    
    [ symbols    => [qw( symbol+ )] ],
    
    [ symbol     => [qw( identifier )] ],
    [ symbol     => [qw( literal    )] ],

];

my $options = {

    # stage: BNF grammar parser initialization
    show_bnf_parser_tokens => undef,
    show_bnf_parser_rules => undef,    
    show_bnf_parser_closures => undef, 
    show_parsed_bnf_rules => undef,    
    
    # stage: parsing the BNF grammar text set as <rules> option
    show_bnf_tokens => undef,
    show_bnf_rules => undef,    
    show_bnf_closures => undef, 
};

# construction
sub new
{
    my $class = shift;
    
    my $options = shift;
    
    #
    # TODO: build $bnf_rules only once (package variable $bnf_parser)
    # ditto for EBNF
    #
    my $self = $class->SUPER::new({ 
        rules          => $bnf_rules,
        default_action => 'MarpaX::Parse::Tree::AoA',
    });

# begin _make_rules(text)
        
    # save original rules for possible merging
    my $bnf_text = $options->{rules};

    # parse bnf
    my $bnf_tokens = MarpaX::Parse::Lexer::BNF->new->lex($bnf_text);
    
    # save bnf tokens
    # TODO: this needs to $self->{o}->set('bnf_tokens' ...
#    $self->set_option('bnf_tokens', join "\n", map { join ': ', @$_ } @$bnf_tokens);

    # show BNF tokens if the option is set
    # TODO: this needs to $self->{o}->show('bnf_tokens' ...
    # say "# BNF tokens:\n", $self->show_bnf_tokens if $self->{show_bnf_tokens};
#    $self->show_option('bnf_tokens');
    
    # TODO: show bnf parser tokens, rules, and closures if the relevant options are set
    
    # parse BNF tokens to Marpa::R2 rules
    $options->{rules} = MarpaX::Parse::Parser->new({ 
        grammar => $self->grammar, 
        default_action => $self->{default_action}, 
        closures => $self->{closures},
    })->parse($bnf_tokens);

# end _make_rules    

    $self->build($options);
    
    # restore rules for possible merging
    $self->{options}->{rules} = $bnf_text;
    
    bless $self, $class;
}

sub merge_token_rules { 
    
    my $self = shift;

    my $token_rules = shift;

    say "merging $token_rules";

    # get initial options
    my $options = $self->{options};

    say ref $self;
    say ref $token_rules;
    say ref $options->{rules};
    
    # $token_rules and $options->{rules} need to be both texts
    if (ref $token_rules eq "" and ref $options->{rules} eq ""){
        # merge texts
        say "merging $token_rules with $options->{rules}";
        $options->{rules} .= $token_rules;
    }
    
    # rebuild
    $self->build($options);
}

# parse BNF to what will become Marpa::R2 rules after transformation 
# (extraction of closures, adding rules for quantifiers, extraction of lexer rules, etc.)
sub rules { $_[0]->{rules} }

1;
