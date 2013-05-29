package Gruta::Renderer::Text;

use strict;
use warnings;

use base 'Gruta::Renderer::BASE';

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

	$content =~ s/&/&amp;/g;
	$content =~ s/</&lt;/g;
	$content =~ s/>/&gt;/g;

	($title) = (split(/\r?\n/, $content))[0];
	$abstract = "<h2>\n" . $title . "</h2>\n";

	$story->set('title', $title);
	$story->set('abstract', $abstract);
	$story->set('body', "<pre>\n" . $content . "</pre>\n");

	return $self->SUPER::story($story);
}

1;
