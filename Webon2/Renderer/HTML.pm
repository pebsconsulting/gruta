package Gruta::Renderer::HTML;

sub new {
	my $class	= shift;

	my $r = bless( { @_ }, $class );

	if (not exists $r->{valid_tags}) {
		$r->{valid_tags} = 'I B P A LI OL UL EM BR TT STRONG BLOCKQUOTE';
	}

	$r->{valid_tags_h} = {};

	foreach my $t (split(/\s+/, $r->{valid_tags})) {
		$r->{valid_tags_h}->{$t}++;
	}

	$r->{renderer_id} ||= defined($r->{valid_tags}) ? 'html' : 'raw_html';

	return $r;
}


sub _filter_tag
{
	my ($text, $tags) = @_;

	return $text unless $text =~ /<\s*\/?\s*(\w+)/;

	return exists $tags->{uc($1)} ? $text : '';
}


sub _filter {
	my $self	= shift;
	my $str		= shift;

	my $tags = $self->{valid_tags_h};

	$str =~ s/(<\/?[^>]+>)/_filter_tag($1, $tags)/ge;

	return $str;
}


sub story {
	my $self	= shift;
	my $story	= shift; # ::Data::Story

	my ($title, $abstract);

	my $content = $story->get('content');

	($title) = ($content =~ /<\s*title[^>]*>(.*)<\/title>/is);
	($title) = ($content =~ /<\s*h1[^>]*>(.*)<\/h1>/is) unless $title;

	$title ||= "-";

	# clean up the title
	$title =~ s/[\n\r].//g;
	$title =~ s/^\s+//g;
	$title =~ s/\s+$//g;

	# strip unacceptable tags
	$content =~ s/<\s*title[^>]*>.*<\s*\/\s*title\s*>//igs;
	$content =~ s/<\s*head[^>]*>.*<\s*\/\s*head\s*>//igs;
	$content =~ s/<\s*style[^>]*>.*<\s*\/\s*style\s*>//igs;
	$content =~ s/<\s*\/?\s*html[^>]*>//ig;
	$content =~ s/<\s*\/?\s*!doctype[^>]*>//ig;
	$content =~ s/<\s*\/?\s*body[^>]*>//ig;
	$content =~ s/<\s*\/?\s*meta[^>]*>//ig;
	$content =~ s/<\s*\/?\s*link[^>]*>//ig;

	# if $tags filter is defined, is filtered_html
	if($self->{valid_tags_h}) {
		$content =~ s/<\s*h1[^>]*>.*<\/h1>//ig;

		$content = $self->_filter($content);
		$abstract = $content;

		$content = "<h2>$title</h2>\n" . $content;
		$abstract = "<h3>$title</h3>\n" . $abstract;
	}
	else {
		$abstract = $content;
	}

	if($abstract =~ /^(.*)<->/s) {
		$abstract = $1;
	}

	$content =~ s/<->//g;

	$story->set('title',	$title);
	$story->set('abstract',	$abstract);
	$story->set('body',	$content);

	return $self;
}

1;
