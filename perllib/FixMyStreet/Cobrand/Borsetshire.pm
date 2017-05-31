package FixMyStreet::Cobrand::Borsetshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_id { return 2608; }
sub council_area { return 'Borsetshire'; }
sub council_name { return 'Borsetshire County Council'; }
sub council_url { return 'borsetshire'; }

sub example_places {
    return ( 'BS36 2NS', 'Coalpit Heath' );
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    #return 'grey' if $p->state eq 'not responsible';
    #return 'green' if $p->is_fixed || $p->is_closed;
    #return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}

sub send_questionnaires {
    return 0;
}

1;
