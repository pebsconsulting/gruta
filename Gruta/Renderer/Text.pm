package Gruta::Renderer::Text;

use strict;
use warnings;

sub new {
	my $class	= shift;

	my $r = bless( { @_ }, $class );

	$r->{renderer_id} ||= 'text';

	return $r;
}

sub story {
	my $self	= shift;
	my $story	= shift; # ::Data::Story

	my $title = '';
	my $abstract = '';
	my $content = $story->get('content');

	($title) = (/^\s*([^\n]+)/s);
	$abstract = "<h1>\n" . $title . "</h1>\n";

	$story->set('title', $title);
	$story->set('abstract', $abstract);
	$story->set('body', "<pre>\n" . $content . "</pre>\n");

	return $self;
}

1;
