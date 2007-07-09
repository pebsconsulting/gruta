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
		'Content-Type'		=> 'text/html; charset=ISO-8859-1',
		'X-Powered-By'		=> 'Gruta',
		'X-Gateway-Interface'	=> $ENV{'GATEWAY_INTERFACE'},
		'X-Server-Name'		=> $ENV{'SERVER_NAME'}
	};

	return $obj;
}


sub run {
	my $self	= shift;

	my $data = $self->data();
	my $vars = $self->vars();

	$data->template->cgi_vars($vars);

	if (my $cookie = $self->cookie()) {
		if (my ($sid) = ($cookie =~ /^sid\s*=\s*(\d+)$/)) {
			$data->auth_from_sid( $sid );
		}
	}

	my $st = 'INDEX';

	if ($vars->{t}) {
		$st = uc($vars->{t});
	}

	$st = 'INDEX' unless $st =~ /^[-\w0-9_]+$/;

	my $body = undef;

	eval { $body = $data->template->process( $st ) };

	if ($@) {
		$self->http_headers( 'Status' => '404 Not Found' );
		$body = $data->template->process( '404' );
	}

	my $h = $self->http_headers();
	foreach my $k (keys(%{ $h })) {
		print $k, ': ', $h->{$k}, "\n";
	}
	print "\n";

	print $body;
}

1;
