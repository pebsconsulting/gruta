package Gruta::Source::FS;

use Gruta::Data;

package Gruta::Data::FS::BASE;

package Gruta::Data::FS::Story;

use base 'Gruta::Data::Story';
use base 'Gruta::Data::FS::BASE';

package Gruta::Data::FS::Topic;

use base 'Gruta::Data::Topic';
use base 'Gruta::Data::FS::BASE';

package Gruta::Data::FS::User;

use base 'Gruta::Data::User';
use base 'Gruta::Data::FS::BASE';

package Gruta::Source::FS;

sub new {
	my $class = shift;

	my $s = bless( { @_ }, $class);

	return $s;
}

1;
