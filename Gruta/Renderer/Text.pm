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

	($title) = (split(/\r?\n/, $content))[0];
	$abstract = "<h2>\n" . $title . "</h2>\n";

	$story->set('title', $title);
	$story->set('abstract', $abstract);
	$story->set('body', "<pre>\n" . $content . "</pre>\n");

	return $self;
}

1;
