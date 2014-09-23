package Gruta::FCGI;

use base 'Gruta::CGI';

use CGI::Fast qw(:standard);
use Carp;

sub run {
    my $self = shift;

    while ($self->{cgi} = new CGI::Fast) {
        $self->run_1();
    }
}

1;
