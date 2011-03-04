package Edifact::Message;

use warnings;
use strict;
use 5.010;
use Carp;

=head1 NAME

Edifact::Message - The great new Edifact::Message!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Parses an individual Edifact message
Message objects are instantiated by Edifact::Interchange and an array
of them is returned in its messages function
   $interchange->parse($incoming);
   my $m_array = $interchange->messages();
   for my $msg (@{$m_array}) {
      ...retrieve message data
   }


=head1 SUBROUTINES/METHODS

=head2 new

Called by Edifact::Interchange to instantiate a new Message
object. The caller passes the header fields with the 
reference number identifier and message type

=cut

sub new {
    my $class      = shift;
    my $hdr_fields = shift;

    my $self = {
        ref_num            => $hdr_fields->[0]->[0],
        message_identifier => $hdr_fields->[1],
        reference          => [],
        addresses          => [],
        lines              => [],
        segment_group      => 0,
        type               => $hdr_fields->[1]->[0],
    };

    bless $self, $class;
    return $self;
}

=head2 add_segment

Process the next data segment

=cut

sub add_segment {
    my $self     = shift;
    my $tag      = shift;
    my $data_arr = shift;
    given ($tag) {
        when ('BGM') {
            $self->{bgm_data} = $data_arr;
        }
        when ('DTM') {    # TODO can occur in different segment_groups
            my ( $qualifier, $date, $format ) = @{ $data_arr->[0] };
            if ( $self->{segment_group} == 0 ) {    # message header
                    #TBD standard allows 35 repeats
                if ( $qualifier == 137 ) {
                    $self->{message_date} = $date;
                } elsif ( $qualifier == 36 ) {
                    $self->{expirty_date} = $date;
                }
            } elsif ( $self->{segment_group} == 27 ) {
                $self->{lines}->[-1]->{datetimeperiod} = $data_arr;
            }
        }
        when ('RFF') {
            if ( $self->{segment_group} == 0 ) {
                $self->{segment_group}     = 1;    # 1 mandatory occurence
                $self->{message_reference} = {
                    qualifier => $data_arr->[0]->[0],
                    number    => $data_arr->[0]->[1],
                };
            } elsif ( $self->{segment_group} == 11 )
            {                                      # ref to an address (SG12)
                $self->{addresses}->[-1]->{RFF} = {
                    qualifier => $data_arr->[0]->[0],
                      number  => $data_arr->[0]->[1],
                };

            } elsif ( $self->{segment_group} == 27 )
            {                                      # ref to an address (SG12)
                push @{ $self->{lines}->[-1]->{item_reference} }, $data_arr;
            } else {
                push @{ $self->{reference} }, {
                    qualifier => $data_arr->[0]->[0],
                      number  => $data_arr->[0]->[1],
                };
            }
        }
        when ('CUX') {
            if ( $self->{segment_group} == 1 ) {

                $self->{currency}      = $data_arr->[0];
                $self->{segment_group} = 4;
            }
        }
        when ('NAD') {
            push @{ $self->{addresses} }, {
                NAD => $data_arr,
            };
            $self->{segment_group} = 11;
        }
        when ('LIN') {
            $self->{segment_group} = 27;
            my $line = {
                line_number            => $data_arr->[0]->[0],
                action_req             => $data_arr->[1]->[0],
                item_number            => $data_arr->[2]->[0],
                item_number_type       => $data_arr->[2]->[1],
                additional_product_ids => [],
                item_description       => [],
            };
            if ( $data_arr->[3]->[0] ) {
                $line->{sub_line_info} = $data_arr->[3];
            }
            push @{ $self->{lines} }, $line;
            $self->{cur_line_number} = $line->{line_number};
        }
        when ('PIA') {
            push @{ $self->{lines}->[-1]->{additional_product_ids} }, $data_arr;
        }
        when ('IMD') {
            if ( $data_arr->[0]->[0] eq 'L' ) { # only handle text at the moment
                if ( $data_arr->[2]->[4] ) {
                    $data_arr->[2]->[3] .= $data_arr->[2]->[4];
                }
                push @{ $self->{lines}->[-1]->{item_description} }, {
                    code   => $data_arr->[1]->[0],
                      text => $data_arr->[2]->[3],
                };
            }
        }
        when ('QTY') {
            $self->{lines}->[-1]->{quantity} = $data_arr->[0]->[1];
        }
        when ('GIR') {
            my $ln = $self->{cur_line_number} - 1;
            $self->{lines}->[-1]->{related_numbers} = $data_arr;
        }
        when ('MOA') {
            $self->{lines}->[-1]->{monetary_amount} = $data_arr;
        }
        when ('PRI') {
            my $ln = $self->{cur_line_number} - 1;
            $self->{lines}->[-1]->{price} = {
                qualifier            => $data_arr->[0]->[0],
                price                => $data_arr->[0]->[1],
                price_type           => $data_arr->[0]->[2],
                price_type_qualifier => $data_arr->[0]->[3],
            };
        }
        when ('UNS') {
            $self->{segment_group} = -1;    # summary does not have a seg group
        }
        when ('CNT') {
            if ( $data_arr->[0]->[0] == 2 ) {
                $self->{summary_count} = $data_arr->[0]->[1];
            }
        }
    }
    return;
}

