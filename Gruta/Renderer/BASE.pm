package Gruta::Renderer::BASE;

sub story
{
    my $self    = shift;
    my $story   = shift;

    # find an image for the story
    my $body = $story->get('body');
    my $img = '';

    if ($body =~ /img:\/\/([^ \/]+)/) {
        # img:// pseudo_url
        $img = '/img/' . $1;
    }
    elsif ($body =~ /<\s*img\s+src\s*=\s*"([^"]+)"/) {
        # pure HTML img tag
        $img = $1;
    }
    elsif ($story->source) {
        # find an image in the related stories
        foreach my $s ($story->source->related_stories($story, 10)) {
            my $ns = $story->source->story($s->[0], $s->[1]);

            # pick it
            if (my $i = $ns->get('image')) {
                $img = $i;
                last;
            }
        }
    }

    $story->set('image', $img);

    return $self;
}


1;
