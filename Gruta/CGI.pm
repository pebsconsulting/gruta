package Gruta::CGI;

use CGI;

sub vars { return $_[0]->{cgi}->Vars(); }
sub upload_dirs { return @{ $_[0]->{upload_dirs} }; }

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


sub upload {
	my $self	= shift;
	my $dir_num	= shift;
	my $field	= shift;

	my $file = $self->{cgi}->param($field);
	my ($basename) = ($file =~ /([^\/\\]+)$/);

	my $dir = ($self->upload_dirs())[$dir_num] or
		die "Undefined upload dirs.";

	my $filename = $dir . '/' . $basename;

	open F, '>' . $filename or die "Can't write $filename";
	while(<$file>) {
		print F $_;
	}

	close F;
}


sub new {
	my $class	= shift;

	my $obj = bless( {}, $class );

	$obj->{http_headers} = {
		'Content-Type'		=> 'text/html; charset=ISO-8859-1',
		'X-Powered-By'		=> 'Gruta',
		'X-Gateway-Interface'	=> $ENV{'GATEWAY_INTERFACE'},
		'X-Server-Name'		=> $ENV{'SERVER_NAME'}
	};

	$obj->{upload_dirs} ||= [];

	$obj->{cgi} = CGI->new();

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
		$data->log($@);
		$self->redirect('?t=INDEX');
	}

	my $h = $self->http_headers();
	foreach my $k (keys(%{ $h })) {
		print $k, ': ', $h->{$k}, "\n";
	}
	print "\n";

	print $body;
}

1;
