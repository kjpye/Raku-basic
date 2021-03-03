#!/usr/bin/env raku

#use Grammar::Tracer;

$*OUT.out-buffer = False;
$*ERR.out-buffer = False;

my @lines;
my $line-number;
my %variables;
my %string-variables;

my %functions = (
    'int' => { $^a.Int },
    'rnd' => { $^a.rand },
);
my @function = %functions.keys;

my %muloperators = (
    '*' => { $^a * $^b },
    '/' => { $^a / $^b },
);
my @mulopers = %muloperators.keys;

my %addoperators = (
    '+' => { $^a + $^b },
    '-' => { $^a - $^b },
);
my @addopers = %addoperators.keys;

my %compoperators = (
    '='  => { ($^a cmp $^b) == Same }
    '<>' => { $^a != $^b }
    '<'  => { $^a <  $^b }
    '<=' => { $^a <= $^b }
    '>'  => { $^a >  $^b }
    '>=' => { $^a >= $^b }
);
my @compopers = %compoperators.keys;

sub assign-variable($var, $value) {
    %variables{$var} = ($var.substr(*-1, 1) eq '$') ?? ~$value !! +$value;
}

grammar basic {
    regex TOP { <statement>* % ':' }
    regex statement {
        | <comment>
        | <endstatement>
        | <gotostatement>
        | <printstatement>
        | <assignmentstatement>
        | <ifstatement>
        | <inputstatement>
    }
    rule comment { :i 'rem' .* }
    rule endstatement { :i 'end' { say "Exiting"; exit 0; } }
    rule gotostatement { :i 'goto' (\d+) { $line-number = +$0; } }
    rule printstatement { :i 'print' <stringlist> { say $/<stringlist>.made; } }
    rule assignmentstatement { <variable> '=' <expression>
                               {
#                                   say "Setting " ~ $/<variable>.made ~ ' to ' ~ $/<expression>.made;
                                   %variables{$/<variable>.made} = $/<expression>.made;
                                   # dd %variables;
                               }
                             }
    rule ifstatement { :i 'if' <expression> 'then' <linenumber>
                          {
#                          say "ifstatement: conditional is {+$/<expression>.made}";
                              $line-number = +$/<linenumber>.made if +$/<expression>.made;
                          }
                     }

    rule inputstatement { :i 'input' <string> ';' <variable>
        {
            print ~$/<string>.made ~ ': ';
            my $input = $*IN.get();
            assign-variable(~$/<variable>.made, $input);
#            dd %variables;
        }

    }

    token linenumber { (\d+) { make +$0; } }
    token slvalue { <variable> { my $val = ~%variables{$/<variable>.made}; make $val; } }
    rule stringlist { <stringpart>* % ';'
                      {
#                          dd $/<stringpart>;
                          my $s = ($/<stringpart>.map: { .made }) .join(' ');
#                          dd $s;
                          make $s;
                      }
                    }
    rule stringpart {
         | <string> { make $/<string>.made; }
         | <slvalue> { make $/<slvalue>.made; }
    }   
    token string { | '"' (<-["]>*) '"'        { make ~$0; }
#                   | $<var>=(<variable>)      { make ~%variables{$/<var>.lc}; }
                   | :i 'tab' '(' (\d+) ')'   { make ' ' x $0; }
                 }

    token variable { (<alpha> '$'?) { make $0.lc } }

    rule expression {
        <add-expr>* % @compopers
        {
#            dd $/<add-expr>;
            my $value = $/<add-expr>[0].made;
            if +$/<add-expr> > 1 {
#                say "Multiple terms: {+$/<add-expr>}";
                for 1 ..^ +$/<add-expr> -> $i {
#                    say "term $i";
#                    dd $/<add-expr>[$i].from;
#                    dd $/<add-expr>[$i].pos;
                    given $/<add-expr>[0].orig.substr($/<add-expr>[$i-1].pos, $/<add-expr>[$i].from - $/<add-expr>[$i-1].pos) {
                        $value = %compoperators{$_}($value, $/<add-expr>[$i].made);
                    }
#                    dd $value;
                }
            }
            make $value;
        }
    }
    
    rule add-expr {
        <mul-expr>* % @addopers
        {
#            dd $/<mul-expr>;
            my $value = $/<mul-expr>[0].made;
            if +$/<mul-expr> > 1 {
#                say "Multiple terms: {+$/<mul-expr>}";
                for 1 ..^ +$/<mul-expr> -> $i {
#                    say "term $i";
#                    dd $/<mul-expr>[$i].from;
#                    dd $/<mul-expr>[$i].pos;
                    given $/<mul-expr>[0].orig.substr($/<mul-expr>[$i-1].pos, $/<mul-expr>[$i].from - $/<mul-expr>[$i-1].pos) {
                        $value = %addoperators{$_}($value, $/<mul-expr>[$i].made);
                    }
#                    dd $value;
                }
            }
            make $value;
        }
    }

    rule mul-expr {
        <term>* % @mulopers
        {
#            dd $/<term>;
            my $value = $/<term>[0].made;
            if +$/<term> > 1 {
#                say "Multiple terms: {+$/<term>}";
                for 1 ..^ +$/<term> -> $i {
#                    say "term $i";
#                    dd $/<term>[$i].from;
#                    dd $/<term>[$i].pos;
                    given $/<term>[0].orig.substr($/<term>[$i-1].pos, $/<term>[$i].from - $/<term>[$i-1].pos) {
                        $value = %muloperators{$_}($value, $/<term>[$i].made);
                    }
#                    dd $value;
                }
            }
            make $value;
        }
    }
    
    regex term {
        | <variable>                        { make %variables{$/<variable>.made}; }
        | (\d+ [ '.' \d*]? )                { make +$0; }
        | <string>                          { make $/<string>.made; }
        | :i $<function>=(@function) '(' <expression> ')' {
#            say "function: {~$/<function>}";
            make %functions{~$/<function>.lc}(+$/<expression>.made);
          }
        | '(' <expression> ')'              { make $/<expression>.made; }
    }
}

$line-number = 1;
for lines() -> $line is copy {
    if $line ~~ s/^(\d+)\s*// {
        $line-number = +$0;
    }
    @lines[$line-number++] = $line;
}

say "Executing...";

$line-number = 1;

loop {
    if my $line = @lines[$line-number++] {
#        say "{$line-number - 1} $line";
        if basic.parse($line) {
            # successfully executed the line
        } else {
            say "Unknown statement $line" unless basic.parse($line);
            exit(1);
        }
    }
}
