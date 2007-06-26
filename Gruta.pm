package Gruta;

use Gruta::Data;
use CGI;

sub new {
	my $class = shift;

	my $w = bless( {}, $class);

	$w->{cgi}	= CGI->new();
	$w->{data}	= Gruta::Data->new( @_ );

	return $w;
}

sub run {
	my $self = shift;

}

1;
