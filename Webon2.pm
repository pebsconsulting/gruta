package Webon2;

use Webon2::Data;
use CGI;

sub new {
	my $class = shift;

	my $w = bless( {}, $class);

	$w->{cgi}	= CGI->new();
	$w->{data}	= Webon2::Data->new( @_ );

	return $w;
}

sub run {
	my $self = shift;

}

1;
