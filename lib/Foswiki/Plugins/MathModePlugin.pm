# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2009 Michael Daum http://michaeldaumconsulting.com
# Copyright (C) 2002 Graeme Lufkin, gwl@u.washington.edu
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
###############################################################################

package Foswiki::Plugins::MathModePlugin;

use strict;
use vars qw(
  $web $topic $VERSION $RELEASE $core %FoswikiCompatibility
  $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
);
$VERSION = '$Rev$';
$RELEASE = '4.00';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Include <nop>LaTeX formatted math in your Foswiki pages';
$FoswikiCompatibility{endRenderingHandler} = 1.1;

###############################################################################
sub initPlugin {
  ($topic, $web) = @_;
	
  undef $core;
  return 1;
}

###############################################################################
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;

  $_[0] =~ s/%\\\[(.*?)\\\]%/&handleMath($1,0)/geo;
  $_[0] =~ s/%\$(.*?)\$%/&handleMath($1,1)/geo;
  $_[0] =~ s/<latex(?: (.*?))?>(.*?)<\/latex>/&handleMath($2,2,$1)/geos;
}

###############################################################################
sub getCore {
  return $core if $core;
  
  require Foswiki::Plugins::MathModePlugin::Core;
  $core = new Foswiki::Plugins::MathModePlugin::Core;

  return $core;
}

###############################################################################
sub handleMath { 
  return getCore()->handleMath($web, $topic, @_); 
}

###############################################################################
sub postRenderingHandler { 
  return unless $core; # no math
  $core->postRenderingHandler($web, $topic, @_)
}
	
1;
