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
        $img = $1;
    }
    elsif ($body =~ /<\s*img\s+src\s*=\s*"([^"]+)"/) {
        # pure HTML img tag
        $img = $1;
    }

    $story->set('image', $img);

    return $self;
}


1;
