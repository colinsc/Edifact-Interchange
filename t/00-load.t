#!perl -T

use Test::More tests => 5;

BEGIN {
    use_ok( 'Edifact::Interchange' ) || print "Bail out!  ";
    use_ok( 'Edifact::Message' ) || print "Bail out!  ";
    use_ok( 'Edifact::Message::LineItem' ) || print "Bail out!";
}

my $obj = Edifact::Interchange->new;
isa_ok( $obj, 'Edifact::Interchange');
can_ok( $obj, qw( messages ));

diag( "Testing Edifact::Interchange $Edifact::Interchange::VERSION, Perl $], $^X" );
