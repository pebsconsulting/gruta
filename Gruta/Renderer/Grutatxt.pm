package Gruta::Renderer::Grutatxt;

use strict;
use warnings;

use Grutatxt;

sub new {
	my $class	= shift;
	my %args	= @_;

	my $r = bless( { renderer_id => 'grutatxt' }, $class );

	$r->{title}	= '';
	$r->{marks}	= [];
	$r->{abstract}	= 0;

	$r->{grutatxt} = Grutatxt->new(
		'header-offset'		=>	1,
		'table-headers'		=>	1,
		'title'			=>	\$r->{title},
		'marks'			=>	$r->{marks},
		'abstract'		=>	\$r->{abstract}
	);

	return $r;
}

sub _process {
	my $self	= shift;
	my $str		= shift;

	return $self->{grutatxt}->process($str);
}

sub story {
	my $self	= shift;
	my $story	= shift; # ::Data::Story

	my @o = $self->_process( $story->get('content') );

	my $to;

	if ($self->{marks}->[0]) {
		# story has a separator
		$to = $self->{marks}->[0] - 1;
	}
	else {
		# use first paragraph
		$to = $self->{abstract};
	}

	$to = scalar(@o) - 1 if $to >= scalar(@o);

	$story->set('title',	$self->{title}) if $self->{title};
	$story->set('abstract',	join("\n", @o[0 .. $to]));
	$story->set('body',	join("\n", @o));

	return $self;
}

1;
