# capturing subrules
greeting ::= (hello: 'Hi' | 'Hello' | 'hi' | 'hello' ) (comma: ',')? (name: world | me)? 
%{
    $hello, $comma, $name
%}


# ','?
    # this works:
      s ::= x ( (',' x) | (','? conj x) )*

    # this doesn't:
        greeting ::= ('Hi' | 'Hello' | 'hi' | 'hello' ) ','? (world | me)? 
            %{ 
#                say Dump \@_;
                shift;
                my ($hello, $comma, $name) = @_;
                my %name_to_answer = ( world => 'parser', parser => 'world' );
                if ($comma){
                    join ' ', "$hello,", $name_to_answer{$name};
                }
                elsif ($name eq "parser") {
                    "$hello me? $hello you!"
                }
                else {
                    "$hello $name? How come?"
                }
            %}
        world ::= 'world'
        me    ::= 'parser'
        comma ::= ','
