# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# TrashPlugin is Copyright (C) 2013 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::TrashPlugin;

use strict;
use warnings;

use Foswiki::Func ();

use version; our $VERSION = version->declare("1.0.1");
our $RELEASE = '05 Sep 2013';
our $SHORTDESCRIPTION = 'Maintain the Trash web';
our $NO_PREFS_IN_TOPIC = 1;
our $core;

sub core {
  unless (defined $core) {
    require Foswiki::Plugins::TrashPlugin::Core;
    $core = new Foswiki::Plugins::TrashPlugin::Core();
  }

  return $core;
}

sub initPlugin {
  Foswiki::Func::registerRESTHandler("cleanUp", sub { return core->cleanUp(@_); });
  return 1;
}

1;
