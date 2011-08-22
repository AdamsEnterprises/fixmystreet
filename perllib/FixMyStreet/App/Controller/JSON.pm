package FixMyStreet::App::Controller::JSON;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use JSON;
use DateTime;
use DateTime::Format::ISO8601;
use List::MoreUtils 'uniq';

=head1 NAME

FixMyStreet::App::Controller::JSON - Catalyst Controller

=head1 DESCRIPTION

Provide information as JSON

=head1 METHODS

=head2 problems

Provide JSON of new/fixed problems in a specified time range

=cut

sub problems : Local {
    my ( $self, $c, $path_type ) = @_;

    # get the type from the path - this is to deal with the historic url
    # structure. In futur
    $path_type ||= '';
    my $type =
        $path_type eq 'new'   ? 'new_problems'
      : $path_type eq 'fixed' ? 'fixed_problems'
      :                         '';

    # gather the parameters
    my $start_date = $c->req->param('start_date') || '';
    my $end_date   = $c->req->param('end_date')   || '';
    my $category   = $c->req->param('category')   || '';

    my $yyyy_mm_dd = qr{^\d{4}-\d\d-\d\d$};
    if (   $start_date !~ $yyyy_mm_dd
        || $end_date !~ $yyyy_mm_dd )
    {
        $c->stash->{error} = 'Invalid dates supplied';
        return;
    }

    # convert the dates to datetimes and trap errors
    my $iso8601  = DateTime::Format::ISO8601->new;
    my $start_dt = eval { $iso8601->parse_datetime($start_date); };
    my $end_dt   = eval { $iso8601->parse_datetime($end_date); };
    unless ( $start_dt && $end_dt ) {
        $c->stash->{error} = 'Invalid dates supplied';
        return;
    }

    # check that the dates are sane
    if ( $start_dt > $end_dt ) {
        $c->stash->{error} = 'Start date after end date';
        return;
    }

    # check that the type is supported
    unless ( $type eq 'new_problems' || $type eq 'fixed_problems' ) {
        $c->stash->{error} = 'Invalid type supplied';
        return;
    }

    # query the database
    my ( @state, $date_col );
    if ( $type eq 'new_problems' ) {
        @state = FixMyStreet::DB::Result::Problem->open_states();
        $date_col = 'confirmed';
    } elsif ( $type eq 'fixed_problems' ) {
        @state = FixMyStreet::DB::Result::Problem->fixed_states();
        $date_col = 'lastupdate';
    }

    my $one_day = DateTime::Duration->new( days => 1 );
    my $query = {
        $date_col => {
            '>=' => $start_dt,
            '<=' => $end_dt + $one_day,
        },
        state => [ @state ],
    };
    $query->{category} = $category if $category;
    my @problems = $c->cobrand->problems->search( $query, {
        order_by => { -asc => 'confirmed' },
        columns => [
            'id',       'title', 'council',   'category',
            'detail',   'name',  'anonymous', 'confirmed',
            'whensent', 'service',
            'latitude', 'longitude', 'used_map',
            'state', 'lastupdate',
        ]
    } );

    my @councils;
    foreach my $problem (@problems) {
        $problem->name( '' ) if $problem->anonymous == 1;
        $problem->service( 'Web interface' ) if $problem->service eq '';
        if ($problem->council) {
            (my $council = $problem->council) =~ s/\|.*//g;
            my @council_ids = split /,/, $council;
            push(@councils, @council_ids);
            $problem->council( \@council_ids );
        }
    }
    @councils = uniq @councils;
    my $areas_info = mySociety::MaPit::call('areas', \@councils);
    foreach my $problem (@problems) {
        if ($problem->council) {
             my @council_names = map { $areas_info->{$_}->{name} } @{$problem->council} ;
             $problem->council( join(' and ', @council_names) );
        }
    }

    @problems = map { { $_->get_columns } } @problems;
    $c->stash->{response} = \@problems;
}

sub end : Private {
    my ( $self, $c ) = @_;

    my $response =
      $c->stash->{error}
      ? { error => $c->stash->{error} }
      : $c->stash->{response};

    $c->res->content_type('application/json; charset=utf-8');
    $c->res->body( encode_json( $response || {} ) );
}

__PACKAGE__->meta->make_immutable;

1;
