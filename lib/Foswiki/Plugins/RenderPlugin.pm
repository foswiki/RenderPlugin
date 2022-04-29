# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2022 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::RenderPlugin;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Sandbox() ;
use Foswiki::Attrs() ;
use Foswiki::Plugins::JQueryPlugin ();
use Encode ();

our $VERSION = '7.00';
our $RELEASE = '29 Apr 2022';
our $SHORTDESCRIPTION = 'Render <nop>WikiApplications asynchronously';
our $NO_PREFS_IN_TOPIC = 1;
our $core;

sub initPlugin {

  Foswiki::Plugins::JQueryPlugin::registerPlugin('FoswikiTemplate', 'Foswiki::Plugins::RenderPlugin::FoswikiTemplate');

  # deprecated handler
  if ($Foswiki::cfg{RenderPlugin}{ExpandHandler}{Enabled}) {
    Foswiki::Func::registerRESTHandler('expand', 
      sub {
        return getCore(shift)->restExpand(@_);
      },
      authenticate => 0,
      validate => 0,
      http_allow => 'GET,POST',
    );
  }

  # deprecated handler
  if ($Foswiki::cfg{RenderPlugin}{RenderHandler}{Enabled}) {
    Foswiki::Func::registerRESTHandler('render', 
      sub {
        return getCore(shift)->restRender(@_);
      },
      authenticate => 0,
      validate => 0,
      http_allow => 'GET,POST',
    );
  }

  Foswiki::Func::registerRESTHandler('template', 
    sub {
      return getCore(shift)->restTemplate(@_);
    },
    authenticate => 0,
    validate => 0,
    http_allow => 'GET,POST',
  );


  Foswiki::Func::registerRESTHandler('jsonTemplate', 
    sub {
      return getCore(shift)->restJsonTemplate(@_);
    },
    authenticate => 0,
    validate => 0,
    http_allow => 'GET,POST',
  );

  Foswiki::Func::registerRESTHandler('tag', 
    sub {
      return getCore(shift)->restTag(@_);
    }, 
    authenticate => 0,
    validate => 0,
    http_allow => 'GET,POST',
  );

  return 1;
}

sub modifyHeaderHandler {
  return getCore()->modifyHeaderHandler(@_);
}

sub getCore {
  my $session = shift;

  unless ($core) {
    require Foswiki::Plugins::RenderPlugin::Core;
    $core = Foswiki::Plugins::RenderPlugin::Core->new($session);
  }

  return $core;
}

sub finishPlugin {
  $core->finish() if $core;
  undef $core;
}

# api
sub registerAllowedTag {
  return getCore()->registerAllowedTag(@_);
}

1;
