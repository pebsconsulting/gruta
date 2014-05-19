#!/usr/bin/perl

my $PROTO_VERSION = '1.0';
my $SERVER_VERSION = '0.0';

use strict;
use warnings;

use File::Temp;

use Gruta;
use Gruta::Source::DBI;
use Gruta::Source::FS;
use Gruta::Renderer::Grutatxt;
use Gruta::Renderer::HTML;
use Gruta::Renderer::Text;

sub arg
{
	if (@ARGV) {
		return shift(@ARGV);
	}

	usage();
}


sub new_source
{
	my $src_str = shift;
	my $src;

	if ($src_str =~ /^dbi:/) {
		$src = Gruta::Source::DBI->new( string => $src_str );
	}
	elsif ($src_str =~ /^mbox:(.+)/) {
		my $file = $1;

		$src = Gruta::Source::Mbox->new(
			file		=>	$file
		);
	}
	else {
		$src = Gruta::Source::FS->new( path => $src_str );
	}

	return $src;
}


sub init
{
	my $src = new_source(arg());
	my $g	= Gruta->new(
		source => $src,
		renderers	=> [
			Gruta::Renderer::Grutatxt->new(),
			Gruta::Renderer::HTML->new(),
			Gruta::Renderer::HTML->new( valid_tags => undef ),
			Gruta::Renderer::Text->new(),
		]
	);

	return $g;
}


sub usage
{
    print "grutad.pl - Grutad server in Perl\n\n";

    print "Usage:\n";
    print "grutad {src}\n\n";

    print "Where {src} is a Gruta source spec. Examples:\n\n";
    print " * /var/www/site_dir/var (FS type)\n";
    print " * dbi:SQLite:/var/www/site_dir/var/gruta.db (Perl DBI type)\n";

    exit 1;
}


sub dump_as_hash
{
    my $h = shift;
    my $e = shift;

    if ($h) {
        print "OK\n";

        foreach my $k (keys(%{$h})) {
            my $v = $h->{$k} || '';

            if (ref(\$v) eq 'SCALAR') {
                $v =~ s/\n/\\n/g;

                print $k, "\n";
                print $v, "\n";
            }
        }

        print ".\n";
    }
    else {
        print "ERROR ", $e, "\n";
    }
}


sub dump_as_list
{
    my @l   = @_;

    print "OK\n";

    foreach my $e (@l) {
        my $t = ref($e);

        if ($t eq 'ARRAY') {
            print join(":", @{$e}), "\n";
        }
        else {
            print $e, "\n";
        }
    }
    print ".\n";
}


sub dialog
{
    my $g = shift;

    for (;;) {
        my $l = <>;
        chomp($l);

        if (!$l) {
            last;
        }

        my ($k, @args) = split(/ /, $l);

        if ($k eq 'bye') {
            last;
        }
        elsif ($k eq 'version') {
            dump_as_hash({
                PROTO_VERSION   => $PROTO_VERSION,
                SERVER_VERSION  => $SERVER_VERSION
                }
            );
        }
        elsif ($k eq 'topics') {
            dump_as_list($g->source->topics());
        }
        elsif ($k eq 'users') {
            dump_as_list($g->source->users());
        }
        elsif ($k eq 'tags') {
            dump_as_list($g->source->tags());
        }
        elsif ($k eq 'stories_top_ten') {
            dump_as_list($g->source->stories_top_ten($args[0] || 10));
        }
        elsif ($k eq 'stories_by_date') {
            my $topics = undef;

            if ($args[0]) {
                $topics = [ $args[0] eq '-' ?
                    $g->source->topics() :
                    split(/:/, $args[0])
                ];
            }

            dump_as_list($g->source->stories_by_date($topics,
                        num     => $args[1] || 0,
                        offset  => $args[2] || 0,
                        from    => $args[3] || '',
                        to      => $args[4] || '',
                        future  => $args[5] || 0
             ));
        }
        elsif ($k eq 'story') {
            my $obj = $g->source->story($args[0], $args[1]);

            dump_as_hash($obj, "Story '$args[0]/$args[1]' not found");
        }
        elsif ($k eq 'topic') {
            my $obj = $g->source->topic($args[0]);

            dump_as_hash($obj, "Topic '$args[0]' not found");
        }
        elsif ($k eq 'user') {
            my $obj = $g->source->user($args[0]);

            dump_as_hash($obj, "User '$args[0]' not found");
        }
        else {
            print "ERROR '$k' command not found\n";
        }
    }
}


dialog(init());

exit 0;
