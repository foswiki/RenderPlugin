# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2019-2025 Michael Daum, http://michaeldaumconsulting.com
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

package Foswiki::Plugins::RenderPlugin::FoswikiTemplate;

use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugin ();
our @ISA = 'Foswiki::Plugins::JQueryPlugin::Plugin';

sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;
  my $this = bless(
    $class->SUPER::new(
      $session,
      name => 'FoswikiTemplate',
      version => '3.30',
      author => 'Michael Daum',
      homepage => 'https://foswiki.org/Extensions/RenderPlugin',
      puburl => '%PUBURLPATH%/%SYSTEMWEB%/RenderPlugin',
      javascript => ['foswikiTemplate.js'],
      summary => <<SUMMARY), $class);
<nop>This helper module that loads a Foswiki tmpl using json-rpc and then 
merges it into the current page. Any additional javascript dependency is loaded into
the page's zone while doing so.
SUMMARY
  return $this;
}
1;
