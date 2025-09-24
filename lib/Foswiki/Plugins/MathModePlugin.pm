# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2025 Michael Daum http://michaeldaumconsulting.com
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
use warnings;

our $VERSION = '4.06';
our $RELEASE = '%$RELEASE%';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION = 'Include <nop>LaTeX formatted math in your Foswiki pages';
our $LICENSECODE = '%$LICENSECODE%';
our $web;
our $topic;
our $core;

our %FoswikiCompatibility;
$FoswikiCompatibility{endRenderingHandler} = 1.1;

sub initPlugin {
  ($topic, $web) = @_;

  # Tell WyswiygPlugin to protect <latex>...</latex> markup
  if (defined &Foswiki::Plugins::WysiwygPlugin::addXMLTag) {
    Foswiki::Plugins::WysiwygPlugin::addXMLTag('latex', sub { 1 });
  }

  return 1;
}

sub finishPlugin {
  undef $core;
}

sub commonTagsHandler {
  my ($text, $topic, $web) = @_;

  $_[0] =~ s/%\\\[(.*?)\\\]%/&handleMath($web, $topic, $1,0)/geo;
  $_[0] =~ s/%\$(.*?)\$%/&handleMath($web, $topic, $1,1)/geo;
  $_[0] =~ s/<latex(?: (.*?))?>(.*?)<\/latex>/&handleMath($web, $topic, $2,2,$1)/geos;
}

sub getCore {
  return $core if $core;

  require Foswiki::Plugins::MathModePlugin::Core;
  $core = Foswiki::Plugins::MathModePlugin::Core->new();

  return $core;
}

sub handleMath {
  return getCore()->handleMath(@_);
}

sub postRenderingHandler {
  return unless $core; # no math
  $core->postRenderingHandler($web, $topic, @_);
}

1;
