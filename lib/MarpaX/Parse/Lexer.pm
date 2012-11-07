package MarpaX::Parse::Lexer;

use MarpaX::Parse::Grammar;

sub new{

    my $class = shift;
    my $grammar = shift;
  
    my $self = {};
    bless $self, $class;
    $self->{grammar} = $grammar;
    $self;
}

# TODO: pluggable lexer (Parse::Flex, etc.)
sub lex
{
    my $self = shift;
    
#    say "# lexing: ", Dump \@_;
    
    my $input = shift;
    
    my $lex = shift || $self->{grammar}->{lexer_rules};

    #$self->set_option('input', $input);
    #$self->show_option('input');
   
    #$self->show_option('rules');
    #$self->show_option('symbols');
    #$self->show_option('terminals');
    #$self->show_option('literals');

    #$self->show_option('lexer_rules');
    
    # TODO: add 'default' rule (as in given/when) to apply when 
    # none of the other rules matched (for BNF parsing)

    # make regexes of strings and qr// in strings leaving regexes proper as is
    my $lex_re = {};
    for my $l (keys %$lex){
#say "terminal: <$l>";    
        my $l_re = $l;
        if ($l =~ /^\Q(?^:\E/){
#say "regex: $l";
        }
        elsif ($l =~ m{^qr/.*?/\w*$}){
#say "qr in string: $l";
            $l_re = eval $l;
        }
        else{
#say "string: $l";
            $l_re = qr/\Q$l\E/;
        }
        $lex_re->{$l_re} = $lex->{$l};
    }
    $self->{lexer_regexes} = $lex_re;
    chomp $self->{lexer_regexes};
#    $self->show_option('lexer_regexes');

    my $tokens = [];
    my $i;

    my $max_iterations = 1000000;

#    $self->show_option('show_input');
        
    while ($i++ < $max_iterations){
        # trim input start
        $input =~ s/^\s+//s;
        $input =~ s/^\s+//s;
#say "# input: <$input>";
        # match reach regex at string beginning
        my $matches = {};
        for my $re (keys %$lex_re){
            if ($input =~ /^($re)/){
#say "match: $re -> '$1'";
                $matches->{$1}->{$lex_re->{$re}} = undef;
            }
        }
#say Dump $matches;
        # no matches means the end of lexing
        my @matches = keys %$matches;
        last unless @matches;
        # sort matches by length (longest first)
        @matches = sort { length $b <=> length $a } @matches;
        # get longest match(es)
        my $max_len = length $matches[0];
        my @max_len_tokens = grep { length $_ eq $max_len } @matches;
        # set [ token_name, token_value ] pairs
        my @matched_tokens;
        # get token names of token values
        for my $token_value (@max_len_tokens){
            my @token_names = keys %{ $matches->{$token_value} };
            for my $token_name (@token_names){
    #            say "$token_name, $token_value";
                push @matched_tokens, [ $token_name, $token_value ];
            }
        }
        if (@matched_tokens > 1){ # ambigious tokens
            push @$tokens, \@matched_tokens;
        }
        else{
            push @$tokens, $matched_tokens[0];
        }

        # trim the longest match from the string start
        $input =~ s/^\Q$max_len_tokens[0]\E//;
    }
    warn "This must have been an infinite loop: maximum interations count $max_iterations exceeded" if $i > $max_iterations;
    push @$tokens, [ '::any', $input ] if $input;
    
    $self->{tokens} = $tokens;
    
    return $tokens;
}


1;

