package Marpa::Easy::EBNF;

use 5.010;
use strict;
use warnings;

use YAML;

use Eval::Closure;

sub new
{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

my $action_prolog = q{
    # start action prolog
    # imports
    use 5.010; use strict; use warnings; use YAML;
    # rule parts and signature
    my ($rule_lhs, @rule_rhs) = $Marpa::R2::Context::grammar->rule($Marpa::R2::Context::rule);
    my $rule_signature = $rule_lhs . ' -> ' . join ' ', @rule_rhs;
    # end action prolog
};

my $ebnf_rules = [
    
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
    
    { lhs => 'rhs', rhs => ['term'], min => 1, separator => '|', proper => 1 },
    { lhs => 'term', rhs => ['factor'], min => 1, proper => 1 },
    [ factor => [qw(symbol)] ], 
    [ factor => [qw(    '(' rhs ')'  action? )] ], 
    [ factor => [qw(    '(' rhs ')?' action? )] ], 
    [ factor => [qw(    '(' rhs ')*' action? )] ], 
    [ factor => [qw(    '(' rhs ')+' action? )] ], 

    [ symbol     => [qw( identifier )] ],
    [ symbol     => [qw( literal    )] ],

];

sub rules { $ebnf_rules }

my $balanced_terminals = {
    '%{.+?%}' => 'action',
    '".+?"' => 'literal',
    "'.+?'" => 'literal',
};
my $balanced_terminals_re = join '|', keys %$balanced_terminals;

my $literal_terminals = {
    '::=' => '::=',
    '|' => '|',
};
my $literal_terminals_re = join '|', map { quotemeta } keys %$literal_terminals;
# and the rest must be symbols

sub lex_ebnf_text
{
    my $self = shift;
    
    my $ebnf_text = shift;
    
    my $tokens = [];
    
#    say $ebnf_text;
    
    # trim ebnf text
    $ebnf_text =~ s/^\s+//s;
    $ebnf_text =~ s/\s+$//s;

    # remove comments at line start and trim
    $ebnf_text =~ s/^#.*?$//mg;
    $ebnf_text =~ s/^\s+//s;
    $ebnf_text =~ s/\s+$//s;
    
    # split on balanced
    for my $on_balanced (split /($balanced_terminals_re)/s, $ebnf_text){
        
        # trim
        $on_balanced =~ s/^\s+//s;
        $on_balanced =~ s/\s+$//s;
#        say "on balanced: <$on_balanced>";

        # find balanced terminals
        if ($on_balanced =~ /^$balanced_terminals_re$/s){
            for my $re (keys %$balanced_terminals){
                if ($on_balanced =~ m/^$re$/s){
#                    say $balanced_terminals->{$re}, ": ",$on_balanced;
                    push @$tokens, [ $balanced_terminals->{$re}, $on_balanced ];
                }
            }      
        }
        else{

            # remove comments and trim
            $on_balanced =~ s/#.*?$//mg;
            $on_balanced =~ s/^\s+//s;
            $on_balanced =~ s/\s+$//s;
            
            # split on literals
            for my $on_literal (split /($literal_terminals_re)/s, $on_balanced){
                $on_literal =~ s/^\s+//s;
                $on_literal =~ s/\s+$//s;
#                say "on literal: <$on_literal>";
                # find literal terminals
#                say "on literal: <$on_literal>";
                if ($on_literal =~ /^$literal_terminals_re$/){
                    for my $re (keys %$literal_terminals){
                        if ($on_literal =~ m/^\Q$re\E$/){
#                            say $literal_terminals->{$re}, ": ",$on_literal;
                            push @$tokens, [ $literal_terminals->{$re}, $on_literal ];
                        }
                    }      
                }
                else{
                    for my $identifier (split /\s+/s, $on_literal){
                        $identifier =~ s/^\s+//s;
                        $identifier =~ s/\s+$//s;
#                        say "identifier: $identifier";
                        push @$tokens, [ 'identifier', $identifier ];
                    }
                }
            }
        }
    }

#    say "# ebnf tokens ", Dump $tokens;
    return $tokens; 
}

1;
