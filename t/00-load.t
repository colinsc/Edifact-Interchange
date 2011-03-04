#!perl -T

use Test::More tests => 2;

BEGIN {
    use_ok( 'Edifact::Interchange' ) || print "Bail out!
";
    use_ok( 'Edifact::Message' ) || print "Bail out!
";
}

diag( "Testing Edifact::Interchange $Edifact::Interchange::VERSION, Perl $], $^X" );