=head2 type

return the message's type
e.g. 'QUOTES' or 'ORDERS'

=cut

sub type {
    my $self = shift;
    return $self->{type};    # e.g. 'QUOTES'
}

=head2 function

Returns the message's function field
May be 'original' or 'retransmission'

=cut

sub function {
    my $self = shift;
    my $f    = $self->{bgm_data}->[2]->[0];
    if ( $f == 9 ) {
        return 'original';
    } elsif ( $f == 7 ) {
        return 'retransmission';
    } else {
        return $f;
    }
}

=head2 currency_code

=cut

sub currency_code {
    my $self = shift;
    if ( exists $self->{currency} ) {
        return $self->{currency}->[1];
    }
    return;
}

=head2 reference_number

=cut

sub reference_number {
    my $self = shift;
    return $self->{ref_num};
}

=head2 date_of_message

=cut

sub date_of_message {
    my $self = shift;
    return $self->{message_date};
}

# from lineitems

=head2 order_reference_number

=cut

sub order_reference_number {
    my $self = shift;
    my $line = shift;

}

=head2 line_sequence_number

=cut

sub line_sequence_number {
    my $self = shift;
    my $line = shift;
}

=head2 ean

Return the lineitem's ean (a 13 digit ISBN)

=cut

sub ean {    #LIN
    my $self = shift;
    my $line = shift;
}

=head2 author_surname

=cut

sub author_surname {    #110
    my $self = shift;
    my $line = shift;
}

=head2 author_firstname

=cut

sub author_firstname {    # 111
    my $self = shift;
    my $line = shift;
}

=head2 author

=cut

sub author {
    my $self = shift;
    my $line = shift;
}

=head2 title

=cut

sub title {    #050
    my $self = shift;
    my $line = shift;
}

=head2 subtitle

=cut

sub subtitle {    #060
    my $self = shift;
    my $line = shift;
}

=head2 edition

=cut

sub edition {     # IMD 100
    my $self = shift;
    my $line = shift;
}

=head2 place_of_publication

=cut

sub place_of_publication {    # IMD 110
    my $self = shift;
    my $line = shift;
}

=head2 publisher

=cut

sub publisher {               # IMD 120
    my $self = shift;
    my $line = shift;
}

=head2 date_of_publication

=cut

sub date_of_publication {     # IMD 170
    my $self = shift;
    my $line = shift;
}

=head2 item_format

=cut

sub item_format {             #IMD 220
    my $self = shift;
    my $line = shift;
}

=head2 shelfmark

=cut

sub shelfmark {               #IMD 230
    my $self = shift;
    my $line = shift;
}

=head2 quantity

=cut

sub quantity {
    my $self = shift;
    my $line = shift;
}

=head2 price

=cut

sub price {
    my $self = shift;
    my $line = shift;
}

=head1 AUTHOR

Colin Campbell, C<< <colin.campbell at ptfs-europe.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-edifact-interchange at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Edifact-Interchange>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Edifact::Message


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Edifact-Interchange>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Edifact-Interchange>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Edifact-Interchange>

=item * Search CPAN

L<http://search.cpan.org/dist/Edifact-Interchange/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Colin Campbell.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of Edifact::Message
