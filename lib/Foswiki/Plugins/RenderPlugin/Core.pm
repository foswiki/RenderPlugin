# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2016 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::RenderPlugin::Core;

use strict;
use warnings;

use Foswiki::Func();
use Foswiki::Plugins();
use Foswiki::Attrs ();

use constant TRACE => 0; # toggle me

###############################################################################
sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  my $this = bless({
    session => $session,
    @_
  }, $class);

  return $this;
}

###############################################################################
sub writeDebug {
  print STDERR '- RenderPlugin - '.$_[0]."\n" if TRACE;
}

###############################################################################
sub json {
  my $this = shift;

  unless (defined $this->{json}) {
    require JSON;
    $this->{json} = JSON->new->pretty->convert_blessed(1);
  }

  return $this->{json};
}

###############################################################################
sub getZoneObject {
  my ($this, $zone, $meta) = @_;

  my @zone = ();
  my $excludeFromZone = $Foswiki::cfg{AngularPlugin}{ExcludeFromZone} || $Foswiki::cfg{RenderPlugin}{ExcludeFromZone};

  foreach my $item (grep { $_->{text} } $this->getZoneItems($zone)) {
    if ($excludeFromZone && $item->{id} =~ /$excludeFromZone/g) {
      #print STDERR "excluding $item->{id}\n"; 
      next;
    }
    #print STDERR "id=$item->{id}\n"; 
    my @requires = map { $_->{id} } @{$item->{requires}};

    my $text = $meta->renderTML($meta->expandMacros($item->{text}));
    $text =~ s/\$id/$item->{id}/g;
    $text =~ s/\$zone/$zone/g;
    push @zone, {
      id => $item->{id},
      text => $text,
      requires => \@requires,
    };
  }

  return \@zone;
}

###############################################################################
sub getZoneItems {
  my ($this, $zone) = @_;

  my $session = $Foswiki::Plugins::SESSION;
  my $zonesHandler;

  if ($session->can("zones")) {
    # Foswiki > 2.0.3: zones are stored in a sub-component
    $zonesHandler = $session->zones();
  } else {
    # Foswiki <= 2.0.3: zones are stored in the session object
    $zonesHandler = $session;
  }

  my @zoneItems = values %{$zonesHandler->{_zones}{$zone}};
  my %visited = ();
  my @result = ();

  foreach my $item (@zoneItems) {
    $zonesHandler->_visitZoneID($item, \%visited, \@result);
  }

  return @result;
}

###############################################################################
sub restTag {
  my ($this, $subject, $verb) = @_;

  #writeDebug("called restTag($subject, $verb)");

  # get params
  my $query = Foswiki::Func::getCgiQuery();

  my $theTag = $query->param('name') || 'INCLUDE';
  my $theDefault = $query->param('param') || '';
  my $theRender = $query->param('render') || 0;

  $theRender = ($theRender =~ /^\s*(1|on|yes|true)\s*$/) ? 1:0;

  my $theTopic = $query->param('topic') || $this->{session}{topicName};
  my $theWeb = $query->param('web') || $this->{session}{webName};
  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $theTopic);
  $web = Foswiki::Sandbox::untaint($web, \&Foswiki::Sandbox::validateWebName);
  $topic = Foswiki::Sandbox::untaint($topic, \&Foswiki::Sandbox::validateTopicName);

  # construct parameters for tag
  my $params = $theDefault?'"'.$theDefault.'"':'';
  foreach my $key ($query->param()) {
    next if $key =~ /^(name|param|render|topic|XForms:Model)$/;
    my $value = $query->param($key);
    $params .= ' '.$key.'="'.$value.'" ';
  }

  # create TML expression
  my $tml = '%'.$theTag;
  $tml .= '{'.$params.'}' if $params;
  $tml .= '%';

  #writeDebug("tml=$tml");

  # and render it
  my $result = Foswiki::Func::expandCommonVariables($tml, $topic, $web) || ' ';
  if ($theRender) {
    $result = Foswiki::Func::renderText($result, $web, $topic);
  }

  #writeDebug("result=$result");

  my $contentType = $query->param("contenttype");
  $this->{session}->writeCompletePage($result, undef, $contentType);

  return;
}

###############################################################################
sub restRender {
  my ($this, $subject, $verb) = @_;

  my $query = Foswiki::Func::getCgiQuery();
  my $theText = $query->param('text') || '';

  return ' ' unless $theText; # must return at least on char as we get a
                              # premature end of script otherwise

  my $theTopic = $query->param('topic') || $this->{session}{topicName};
  my $theWeb = $query->param('web') || $this->{session}{webName};
  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $theTopic);
  $web = Foswiki::Sandbox::untaint($web, \&Foswiki::Sandbox::validateWebName);
  $topic = Foswiki::Sandbox::untaint($topic, \&Foswiki::Sandbox::validateTopicName);

  # expand and render
  my $result = Foswiki::Func::expandCommonVariables($theText, $topic, $web) || ' ';
  $result = Foswiki::Func::renderText($result, $web, $topic);

  my $contentType = $query->param("contenttype");
  $this->{session}->writeCompletePage($result, undef, $contentType);

  return;
}

