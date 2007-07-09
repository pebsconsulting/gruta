package Gruta::CGI;

use CGI qw(Vars);

sub vars { return Vars(); }

sub http_headers {
	my $self	= shift;
	my %headers	= @_;

	foreach my $k (keys(%headers)) {
		$self->{http_headers}->{$k} = $headers{$k};
	}

	return $self->{http_headers};
}

sub cookie {
	my $self	= shift;

	if (@_) {
		$self->http_headers( 'Set-Cookie', shift );
	}

	return $ENV{HTTP_COOKIE};
}

sub redirect { $_[0]->http_headers( 'Location', $_[1] ); }

sub data {
	my $self	= shift;
	my $data	= shift;

	if (defined($data)) {
		$self->{data} = $data;
	}

	return $self->{data};
}

sub new {
	my $class	= shift;

	my $obj = bless( {}, $class);

	$obj->{http_headers} = {
		'X-Powered-By'		=> 'Gruta',
		'X-Gateway-Interface'	=> $ENV{'GATEWAY_INTERFACE'},
		'X-Server-Name'		=> $ENV{'SERVER_NAME'}
	};

	return $obj;
}