###############################################################################
sub restExpand {
  my ($this, $subject, $verb) = @_;

  # get params
  my $query = Foswiki::Func::getCgiQuery();
  my $theText = $query->param('text') || '';

  return ' ' unless $theText; # must return at least on char as we get a
                              # premature end of script otherwise

  my $theTopic = $query->param('topic') || $this->{session}{topicName};
  my $theWeb = $query->param('web') || $this->{session}{webName};
  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $theTopic);
  $web = Foswiki::Sandbox::untaint($web, \&Foswiki::Sandbox::validateWebName);
  $topic = Foswiki::Sandbox::untaint($topic, \&Foswiki::Sandbox::validateTopicName);

  # expand
  my $result = Foswiki::Func::expandCommonVariables($theText, $topic, $web) || ' ';

  my $contentType = $query->param("contenttype");
  $this->{session}->writeCompletePage($result, undef, $contentType);

  return;
}

###############################################################################
sub restTemplate {
  my ($this, $subject, $verb) = @_;

  my $query = Foswiki::Func::getCgiQuery();
  my $theTemplate = $query->param('name');
  return '' unless $theTemplate;

  my $theExpand = $query->param('expand');
  return '' unless $theExpand;

  my $theTopic = $query->param('topic') || $this->{session}{topicName};
  my $theWeb = $query->param('web') || $this->{session}{webName};
  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $theTopic);
  $web = Foswiki::Sandbox::untaint($web, \&Foswiki::Sandbox::validateWebName);
  $topic = Foswiki::Sandbox::untaint($topic, \&Foswiki::Sandbox::validateTopicName);

  Foswiki::Func::loadTemplate($theTemplate);
  my $attrs = new Foswiki::Attrs($theExpand);

  my $tmpl = $this->{session}->templates->tmplP($attrs);

  # expand
  my $result = Foswiki::Func::expandCommonVariables($tmpl, $topic, $web) || ' ';

  # render
  my $theRender = Foswiki::Func::isTrue(scalar $query->param('render'),  0);
  if ($theRender) {
    $result = Foswiki::Func::renderText($result, $web, $topic);
  }

  my $contentType = $query->param("contenttype");
  $this->{session}->writeCompletePage($result, undef, $contentType);

  return;
}

###############################################################################
sub restJsonTemplate {
  my ($this, $subject, $verb) = @_;

  my $query = Foswiki::Func::getCgiQuery();
  my $theTemplate = $query->param('name');
  return '' unless $theTemplate;

  my $theExpand = $query->param('expand');
  return '' unless $theExpand;

  my $theTopic = $query->param('topic') || $this->{session}{topicName};
  my $theWeb = $query->param('web') || $this->{session}{webName};
  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $theTopic);
  $web = Foswiki::Sandbox::untaint($web, \&Foswiki::Sandbox::validateWebName);
  $topic = Foswiki::Sandbox::untaint($topic, \&Foswiki::Sandbox::validateTopicName);

  my ($meta) = Foswiki::Func::readTopic($web, $topic);

  Foswiki::Func::loadTemplate($theTemplate);

  require Foswiki::Attrs;
  my $attrs = new Foswiki::Attrs($theExpand);

  my $tmpl = $this->{session}->templates->tmplP($attrs);

  # expand
  my $result = {
    web => $web,
    topic => $topic,
    expand => Foswiki::Func::expandCommonVariables($tmpl, $topic, $web, $meta) || ' ',
    zones => {},
  };

  # render
  my $theRender = Foswiki::Func::isTrue(scalar $query->param('render'),  0);
  if ($theRender) {
    $result->{expand} = Foswiki::Func::renderText($result->{expand}, $web, $topic);
  }

  # expand zones
  my $theZones = $query->param('zones') || '';
  foreach my $id (split(/\s*,\s*/, $theZones)) {
    $result->{zones}{$id} = $this->getZoneObject($id, $meta);
  }

  my $data = $this->json->encode($result);

  $this->{session}{response}->header(-'Content-Type' => "application/json; charset=$Foswiki::cfg{Site}{CharSet}");
  $this->{session}->writeCompletePage($data, undef, "application/json; charset=$Foswiki::cfg{Site}{CharSet}");

  return;
}

1;
